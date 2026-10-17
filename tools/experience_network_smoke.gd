extends SceneTree

var session: NetworkSession
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func wait_for(condition: Callable) -> bool:
	var limit := Time.get_ticks_msec() + 12000
	while not condition.call() and Time.get_ticks_msec() < limit:
		await process_frame
	return condition.call()

func run() -> void:
	var host := "--host" in OS.get_cmdline_user_args()
	game = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new()
	game.settings.autosave = false
	game.settings.combat_summary = false
	game.settings.particles = false
	game.scenario = ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json").data
	game.scenario.terrain = [{"id": "cover_test", "title": "Explicit cover test", "kind": "box", "size": [12, .1, 6], "position": [-10, 0, -8], "blocks_movement": false, "blocks_los": false, "cover_bonus": 1}]
	root.add_child(game)
	var transport := ENetTransport.new()
	root.add_child(transport)
	if transport.open(host, "127.0.0.1", 17806) != OK: quit(1); return
	session = NetworkSession.new()
	game.add_child(session)
	session.open(transport, game)
	if not await wait_for(func(): return session.session_ready and (host or session.started)):
		print("GRIMTABLE 0.6 COMPATIBILITY FAIL: handshake")
		quit(1); return
	if host:
		await create_timer(.3).timeout
		game.dice.rng.seed = 42
		game.combat.resolve(game.battlefield.units.get_child(0), game.battlefield.units.get_child(3), game.get_world_3d())
	if not await wait_for(func(): return game.combat.current != null):
		print("GRIMTABLE 0.6 COMPATIBILITY FAIL: attack")
		quit(1); return
	await create_timer(.6 if host else .2).timeout
	var result: Dictionary = game.combat.current.result
	print("GRIMTABLE 0.6 COMPATIBILITY ", "HOST" if host else "GUEST", " cover=", result.get("cover_bonus"), " dice=", result.hit_rolls, " hash=", NetworkSession.state_hash(WorldState.capture(game)))
	quit(0 if int(result.get("cover_bonus", 0)) == 1 and NetworkCompatibility.error_for(NetworkCompatibility.manifest()).is_empty() else 1)
