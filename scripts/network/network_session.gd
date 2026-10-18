class_name NetworkSession
extends Node

signal status_changed(text: String)
signal opponent_connected
signal disconnected(reason: String)
signal synchronized
var transport: MultiplayerTransport
var api := SceneMultiplayer.new()
var game: Node3D
var host := false
var session_ready := false
var applying := false
var publishing := false
var committed: Dictionary = {}
var last_sequence := 0
var resolutions: Dictionary = {}
var remote_id := 0
var request_id := 0
var last_request := 0
var packet_id := 0
var assembly := {}
var ping_elapsed := 0.0
var ping_ms := -1
var quiet := 0.0
var request_window := 0.0
var requests_in_window := 0
var changed_pending := false
var started := false
var disconnected_once := false
var resync_attempts := 0
var compatibility_accepted := false
var handshake_elapsed := 0.0
var snapshot_waiting := false
var snapshot_elapsed := 0.0
var hash_status := "awaiting snapshot"
var ledger := RequestLedger.new()
var compatibility := NetworkCompatibility.manifest()
var debug_delay_ms := 0
var delayed_frames: Array[Dictionary] = []

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--net-delay-ms="): debug_delay_ms = clampi(int(argument.trim_prefix("--net-delay-ms=")), 0, 1000)
	api.root_path = get_path()
	api.peer_connected.connect(_peer_connected)
	api.peer_disconnected.connect(func(_id: int): _lost("Opponent disconnected." if host else "Connection lost."))
	api.connection_failed.connect(func(): _lost("Connection failed."))
	api.server_disconnected.connect(func(): _lost("Connection lost."))
	api.peer_packet.connect(_packet)

func open(next_transport: MultiplayerTransport, table: Node3D) -> void:
	transport = next_transport
	host = transport.is_host
	game = table
	game.network_session = self
	game.interaction.can_control = func(team: int): return session_ready and team == (0 if host else 1) and (game.manager.deployment or game.manager.active_team == team)
	game.history.submit = _submit_action
	game.manager.submit = func(command: String): return request(command)
	game.dice.submit = func(count: int): return request("dice", {"count": count})
	game.combat.submit = request
	game.battle_log.changed.connect(_schedule_publish)
	transport.peer_ready.connect(_attach)
	transport.status_changed.connect(func(text: String): status_changed.emit(text))
	transport.connection_lost.connect(_lost)
	if transport.peer != null: _attach()
	committed = WorldState.capture(game)
	game.hud.refresh_turn()

func _attach() -> void:
	api.multiplayer_peer = transport.peer
	api.allow_object_decoding = false

func _process(delta: float) -> void:
	if transport == null: return
	while not delayed_frames.is_empty() and int(delayed_frames[0].due) <= Time.get_ticks_msec():
		var frame: Dictionary = delayed_frames.pop_front()
		if api.multiplayer_peer != null: api.send_bytes(frame.bytes, remote_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)
	if api.multiplayer_peer != null: api.poll()
	if remote_id != 0 and not compatibility_accepted and not disconnected_once:
		handshake_elapsed += delta
		if handshake_elapsed > 15: _lost("Multiplayer compatibility check timed out. Both players need the same GrimTable build.")
	if snapshot_waiting and not disconnected_once:
		snapshot_elapsed += delta
		if snapshot_elapsed > 20: _lost("Host snapshot synchronization timed out. Check the connection and retry from the menu.")
	if not session_ready: return
	quiet += delta
	ping_elapsed += delta
	request_window += delta
	if request_window >= 1:
		request_window = 0
		requests_in_window = 0
	if ping_elapsed > 2:
		ping_elapsed = 0
		_send({"type": "ping", "time": Time.get_ticks_msec()})
	if quiet > 20: _lost("Connection timed out.")

func _peer_connected(id: int) -> void:
	if remote_id != 0: return
	if transport is OnlineTransport and not transport.reliable_channel_ok(id): _lost("Gameplay data channel is not reliably ordered. Use a matching supported GrimTable build."); return
	remote_id = id
	transport.connected = true
	quiet = 0
	_send({"type": "hello", "compatibility": compatibility})

