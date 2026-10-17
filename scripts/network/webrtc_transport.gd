class_name OnlineTransport
extends MultiplayerTransport

var socket := WebSocketPeer.new()
var connection: WebRTCPeerConnection
var code := ""
var player_name := "Player"
var requested := false
var join_code := ""
var elapsed := 0.0
var negotiating := false
var signal_open := false
var failed := false
var remote_set := false
var candidates: Array[Dictionary] = []
# Diagnostic test switch: strip non-relay candidates from SDP and trickle ICE.
# The pinned native plugin does not expose iceTransportPolicy or selected-route stats.
var relay_only := false
var signaling_url := ""
var secure_url := false
var session_token := ""
var lease := TurnLease.new()
var refreshing := false
var refresh_elapsed := 0.0
var retry_elapsed := 0.0
var retry_delay := 5.0
var renewal_state := "not needed"
var local_types: Dictionary = {}
var remote_types: Dictionary = {}
var gathering_elapsed := 0.0
var signal_warning_shown := false
const SIGNAL_TIMEOUT := 15.0
const NEGOTIATION_TIMEOUT := 45.0

static func valid_url(url: String) -> bool:
	if url.begins_with("wss://") and url.length() > 6: return true
	return url.begins_with("ws://127.0.0.1:") or url.begins_with("ws://localhost:") or url.begins_with("ws://[::1]:")

func open(hosting: bool, url: String, display_name: String, room := "") -> Error:
	if not valid_url(url): return ERR_INVALID_PARAMETER
	is_host = hosting
	signaling_url = url
	secure_url = url.begins_with("wss://")
	relay_only = relay_only or "--force-turn" in OS.get_cmdline_user_args()
	label = "ONLINE"
	player_name = display_name.left(32)
	join_code = room.strip_edges().to_upper()
	status_changed.emit("SIGNALING…")
	socket.inbound_buffer_size = 262144
	socket.outbound_buffer_size = 262144
	return socket.connect_to_url(url)

func send_signal(message: Dictionary) -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	message.version = 1
	socket.send_text(JSON.stringify(message))

func _process(delta: float) -> void:
	if failed: return
	elapsed += delta
	socket.poll()
	var state := socket.get_ready_state()
	signal_open = state == WebSocketPeer.STATE_OPEN
	if signal_open:
		if refreshing:
			if not lease.refresh_pending:
				lease.refresh_pending = true
				send_signal({"type": "refresh_ice", "room_code": code, "session_token": session_token})
		elif not requested:
			requested = true
			send_signal({"type": "create_room" if is_host else "join_room", "player_name": player_name, "room_code": join_code, "capabilities": ["credential_refresh"]})
		while socket.get_available_packet_count() > 0:
			var packet := socket.get_packet()
			if packet.size() > 65536: _fail("Signaling message too large"); return
			var message: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if not message is Dictionary or message.get("version") != 1 or not message.get("type") is String:
				_fail("Invalid signaling protocol"); return
			_handle(message)
	elif state == WebSocketPeer.STATE_CLOSED and not connected:
		_fail(signaling_error(secure_url))
		return
	elif state == WebSocketPeer.STATE_CLOSED and connected:
		if not signal_warning_shown:
			signal_warning_shown = true
			status_changed.emit("Signaling unavailable; gameplay connection is still active.")
		if refreshing: _refresh_failed("Signaling unavailable; credential refresh will retry.")
	if connected:
		_tick_renewal(delta)
	if connection != null:
		# SceneMultiplayer polls the WebRTCMultiplayerPeer after it is attached.
		var connection_state := connection.get_connection_state()
		if connection_state in [WebRTCPeerConnection.STATE_FAILED, WebRTCPeerConnection.STATE_CLOSED, WebRTCPeerConnection.STATE_DISCONNECTED]:
			_fail("Game connection lost. If a relay was required, check TURN availability. Return to the menu to reconnect." if connected else ice_failure())
		if connection.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_GATHERING:
			gathering_elapsed += delta
			if not connected and gathering_elapsed > 35: _fail(ice_failure())
	if not connected and ((code.is_empty() and elapsed > SIGNAL_TIMEOUT) or (negotiating and elapsed > NEGOTIATION_TIMEOUT)):
		_fail(signaling_error(secure_url) if code.is_empty() else ice_failure())

static func signaling_error(secure: bool) -> String:
	return "Secure signaling connection failed. Check the server hostname, TLS certificate chain and service availability." if secure else "Unable to reach signaling server. Check the address and start the local service."

