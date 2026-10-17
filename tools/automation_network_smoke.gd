extends SceneTree

var session: NetworkSession
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func wait_for(condition: Callable) -> bool:
	var limit := Time.get_ticks_msec() + 16000
	while not condition.call() and Time.get_ticks_msec() < limit: await process_frame
	return condition.call()

func fail(reason: String) -> void:
	print("GRIMTABLE AUTOMATION NETWORK FAIL: ", reason)
	quit(1)

func run() -> void:
	var host := "--host" in OS.get_cmdline_user_args()
	game = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new()
	game.settings.autosave = false
	game.settings.camera_assistance = false
	game.settings.combat_summary = false
	game.settings.particles = false
	var data: Dictionary = ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json").data.duplicate(true)
	data.armies = [data.armies[0], data.armies[5]]
	data.armies[1].models[0].position = [-10, 0, -8]
	data.terrain = [{"id": "cover", "title": "Cover test", "kind": "box", "size": [8, .1, 6], "position": [-10, 0, -8], "blocks_movement": false, "blocks_los": false, "cover_bonus": 0}]
	data.objectives = [{"id": "relay", "number": 1, "name": "Relay", "position": [-10, 0, 8], "radius": 3}]
	data.starting_state = {"round": 1, "phase": 2, "team": 0, "deployment": false}
	game.scenario = data
	root.add_child(game)
	var transport := ENetTransport.new()
	root.add_child(transport)
	if transport.open(host, "127.0.0.1", 17807) != OK: fail("transport open"); return
	session = NetworkSession.new()
	game.add_child(session)
	session.open(transport, game)
	if not await wait_for(func(): return session.session_ready and (host or session.started)): fail("matching build handshake"); return
	if host:
		await create_timer(.2).timeout
		game.selection.select_unit(game.battlefield.units.get_child(0))
		game.assistance.begin_attack()
		game.assistance.choose_target(game.battlefield.units.get_child(1))
		game.dice.rng.seed = 42
		game.assistance.confirm_attack()
	if not await wait_for(func(): return game.combat.current != null): fail("automatic attack"); return
	var result: Dictionary = game.combat.current.result.duplicate(true)
	if int(result.damage) < 1: fail("fixture must exercise positive defender allocation"); return
	if not host:
		while game.combat.current.remaining > 0:
			var before: int = game.combat.current.remaining
			game.assistance.apply_suggestion()
			if not await wait_for(func(): return game.combat.current.remaining < before): fail("defender allocation"); return
	if not await wait_for(func(): return game.combat.current.remaining == 0): fail("damage synchronization"); return
	if host:
		if not await wait_for(func(): return not game.hud.combat_panel.batch_running): fail("group completion"); return
		AssistanceService.request(game, "end_turn")
	else:
		if not await wait_for(func(): return game.manager.active_team == 1): fail("guest turn"); return
		AssistanceService.request(game, "end_turn")
	if not await wait_for(func(): return game.manager.round_number == 2 and int(game.manager.scores["0"]) == 1): fail("automatic scoring"); return
	await create_timer(.6 if host else .2).timeout
	print("GRIMTABLE AUTOMATION NETWORK ", "HOST" if host else "GUEST", " dice=", result.hit_rolls, " damage=", result.damage, " remaining=", game.combat.current.remaining, " score=", game.manager.scores, " hash=", NetworkSession.state_hash(WorldState.capture(game)))
	quit()
