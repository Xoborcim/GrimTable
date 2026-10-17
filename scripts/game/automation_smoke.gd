class_name AutomationSmoke
extends Node

var failures: Array[String] = []
var checks := 0

func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text); push_error("AUTOMATION SMOKE: " + text)

func settle() -> void:
	for i in 5: await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func run(app: Node) -> void:
	app.settings.autosave = false
	app.settings.camera_assistance = false
	app.settings.combat_camera = false
	check(app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json")), "Ashfall showcase opens")
	var game: Node3D = app.game
	await settle()
	check(game.battlefield.units.get_child_count() == 6, "Showcase models load")
	game.selection.select_unit(game.battlefield.units.get_child(0))
	await capture("user://automation_showcase.png")
	# A small deterministic training lane exercises all new interactions without
	# asking a formation convenience tool to pathfind around showcase bulkheads.
	var data: Dictionary = game.scenario.duplicate(true)
	data.armies = [data.armies[0], data.armies[5]]
	for i in data.armies[0].models.size(): data.armies[0].models[i].position = [(i - 2) * 1.5, 0, 8]
	data.armies[1].models[0].position = [0, 0, -6]
	data.terrain = [{"id": "rubble", "title": "Rubble", "kind": "box", "size": [12, .1, 2], "position": [0, 0, 4], "blocks_movement": false, "blocks_los": false, "movement_penalty": 2}]
	data.objectives = [{"id": "relay", "name": "Training relay", "number": 1, "radius": 3, "position": [0, 0, -4]}]
	data.starting_state = {"round": 1, "phase": 1, "team": 0, "deployment": false}
	game.apply_scenario(data)
	await settle()
	var unit: TableUnit = game.battlefield.units.get_child(0)
	var enemy: TableUnit = game.battlefield.units.get_child(1)
	game.selection.select_unit(unit)
	game.assistance.move_button.pressed.emit()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.camera_rig.camera.unproject_position(Vector3(0, 0, 4))
	get_viewport().push_input(click, true)
	check(game.interaction.session != null and game.interaction.session.validation_error().is_empty(), "Destination click creates legal formation")
	check(FormationPlanner.center(unit.living_models()).distance_to(Vector3(0, 0, 4)) < .02, "Preview reaches requested anchor")
	await capture("user://automation_move.png")
	check(game.interaction.confirm_unit_move(), "One Confirm commits move")
	check(int(game.assistance.state(unit).get("moved", 0)) == 1, "Moved status automatic")
	check(AssistanceService.request(game, "referee", {"field": "phase", "value": 2}), "Shooting phase correction recorded")
	game.assistance.begin_attack()
	check(game.assistance.target == enemy, "Unique legal target defaults reversibly")
	check(game.assistance.available.size() == 1, "Only usable ranged weapon defaults")
	await capture("user://automation_attack.png")
	check(game.assistance.commit_button.get_global_rect().end.y < get_viewport().get_visible_rect().size.y - 135, "Attack confirmation visible without scrolling")
	check(game.hud.confirm_move.get_parent().get_parent().get_parent() == game.assistance.quick_card, "Movement confirmation uses decision panel")
	game.dice.rng.seed = 42
	game.assistance.commit_button.pressed.emit()
	check(game.combat.current != null and game.combat.current.result.attacks == 10, "Single confirmation rolls automatic attack count")
	if game.combat.current == null: finish(); return
	var exact: Array = game.combat.current.result.hit_rolls.duplicate()
	while game.combat.current.remaining > 0:
		var before: int = game.combat.current.remaining
		game.assistance.apply_suggestion()
		if game.combat.current.remaining >= before: check(false, "Damage allocation progresses"); break
	game.hud.combat_panel.continue_batch()
	check(game.combat.current.remaining == 0, "Allocation performs damage arithmetic")
	check(AssistanceService.request(game, "referee", {"field": "phase", "value": 3}), "Charge phase correction recorded")
	game.assistance.begin_charge()
	game.assistance.choose_target(enemy)
	game.dice.rng.seed = 42
	game.assistance.commit_button.pressed.emit()
	await settle()
	check(game.interaction.session != null and game.interaction.session.allowance == 11, "Charge dice give canonical 11 inch movement budget")
	if game.interaction.session == null: finish(); return
	check(game.interaction.session.validation_error().is_empty(), "Automatic charge formation legal after terrain costs")
	await capture("user://automation_charge.png")
	check(game.interaction.confirm_unit_move(), "Player confirms charge destination")
	check(int(game.assistance.state(unit).get("charged", 0)) == 1, "Charge completion tracked")
	check(AssistanceService.request(game, "referee", {"field": "phase", "value": 4}), "Fight phase correction recorded")
	game.assistance.begin_attack()
	check(not game.assistance.available.is_empty() and game.assistance.available[0].weapon.get("type") == "melee", "Attack detects melee context")
	game.assistance.commit_button.pressed.emit()
	while game.combat.current.remaining > 0:
		var recipient := AttackOptions.suggested(game.combat.current)
		if recipient == null: game.combat.discard_pending(); break
		game.assistance.apply_suggestion()
	game.hud.combat_panel.continue_batch()
	check(AssistanceService.request(game, "end_turn"), "End Turn skips unnecessary phase substeps")
	check(AssistanceService.request(game, "end_turn"), "Defender may pass turn")
	check(int(game.manager.scores["0"]) > 0, "Scoring automatically awards controlled relay")
	var expected := WorldState.capture(game)
	check(SaveService.save_game(game, game.manager, game.battle_log, game.combat, "user://automation_smoke.json").begins_with("Saved"), "Save writes")
	check(SaveService.load_game(game, game.manager, game.battle_log, game.combat, "user://automation_smoke.json").begins_with("Loaded"), "Load reads")
	check(WorldState.capture(game) == expected, "Load preserves exact charge/combat/score state")
	var replay := ReplayController.new()
	replay.game = game
	game.add_child(replay)
	check(replay.open({"initial_scenario": game.initial_scenario, "events": game.battle_log.entries.duplicate(true)}).is_empty(), "Replay opens")
	replay.seek(replay.events.size())
	check(WorldState.capture(game) == expected, "Replay reconstructs all automation exactly")
	check(not exact.is_empty(), "Canonical dice retained")
	game.replay_mode = false
	game.interaction.read_only = false
	data.starting_state = {"round": 1, "phase": 0, "team": 0, "deployment": true}
	game.apply_scenario(data)
	game.hud.show()
	await settle()
	game.assistance.ready()
	game.assistance.refresh()
	check(game.assistance.focus_button.is_visible_in_tree(), "Deployment problem provides visible Focus")
	await capture("user://automation_ready.png")
	check(AssistanceService.request(game, "auto_deploy"), "Auto Deploy places armies legally")
	game.assistance.ready()
	check(not game.manager.deployment, "Ready validates and starts battle")
	finish()

func finish() -> void:
	print("GRIMTABLE AUTOMATION SMOKE: %d checks / %d failures %s" % [checks, failures.size(), str(failures)])
	get_tree().quit(0 if failures.is_empty() else 1)