func ice_failure() -> String:
	if relay_only and not local_types.has("relay"):
		return "No relay candidate was gathered. Check TURN DNS, credentials/expiry, listening ports and server public IP."
	if relay_only:
		return "Relay connection timed out. Check the configured TURN relay UDP port range and public/relay IP configuration."
	return "NAT traversal failed. Check STUN/TURN availability, temporary credentials and relay firewall ports; try a different network."

func _tick_renewal(delta: float) -> void:
	retry_elapsed = maxf(0, retry_elapsed - delta)
	if refreshing:
		refresh_elapsed += delta
		if refresh_elapsed > SIGNAL_TIMEOUT: _refresh_failed("Credential refresh timed out; gameplay continues while the peer remains connected.")
	elif lease.due(Time.get_ticks_msec()) and retry_elapsed <= 0:
		request_ice_refresh()
	if lease.active_expires_at_msec > 0 and Time.get_ticks_msec() >= lease.active_expires_at_msec - 60000 and not lease.warning_shown:
		lease.warning_shown = true
		status_changed.emit("Original TURN credentials expire soon. This native peer cannot apply refreshed credentials live. Save the game if a relay is required.")

func request_ice_refresh() -> void:
	if refreshing or not connected: return
	if not IceConfiguration.token_valid(session_token):
		renewal_state = "server does not support authenticated refresh"
		retry_elapsed = 300
		return
	refreshing = true
	refresh_elapsed = 0
	renewal_state = "requesting fresh credentials"
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		lease.refresh_pending = true
		send_signal({"type": "refresh_ice", "room_code": code, "session_token": session_token})
	else:
		socket = WebSocketPeer.new()
		socket.inbound_buffer_size = 262144
		socket.outbound_buffer_size = 262144
		lease.refresh_pending = false
		if socket.connect_to_url(signaling_url) != OK: _refresh_failed("Unable to reconnect signaling for credential refresh.")

func _refresh_failed(reason: String) -> void:
	refreshing = false
	lease.refresh_pending = false
	renewal_state = reason
	retry_elapsed = retry_delay
	retry_delay = minf(300, retry_delay * 2)

func _handle(message: Dictionary) -> void:
	match message.type:
		"room_created", "room_joined":
			if not message.get("room_code") is String or message.room_code.length() != 6 or not message.get("ice_servers") is Array:
				_fail("Invalid room response"); return
			for character in message.room_code:
				if not character in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789": _fail("Invalid room code returned by server"); return
			code = message.room_code
			if message.has("session_token"):
				if not IceConfiguration.token_valid(message.session_token): _fail("Invalid signaling session token"); return
				session_token = message.session_token
			var error := lease.accept(message, Time.get_ticks_msec(), true)
			if not error.is_empty(): _fail(error); return
			if not _setup(message.ice_servers): return
			room_created.emit(code)
			status_changed.emit("ROOM " + code + " · Waiting for opponent…" if is_host else "CONNECTING…")
			if not is_host: negotiating = true; elapsed = 0
		"peer_joined":
			if connection == null or not is_host: return
			negotiating = true
			elapsed = 0
			status_changed.emit("CONNECTING · ICE checks / relay fallback…")
			if connection.create_offer() != OK: _fail("Could not create WebRTC offer")
		"offer", "answer":
			if connection == null or not message.get("sdp") is String or message.sdp.length() > 60000 or (message.type == "offer") == is_host:
				_fail("Invalid WebRTC description"); return
			for line in message.sdp.split("\n"):
				if line.begins_with("a=candidate:"): remote_types[IceConfiguration.candidate_type(line)] = true
			if connection.set_remote_description(message.type, _filter_sdp(message.sdp)) != OK:
				_fail("WebRTC negotiation failed"); return
			remote_set = true
			for candidate in candidates: _add_candidate(candidate)
			candidates.clear()
		"ice_candidate":
			if not message.get("candidate") is String or message.candidate.length() > 2048 or not message.get("media") is String or message.media.is_empty() or message.media.length() > 128 or not ScenarioDefinition.integer(message.get("index"), 0, 32):
				_fail("Invalid ICE message"); return
			if remote_set: _add_candidate(message)
			elif candidates.size() < 256: candidates.append(message)
		"ice_credentials":
			if not refreshing: return
			var error := lease.accept(message, Time.get_ticks_msec())
			if not error.is_empty(): _refresh_failed(error); return
			refreshing = false
			retry_delay = 5
			renewal_state = "fresh credentials cached for a future peer; live peer unchanged"
			signal_warning_shown = false
		"signaling_unavailable":
			if connected: status_changed.emit("Opponent signaling unavailable; gameplay connection is still active.")
		"peer_left":
			# Signaling loss is independent of an established data connection.
			if not connected: _fail(str(message.get("reason", "Opponent left")))
		"error":
			if refreshing:
				_refresh_failed(str(message.get("message", "Credential refresh rejected")))
				if message.get("code") == "invalid_session": session_token = ""; lease.renew_at_msec = 0
			elif not connected: _fail(str(message.get("message", "Signaling error")))
			elif message.get("code") == "room_expired":
				session_token = ""
				lease.renew_at_msec = 0
				renewal_state = "signaling match lease expired; gameplay peer unchanged"
				status_changed.emit("Signaling lease expired; gameplay connection is still active. Credential refresh is unavailable for this match.")
		"pong": pass
		_: _fail("Unknown signaling message")

