class_name NetworkSmoke
extends Node

var app: Node
var session: NetworkSession
var hosting := false
var failed := false
var checks := 0
var keep_signaling := false
var test_hold_seconds := 0.0

func run(application: Node, host_role: bool, code: String, lan := false, relay := false) -> void:
	app = application
	hosting = host_role
	var arguments := OS.get_cmdline_user_args()
	keep_signaling = "--keep-signaling" in arguments
	for argument in arguments:
		if argument.begins_with("--test-hold-seconds="): test_hold_seconds = clampf(float(argument.trim_prefix("--test-hold-seconds=")), 0, 300)
	var item := ScenarioLibrary.read(ScenarioLibrary.BUILTINS[0])
	if "--content-smoke" in arguments:
		for index in 2:
			var id := "legion_trooper" if index == 0 else "synthetic_drone"
			item.data.armies[index].unit_id = id
			item.data.armies[index].profile = ContentRegistry.path_for(id)
	# Deterministic open firing lane, using the real demo squads and definitions.
	item.data.terrain = []
	item.data.deployment_zones[0].center = [0, 14]
	item.data.deployment_zones[0].size = [60, 16]
	item.data.deployment_zones[1].center = [0, -14]
	item.data.deployment_zones[1].size = [60, 16]
	var transport: MultiplayerTransport
	if lan:
		var enet := ENetTransport.new()
		app.add_child(enet)
		check(enet.open(hosting, "127.0.0.1", 17777) == OK, "ENet opens")
		transport = enet
	else:
		var online := OnlineTransport.new()
		online.relay_only = relay
		app.add_child(online)
		online.room_created.connect(func(room: String): print("SMOKE ROOM ", room))
		check(online.open(hosting, app.settings.signaling_url, "Smoke Host" if hosting else "Smoke Guest", code) == OK, "signaling opens")
		transport = online
	app.online_menu.begin(transport, item)
	session = app.online_menu.session
	session.status_changed.connect(func(text: String): print("SMOKE STATUS ", text))
	session.disconnected.connect(func(reason: String): print("SMOKE DISCONNECT ", reason))
	if not await until(func(): return session.session_ready, "multiplayer connection establishes", 300 if "--public-test" in arguments else 55): finish(); return
	if not await until(func(): return (hosting or session.started) and app.game.battlefield.terrain.get_child_count() == 0, "scenario synchronized"): finish(); return
	if "--content-smoke" in arguments:
		for unit: TableUnit in app.game.battlefield.units.get_children():
			check(unit.definition.has("faction") and unit.models[0].visual_root.get_child_count() == 1, "faction profile and visual synchronized")
	await get_tree().create_timer(0.8).timeout
	if hosting and transport is OnlineTransport and not keep_signaling:
		transport.socket.close()
		print("SMOKE signaling closed intentionally; continuing on WebRTC")
	if transport is OnlineTransport and keep_signaling:
		transport.request_ice_refresh()
		if not await until(func(): return not transport.refreshing and transport.renewal_state.begins_with("fresh credentials cached"), "signaling credential refresh completes without replacing peer"): finish(); return
	if test_hold_seconds > 0:
		print("SMOKE HOLD ", test_hold_seconds, " seconds · failure injection window; gameplay should remain connected")
		await get_tree().create_timer(test_hold_seconds).timeout
		if not session.session_ready: check(false, "game connection survived failure injection window"); finish(); return
	if hosting: await host_steps()
	else: await guest_steps()
	finish()

func move(unit_id: String, offset: Vector3) -> void:
	var squad := NetworkAuthority.unit(app.game, unit_id)
	app.game.selection.select_unit(squad)
	app.game.interaction.set_mode(1)
	for model in squad.living_models():
		var origin := model.global_position
		model.global_position += offset
		app.game.interaction.session.stage(model, origin)
	check(app.game.interaction.confirm_unit_move(), "transaction confirms")

func position(id: String) -> Vector3:
	return WorldState.registry(app.game)[id].global_position

