class_name PackagedSmoke
extends Node

var issue := ""

func verify(value: bool, description: String) -> void:
	if not value: issue += description + "; "

func picture(path: String) -> void:
	for i in 5: await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)

func run(app: Node) -> void:
	# Explicit opt-in packaged-build validation, independent of editor/source paths.
	var demo := ScenarioLibrary.read(ScenarioLibrary.BUILTINS[0])
	verify(demo.has("data"), "Bundled demo missing")
	if not issue.is_empty(): finish(); return
	verify(app.launch_scenario(demo), "Cannot launch demo")
	await get_tree().physics_frame
	verify(app.game.battlefield.units.get_child_count() == 2, "Units not loaded")
	verify(SaveService.save_game(app.game, app.game.manager, app.game.battle_log, app.game.combat, "user://packaged_smoke.json").begins_with("Saved"), "Game save failed")
	verify(SaveService.load_game(app.game, app.game.manager, app.game.battle_log, app.game.combat, "user://packaged_smoke.json").begins_with("Loaded"), "Game load failed")
	get_window().size = Vector2i(1280, 800)
	await picture("user://packaged_board.png")
	app.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.BUILTINS[1]), true)
	app.editor.set_tool(1)
	verify(app.editor.place(Vector3(-12, 0, 0)), "Editor terrain placement failed")
	app.editor.set_tool(2)
	verify(app.editor.place(Vector3(8, 0, 0)), "Editor objective placement failed")
	app.editor.profile_index = 1
	app.editor.unit_count = 3
	app.editor.set_tool(3)
	verify(app.editor.place(Vector3(0, 0, 16)), "Editor unit placement failed")
	app.editor.path = "user://scenarios/packaged_smoke.json"
	verify(app.editor.save_scenario().begins_with("Saved"), "Scenario save failed")
	var scenario := ScenarioLibrary.read(app.editor.path)
	verify(scenario.has("data"), "Scenario reload failed")
	await picture("user://packaged_editor.png")
	if scenario.has("data"):
		app.launch_scenario(scenario)
		verify(app.game.battlefield.units.get_child_count() == 1 and app.game.battlefield.terrain.get_child_count() == 1, "Custom scenario not rebuilt")
		app.game.start_game()
		var model: Miniature = app.game.battlefield.units.get_child(0).models[0]
		var origin := model.global_position
		model.global_position += Vector3(0, 0, 1)
		app.game.interaction.record_move(model, origin, "Packaged movement")
		var data := {"initial_scenario": app.game.initial_scenario.duplicate(true), "events": app.game.battle_log.entries.duplicate(true)}
		var replay := ReplayController.new()
		replay.game = app.game
		app.game.add_child(replay)
		verify(replay.open(data).is_empty(), "Packaged replay failed")
		replay.seek(replay.events.size())
		verify(app.game.battlefield.units.get_child(0).models[0].global_position.is_equal_approx(origin + Vector3(0, 0, 1)), "Packaged replay movement mismatch")
	var showcase := ScenarioLibrary.read("res://resources/scenarios/legion_vs_swarm.json")
	verify(showcase.has("data") and app.launch_scenario(showcase), "Packaged faction scenario missing")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var legion: TableUnit = app.game.battlefield.units.get_child(0)
	var swarm: TableUnit = app.game.battlefield.units.get_child(3)
	verify(legion.models[0].visual_root.get_child_count() == 1 and legion.definition.id == "legion_trooper", "Packaged faction visual/profile missing")
	verify(app.game.battlefield.terrain.get_child(1).get_child_count() > 0, "Packaged CC0 terrain missing")
	app.game.selection.select_unit(legion)
	app.game.interaction.set_mode(3)
	app.game.interaction.target_model = swarm.models[0]
	app.game.hud.combat_panel.show()
	app.game.hud.dice_panel.hide()
	app.game.dice.rng.seed = 42
	verify(app.game.combat.resolve(legion, swarm, app.game.get_world_3d()), "Packaged faction attack failed")
	if app.game.combat.current != null:
		verify(app.game.combat.current.result.hit_rolls.size() > 0, "Packaged exact dice missing")
		verify(app.game.combat.allocate(swarm.models[0], 1), "Packaged allocation failed")
		verify(app.game.combat.remove_casualty(swarm.models[0]), "Packaged casualty failed")
	var expected := WorldState.capture(app.game)
	verify(SaveService.save_game(app.game, app.game.manager, app.game.battle_log, app.game.combat, "user://packaged_content.json").begins_with("Saved"), "Packaged content save failed")
	verify(SaveService.load_game(app.game, app.game.manager, app.game.battle_log, app.game.combat, "user://packaged_content.json").begins_with("Loaded"), "Packaged content load failed")
	verify(WorldState.capture(app.game) == expected, "Packaged content state changed on load")
	await picture("user://packaged_content.png")
	var content_replay := ReplayController.new()
	content_replay.game = app.game
	app.game.add_child(content_replay)
	var content_archive := {"initial_scenario": app.game.initial_scenario.duplicate(true), "events": app.game.battle_log.entries.duplicate(true)}
	verify(content_replay.open(content_archive).is_empty(), "Packaged content replay open failed")
	content_replay.seek(content_replay.events.size())
	verify(WorldState.capture(app.game) == expected, "Packaged content replay diverged")
	DirAccess.remove_absolute("user://packaged_content.json")
	app.show_main()
	await picture("user://packaged_smoke.png")
	DirAccess.remove_absolute("user://packaged_smoke.json")
	DirAccess.remove_absolute("user://scenarios/packaged_smoke.json")
	finish()

func finish() -> void:
	var file := FileAccess.open("user://packaged_smoke_result.txt", FileAccess.WRITE)
	file.store_string("PASS" if issue.is_empty() else "FAIL: " + issue)
	file.close()
	print("PACKAGED SMOKE: ", "PASS" if issue.is_empty() else issue)
	get_tree().quit(0 if issue.is_empty() else 1)