func _setup(servers: Array) -> bool:
	var configuration_error := IceConfiguration.validate(servers)
	if not configuration_error.is_empty(): _fail(configuration_error); return false
	if relay_only and not IceConfiguration.has_turn(servers):
		_fail("Forced TURN requires a configured TURN server. Ask the server operator to configure TURN_URLS."); return false
	connection = WebRTCPeerConnection.new()
	if connection.initialize({"iceServers": servers}) != OK: _fail("Native WebRTC initialization failed"); return false
	connection.session_description_created.connect(func(type: String, sdp: String):
		if connection.set_local_description(type, sdp) != OK: _fail("Local WebRTC description failed"); return
		send_signal({"type": type, "sdp": _filter_sdp(sdp)}))
	connection.ice_candidate_created.connect(func(media: String, index: int, candidate: String):
		local_types[IceConfiguration.candidate_type(candidate)] = true
		if not relay_only or " typ relay" in candidate: send_signal({"type": "ice_candidate", "media": media, "index": index, "candidate": candidate}))
	var rtc := WebRTCMultiplayerPeer.new()
	var error := rtc.create_server() if is_host else rtc.create_client(2)
	if error != OK or rtc.add_peer(connection, 2 if is_host else 1) != OK: _fail("WebRTC multiplayer setup failed"); return false
	peer = rtc
	peer_ready.emit()
	return true

func _filter_sdp(sdp: String) -> String:
	var result := PackedStringArray()
	for line in sdp.split("\n"):
		if relay_only and line.begins_with("a=candidate:") and IceConfiguration.candidate_type(line) != "relay": continue
		result.append(line)
	return "\n".join(result)

func _add_candidate(message: Dictionary) -> void:
	remote_types[IceConfiguration.candidate_type(message.candidate)] = true
	if relay_only and not " typ relay" in message.candidate: return
	if connection.add_ice_candidate(message.media, int(message.index), message.candidate) != OK: _fail("ICE candidate rejected")

func reliable_channel_ok(id: int) -> bool:
	if not peer is WebRTCMultiplayerPeer or not peer.has_peer(id): return false
	var channels: Array = peer.get_peer(id).get("channels", [])
	if channels.is_empty(): return false
	var channel: WebRTCDataChannel = channels[0]
	return channel.is_ordered() and channel.get_max_packet_life_time() in [-1, 65535] and channel.get_max_retransmits() in [-1, 65535]

func _fail(reason: String) -> void:
	if failed: return
	failed = true
	status_changed.emit(reason)
	connection_lost.emit(reason)

func diagnostics() -> String:
	return "ONLINE · Signaling %s · SDP state %s · Peer %s · ICE gathering %s\nLocal candidate types: %s · Remote: %s\nSelected pair / ICE connection state: unavailable · Route: unavailable\nTURN renewal: %s · Force TURN: %s" % ["connected" if signal_open else "unavailable (independent of gameplay)", str(connection.get_signaling_state()) if connection != null else "new", str(connection.get_connection_state()) if connection != null else "new", str(connection.get_gathering_state()) if connection != null else "new", str(local_types.keys()), str(remote_types.keys()), renewal_state, str(relay_only)]

func close() -> void:
	failed = true
	send_signal({"type": "close_room"})
	socket.close()
	session_token = ""
	lease.servers.clear()
	if connection != null: connection.close()
	super.close()