func host_steps() -> void:
	move("AlphaSquad", Vector3(0, 0, -5))
	if not await until(func(): return is_equal_approx(position("B1").z, -10), "guest deployment syncs"): return
	check(app.game.start_game(), "host starts battle")
	await get_tree().create_timer(0.5).timeout
	move("AlphaSquad", Vector3(0, 0, -3))
	await get_tree().create_timer(0.5).timeout
	app.game.undo_action()
	check(is_equal_approx(position("A1").z, 10), "movement undo")
	await get_tree().create_timer(0.5).timeout
	app.game.redo_action()
	check(is_equal_approx(position("A1").z, 7), "movement redo")
	await get_tree().create_timer(0.5).timeout
	app.game.dice.rng.seed = 1
	app.game.combat.resolve(NetworkAuthority.unit(app.game, "AlphaSquad"), NetworkAuthority.unit(app.game, "BravoSquad"), app.game.get_world_3d())
	await get_tree().create_timer(0.5).timeout
	check(app.game.combat.current != null, "host combat resolves")
	if app.game.combat.current == null: return
	print("SMOKE COMBAT ", JSON.stringify(app.game.combat.current.result))
	if not await until(func(): return app.game.combat.current.remaining == 0, "guest damage allocation synchronizes"): return
	if not await until(func(): return WorldState.registry(app.game)["B1"].removed, "guest casualty removal synchronizes"): return
	app.game.dice.roll(10)
	await get_tree().create_timer(1.0).timeout
	app.game.manager.next_phase()
	await get_tree().create_timer(1.0).timeout
	print("SMOKE HASH ", NetworkSession.state_hash(WorldState.capture(app.game)))
	print("SMOKE DICE ", JSON.stringify(app.game.dice.history))
	print("SMOKE OBJECTIVES ", objective_state())
	if not await until(func(): return not session.session_ready, "guest disconnect detected"): return

func guest_steps() -> void:
	if not await until(func(): return is_equal_approx(position("A1").z, 10), "host deployment syncs"): return
	move("BravoSquad", Vector3(0, 0, 5))
	if not await until(func(): return not app.game.manager.deployment, "battle starts"): return
	if not await until(func(): return app.game.combat.current != null, "canonical combat arrives"): return
	print("SMOKE COMBAT ", JSON.stringify(app.game.combat.current.result))
	while app.game.combat.current.remaining > 0:
		var model: Miniature
		for candidate in app.game.combat.current.target.living_models(): model = candidate; break
		if model == null: app.game.combat.discard_pending(); break
		var allocation: int = mini(model.wounds, app.game.combat.current.remaining)
		var expected_wounds := model.wounds - allocation
		app.game.combat.allocate(model, allocation)
		if not await until(func(): return model.wounds == expected_wounds, "damage confirmed by host"): return
		if model.wounds == 0:
			app.game.combat.remove_casualty(model)
			if not await until(func(): return model.removed, "casualty confirmed by host"): return
	if not await until(func(): return app.game.manager.phase == 1, "phase synchronizes"): return
	# Exercise explicit snapshot recovery after deliberate local state divergence.
	var expected := NetworkSession.state_hash(WorldState.capture(app.game))
	WorldState.registry(app.game)["A1"].wounds = 1
	session._send({"type": "resync"})
	if not await until(func(): return NetworkSession.state_hash(WorldState.capture(app.game)) == expected, "snapshot repairs divergent state"): return
	print("SMOKE HASH ", NetworkSession.state_hash(WorldState.capture(app.game)))
	print("SMOKE DICE ", JSON.stringify(app.game.dice.history))
	print("SMOKE OBJECTIVES ", objective_state())
	await get_tree().create_timer(1.0).timeout
	check(app.game.dice.history.size() == 1, "shared host dice history")

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition: failed = true
	print("SMOKE ", "PASS " if condition else "FAIL ", title)

func until(predicate: Callable, title: String, timeout_seconds := 55) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_seconds * 1000
	while not predicate.call() and Time.get_ticks_msec() < deadline and (session == null or not session.disconnected_once):
		await get_tree().create_timer(0.05).timeout
	var result: bool = predicate.call()
	check(result, title)
	return result

func finish() -> void:
	if session != null:
		print("SMOKE DIAGNOSTICS ", session.diagnostics().replace("\n", " | "))
	print("GRIMTABLE NETWORK SMOKE ", "FAIL" if failed else "PASS", " · ", "HOST" if hosting else "GUEST", " · ", checks, " checks")
	app.online_menu.close()
	get_tree().quit(1 if failed else 0)

func objective_state() -> String:
	var result := {}
	for objective: TableObjective in app.game.battlefield.objectives.get_children(): result[objective.object_id] = ObjectiveControl.evaluate(objective, app.game.battlefield.units.get_children())
	return JSON.stringify(result)
