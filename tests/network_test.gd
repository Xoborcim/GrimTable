extends SceneTree

var checks := 0
var failures := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, title: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL · ", title)

func run() -> void:
	game = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new()
	game.settings.autosave = false
	root.add_child(game)
	await physics_frame
	var state := WorldState.capture(game)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(state))
	check(NetworkSession.state_hash(state) == NetworkSession.state_hash(parsed), "hash survives JSON float/int conversion")
	var reordered := {}
	var keys: Array = state.keys(); keys.reverse()
	for key in keys: reordered[key] = state[key]
	check(NetworkSession.state_hash(state) == NetworkSession.state_hash(reordered), "hash ignores dictionary insertion order")
	var changed := parsed.duplicate(true)
	changed.models[0].wounds = 1
	check(NetworkSession.state_hash(state) != NetworkSession.state_hash(changed), "hash detects state divergence")
	check(OnlineTransport.valid_url("wss://signal.example.com"), "WSS supported")
	check(OnlineTransport.valid_url("ws://127.0.0.1:8080"), "localhost development allowed")
	check(not OnlineTransport.valid_url("ws://signal.example.com:8080"), "remote cleartext signaling rejected")
	for url in ["", "https://example.com", "file:///secret", "ws://127.0.0.1.evil.com:8080"]:
		check(not OnlineTransport.valid_url(url), "invalid signaling URL rejected")
	var model: Miniature = WorldState.registry(game)["B1"]
	var delta := {"id": model.model_id, "property": "global_position", "before": ScenarioFactory.array(model.position), "after": ScenarioFactory.array(model.position + Vector3(0, 0, -1))}
	var record := {"title": "Move", "kind": "unit_move", "changes": [delta]}
	var request := {"command": "action", "args": {"record": record}, "sequence": 0}
	check(NetworkAuthority.validate_request(game, request, 1, state).is_empty(), "guest legal deployment accepted")
	check(model.position == ScenarioFactory.vector(delta.before), "validation restores preview")
	check(not NetworkAuthority.validate_request(game, request, 0, state).is_empty(), "ownership enforced on host too")
	var bad := request.duplicate(true)
	bad.sequence = 1
	check(not NetworkAuthority.validate_request(game, bad, 1, state).is_empty(), "stale action sequence rejected")
	bad = request.duplicate(true)
	bad.args.record.changes[0].after = [0, 0, 20]
	check(not NetworkAuthority.validate_request(game, bad, 1, state).is_empty(), "wrong deployment zone rejected")
	bad = request.duplicate(true)
	bad.args.record.changes[0].after = [200, 0, 0]
	check(not NetworkAuthority.validate_request(game, bad, 1, state).is_empty(), "board bounds enforced")
	bad = request.duplicate(true)
	bad.args.record.changes[0].after[1] = 4
	check(not NetworkAuthority.validate_request(game, bad, 1, state).is_empty(), "vertical movement rejected")
	bad = request.duplicate(true)
	bad.args.record.changes[0].before = [0, 0, 0]
	check(not NetworkAuthority.validate_request(game, bad, 1, state).is_empty(), "forged movement origin rejected")
	bad = request.duplicate(true)
	bad.args.record.changes[0].property = "script"
	check(not NetworkAuthority.validate_request(game, bad, 1, state).is_empty(), "arbitrary property rejected")
	bad = request.duplicate(true)
	bad.args.record.changes.append(bad.args.record.changes[0].duplicate(true))
	check(not NetworkAuthority.validate_request(game, bad, 1, state).is_empty(), "duplicate entity rejected")
	game.manager.deployment = false
	game.manager.active_team = 1
	state = WorldState.capture(game)
	bad = request.duplicate(true)
	bad.args.record.changes[0].after = ScenarioFactory.array(model.position + Vector3(0, 0, -7))
	check(not NetworkAuthority.validate_request(game, bad, 1, state).is_empty(), "movement allowance enforced")
	check(NetworkAuthority.validate_request(game, request, 1, state).is_empty(), "legal active-team movement accepted")
	bad = request.duplicate(true)
	bad.args.record.metadata = {"paths": {"B1": [delta.before, ScenarioFactory.array(model.position + Vector3(0, 0, -4)), delta.after]}}
	check(not NetworkAuthority.validate_request(game, bad, 1, state).is_empty(), "cumulative waypoint movement enforced")
	bad.args.record.metadata.paths.B1 = [delta.before, ScenarioFactory.array(model.position + Vector3(0, 0, -0.5)), delta.after]
	check(NetworkAuthority.validate_request(game, bad, 1, state).is_empty(), "legal waypoint route accepted")
	var action := NetworkAuthority.to_action(game, record)
	action.execute()
	check(model.position == ScenarioFactory.vector(delta.after), "validated action executes")
	action.undo()
	check(model.position == ScenarioFactory.vector(delta.before), "validated action undoes")
	check(not NetworkAuthority.validate_request(game, {"command": "attack", "sequence": 0, "args": {"attacker": "AlphaSquad", "target": "BravoSquad"}}, 1, state).is_empty(), "guest cannot attack with host unit")
	check(NetworkAuthority.validate_request(game, {"command": "attack", "sequence": 0, "args": {"attacker": "BravoSquad", "target": "AlphaSquad"}}, 1, state).is_empty(), "guest can request own attack")
	for command in ["start_game", "undo", "redo", "previous_phase", "next_round"]:
		check(not NetworkAuthority.validate_request(game, {"command": command, "sequence": 0, "args": {}}, 1, state).is_empty(), "guest session control rejected")
	check(not NetworkAuthority.validate_request(game, {"command": "dice", "sequence": 0, "args": {"count": 10001}}, 1, state).is_empty(), "dice request capped")
	check(NetworkAuthority.validate_request(game, {"command": "dice", "sequence": 0, "args": {"count": 10}}, 1, state).is_empty(), "dice request accepted")
	check(not NetworkAuthority.validate_request(game, {"command": "allocate", "sequence": 0, "args": {"model": "A1", "amount": 1}}, 1, state).is_empty(), "guest cannot allocate host wounds")
	check(not NetworkAuthority.validate_request(game, {"command": "shell", "sequence": 0, "args": {}}, 1, state).is_empty(), "unknown command rejected")
	var dice := {"sequence": 1, "kind": "dice", "payload": {"count": 3, "values": [6, 5, 1], "total": 12}}
	check(ActionCodec.validate([dice], game.scenario).is_empty(), "canonical dice serializable")
	ActionCodec.apply(dice, game, {})
	check(game.dice.history[0].values == [6, 5, 1], "recorded dice replay exactly")
	dice.payload.total = 99
	check(not ActionCodec.validate([dice], game.scenario).is_empty(), "invalid dice total rejected")
	var session := NetworkSession.new()
	root.add_child(session)
	var transport := ENetTransport.new()
	transport.is_host = true
	root.add_child(transport)
	session.open(transport, game)
	session.session_ready = true
	game.interaction.set_mode(1)
	game.selection.select_unit(model.get_parent())
	session.request("next_phase")
	check(game.manager.phase == 0, "transaction blocks phase mutation")
	game.interaction.cancel()
	session.detach()
	check(not game.history.submit.is_valid() and game.network_session == null, "continue locally detaches network hooks")
	game.queue_free(); session.queue_free(); transport.queue_free()
	await process_frame
	var app: Node = load("res://scenes/main/app.tscn").instantiate()
	root.add_child(app)
	app.settings.autosave = false
	app.online_menu.show_menu()
	check(app.menu.visible and app.game == null, "multiplayer menu opens independently")
	app.online_menu.form(true)
	check(is_instance_valid(app.online_menu.name_field) and app.online_menu.scenarios.size() >= 2, "host form exposes player name and scenarios")
	app.online_menu.form(false)
	check(app.online_menu.code_field.max_length == 6, "join form exposes short room code")
	app.online_menu.settings()
	check(app.online_menu.server_field.text == app.settings.signaling_url, "custom signaling setting shown")
	app.show_main()
	app.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.BUILTINS[0]))
	app.show_pause()
	check(app.game.menu_open and app.game.interaction.read_only, "pause gates gameplay input")
	app.resume()
	check(not app.game.menu_open and not app.game.interaction.read_only, "resume restores tabletop input")
	app.queue_free()
	await process_frame
	print("GRIMTABLE NETWORK CHECKS ", checks, " · ", "PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