func _accepted() -> void:
	if compatibility_accepted: return
	compatibility_accepted = true
	session_ready = true
	snapshot_waiting = not host
	snapshot_elapsed = 0
	status_changed.emit("Opponent connected · " + transport.label)
	opponent_connected.emit()
	if host: _send_snapshot("lobby")

func request(command: String, args: Dictionary = {}) -> bool:
	if applying: return false
	if not session_ready:
		status_changed.emit("Wait for an opponent before changing the table")
		return true
	if not host and not started:
		status_changed.emit("Waiting for the host's initial snapshot")
		return true
	request_id += 1
	var message := {"type": "request", "request_id": request_id, "sequence": game.battle_log.sequence, "command": command, "args": args}
	if host: _execute_request(message, 0)
	else: _send(message)
	return true

func _submit_action(action: GameAction) -> bool:
	if applying: return false
	var record := action.record()
	# A move is a local preview until the host accepts it. Restore the committed
	# position, never copy a remotely supplied "before" into the world.
	for change: Dictionary in record.changes:
		if change.property == "global_position":
			for category in ["models", "objectives", "terrain"]:
				for item: Dictionary in committed.get(category, []):
					if item.id == change.id:
						var object: Node3D = WorldState.registry(game).get(change.id)
						if object != null: object.global_position = ScenarioFactory.vector(item.position)
	request("action", {"record": record})
	return true

func _execute_request(message: Dictionary, team: int) -> void:
	if game.interaction.session != null or game.interaction.dragging != null or game.interaction.drag_object != null:
		if team == 1 or message.get("command") != "action":
			if team == 0: status_changed.emit("Confirm or cancel movement before another action")
			else: _send({"type": "rejected", "reason": "Host is placing models. Try again shortly."})
			return
	var error := NetworkAuthority.validate_request(game, message, team, committed)
	if not error.is_empty():
		if team == 0: status_changed.emit(error)
		else: _send({"type": "rejected", "reason": error})
		return
	applying = true
	var args: Dictionary = message.args
	if message.command in AssistanceService.COMMANDS:
		var issue := AssistanceService.execute(game, message.command, args, team)
		if not issue.is_empty():
			if team == 0: status_changed.emit(issue)
			else: _send({"type": "rejected", "reason": issue})
	match message.command:
		"action": game.history.perform(NetworkAuthority.to_action(game, args.record))
		"attack": game.combat.resolve(NetworkAuthority.unit(game, args.attacker), NetworkAuthority.unit(game, args.target), game.get_world_3d(), int(args.get("weapon_index", 0)))
		"allocate": game.combat.allocate(WorldState.registry(game)[args.model], int(args.amount))
		"remove_casualty": game.combat.remove_casualty(WorldState.registry(game)[args.model])
		"discard_damage": game.combat.discard_pending()
		"next_phase": game.manager.next_phase()
		"previous_phase": game.manager.previous_phase()
		"next_round": game.manager.next_round()
		"start_game": game.start_game()
		"undo": game.history.undo()
		"redo": game.history.redo()
		"dice":
			var result: Dictionary = game.dice.roll(int(args.count))
			game.battle_log.append("dice", result)
	applying = false
	_schedule_publish()

func _schedule_publish() -> void:
	if not host or not session_ready or publishing: return
	if not changed_pending:
		changed_pending = true
		call_deferred("_publish")

func _publish() -> void:
	changed_pending = false
	if not session_ready or not is_instance_valid(game): return
	committed = WorldState.capture(game)
	var events: Array = game.battle_log.entries.filter(func(event: Dictionary): return int(event.sequence) > last_sequence)
	last_sequence = game.battle_log.sequence
	hash_status = "host authoritative"
	_send({"type": "canonical", "events": events, "sequence": last_sequence, "state": committed, "hash": state_hash(committed), "dice": game.dice.history})
	synchronized.emit()

func _send_snapshot(kind := "snapshot") -> void:
	_send({"type": kind, "scenario": game.initial_scenario, "state": committed, "events": game.battle_log.entries, "sequence": game.battle_log.sequence, "hash": state_hash(committed), "dice": game.dice.history, "compatibility": compatibility})

func _send(message: Dictionary) -> void:
	if remote_id == 0 or api.multiplayer_peer == null: return
	message.version = NetworkCompatibility.PROTOCOL
	var bytes := JSON.stringify(message, "", true, true).to_utf8_buffer()
	if bytes.size() > 2000000: status_changed.emit("Network state exceeds 2 MB session limit"); return
	packet_id += 1
	var count := maxi(1, ceili(bytes.size() / 10000.0))
	for index in count:
		var frame := {"id": packet_id, "index": index, "count": count, "data": Marshalls.raw_to_base64(bytes.slice(index * 10000, (index + 1) * 10000))}
		var bytes_frame := JSON.stringify(frame).to_utf8_buffer()
		if debug_delay_ms > 0: delayed_frames.append({"due": Time.get_ticks_msec() + debug_delay_ms, "bytes": bytes_frame})
		else: api.send_bytes(bytes_frame, remote_id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

func _packet(id: int, bytes: PackedByteArray) -> void:
	if id != remote_id or bytes.size() > 16000: return
	var frame: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not frame is Dictionary or not ScenarioDefinition.integer(frame.get("id"), 1, 100000000) or not ScenarioDefinition.integer(frame.get("count"), 1, 200) or not ScenarioDefinition.integer(frame.get("index"), 0, int(frame.count) - 1) or not frame.get("data") is String or frame.data.length() > 14000: return
	if assembly.get("id") != frame.id:
		if frame.index != 0: return
		assembly = {"id": frame.id, "count": frame.count, "parts": []}
	if frame.index != assembly.parts.size() or frame.count != assembly.count: assembly.clear(); return
	var part := Marshalls.base64_to_raw(frame.data)
	if part.size() > 10000 or (int(frame.index) < int(frame.count) - 1 and part.size() != 10000): assembly.clear(); return
	assembly.parts.append(part)
	if assembly.parts.size() != int(frame.count): return
	var whole := PackedByteArray()
	for piece: PackedByteArray in assembly.parts: whole.append_array(piece)
	assembly.clear()
	var message: Variant = JSON.parse_string(whole.get_string_from_utf8())
	if not message is Dictionary or not message.get("type") is String: return
	if message.get("version") != NetworkCompatibility.PROTOCOL:
		_lost("This GrimTable build is incompatible with the host. Multiplayer protocol versions differ.")
		return
	quiet = 0
	_receive(message)

func _receive(message: Dictionary) -> void:
	if message.type == "hello":
		var issue := NetworkCompatibility.error_for(message.get("compatibility"))
		if not issue.is_empty():
			_send({"type": "incompatible", "reason": issue})
			_lost(issue)
		else: _accepted()
		return
	if message.type == "incompatible":
		_lost("This GrimTable build is incompatible with the host. Use matching versions and profiles.")
		return
	if not compatibility_accepted: return
	match message.type:
		"ping": _send({"type": "pong", "time": message.get("time", 0)})
		"pong":
			if ScenarioDefinition.number(message.get("time"), 0, Time.get_ticks_msec()): ping_ms = Time.get_ticks_msec() - int(message.time)
		"request":
			if not host: return
			requests_in_window += 1
			if requests_in_window > 20 or not ledger.accept(message.get("request_id")): return
			last_request = int(message.request_id)
			_execute_request(message, 1)
		"resync":
			if host and requests_in_window < 20: requests_in_window += 1; _send_snapshot()
		"rejected":
			if not host: status_changed.emit(str(message.get("reason", "Action rejected")))
		"lobby", "snapshot", "canonical":
			if host: return
			_apply_canonical(message)

func _apply_canonical(message: Dictionary) -> void:
	if message.type in ["lobby", "snapshot"] and not NetworkCompatibility.error_for(message.get("compatibility")).is_empty(): _lost("Incompatible host snapshot profiles/schema"); return
	var candidate: Variant = message.get("scenario", game.initial_scenario)
	if not candidate is Dictionary: _lost("Invalid host scenario"); return
	var scenario_data: Dictionary = candidate
	if not ScenarioDefinition.validate(scenario_data).is_empty(): _lost("Invalid host scenario"); return
	if not message.get("state") is Dictionary or not WorldState.validate(message.state, scenario_data).is_empty() or not message.get("events") is Array or not ScenarioDefinition.integer(message.get("sequence"), 0, 1000000): _lost("Invalid host state"); return
	var snapshot: bool = message.type in ["lobby", "snapshot"]
	var events: Array = message.events
	var combined: Array = events if snapshot else game.battle_log.entries + events
	if not ActionCodec.validate(combined, scenario_data).is_empty(): _lost("Invalid canonical action history"); return
	if not snapshot and not events.is_empty() and int(events[0].sequence) != last_sequence + 1: _request_resync(); return
	if int(message.sequence) != (int(combined.back().sequence) if not combined.is_empty() else 0): _lost("Invalid canonical sequence"); return
	applying = true
	game.interaction.cancel()
	if snapshot:
		game.apply_scenario(scenario_data)
		resolutions.clear()
	else:
		for event: Dictionary in events: ActionCodec.apply(event, game, resolutions)
	game.battle_log.restore(combined)
	WorldState.apply(game, message.state)
	game.history.changed.emit()
	game.hud.refresh_selection()
	committed = WorldState.capture(game)
	last_sequence = int(message.sequence)
	_restore_dice(message.get("dice", []))
	applying = false
	if state_hash(committed) != message.get("hash"):
		hash_status = "mismatch; resync requested"
		resync_attempts += 1
		if resync_attempts <= 2: _request_resync(); status_changed.emit("State differs · requesting host snapshot")
		else: _lost("State hash mismatch after synchronization")
		return
	resync_attempts = 0
	snapshot_waiting = false
	hash_status = "matched"
	started = true
	status_changed.emit("Lobby ready · Host controls scenario and Start Game" if message.type == "lobby" else "Synchronized · action %d" % last_sequence)
	synchronized.emit()

func _request_resync() -> void:
	if not snapshot_waiting: snapshot_elapsed = 0
	snapshot_waiting = true
	_send({"type": "resync"})

func _restore_dice(records: Variant) -> void:
	if not records is Array or records.size() > 8: return
	# Snapshot/UI refresh is not a new roll. Canonical events already emitted it.
	if state_hash({"records":records}) == state_hash({"records":game.dice.history}): return
	game.dice.history.clear()
	for record in records:
		if not record is Dictionary or not record.get("values") is Array: continue
		game.dice.history.append(record)
	if not game.dice.history.is_empty(): game.dice.rolled.emit(game.dice.history[0])

static func state_hash(state: Dictionary) -> String:
	return JSON.stringify(_canonical(state)).sha256_text()

static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys(); keys.sort()
		for key in keys: result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_canonical(item))
		return result
	# Integer fixed-point representation avoids -0, JSON int/float differences,
	# and platform float formatting differences in hashes.
	if value is float or value is int: return int(round(float(value) * 10000.0))
	return value

func _lost(reason: String) -> void:
	if transport == null: return
	if disconnected_once: return
	disconnected_once = true
	delayed_frames.clear()
	session_ready = false
	api.multiplayer_peer = null
	game.interaction.cancel()
	disconnected.emit(reason)
	status_changed.emit(reason)

func detach() -> void:
	delayed_frames.clear()
	if is_instance_valid(game):
		game.network_session = null
		game.interaction.can_control = Callable()
		game.history.submit = Callable()
		game.manager.submit = Callable()
		game.dice.submit = Callable()
		game.combat.submit = Callable()
	if transport != null: transport.close()
	api.multiplayer_peer = null
	transport = null
	session_ready = false

func diagnostics() -> String:
	return transport.diagnostics() + "\nRTT %s · sequence %d · Hash: %s · Gameplay: reliable / ordered" % [(str(ping_ms) + " ms") if ping_ms >= 0 else "pending", last_sequence, hash_status] if transport != null else "Offline"

