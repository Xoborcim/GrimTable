extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.runtime")
	var app: Node = load("res://scenes/main/app.tscn").instantiate()
	root.add_child(app)
	await capture("res://.runtime/main_menu.png")
	app.show_browser(true)
	await capture("res://.runtime/scenario_browser.png")
	app.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.BUILTINS[1]), true)
	app.editor.terrain_index = 1
	app.editor.set_tool(1)
	app.editor.place(Vector3(0, 0, 0))
	app.editor.set_tool(2)
	app.editor.place(Vector3(-10, 0, 2))
	app.editor.set_tool(3)
	app.editor.place(Vector3(10, 0, 10))
	app.editor.set_tool(0)
	app.editor.selected_kind = "terrain"
	app.editor.selected_id = app.game.battlefield.terrain.get_child(0).object_id
	app.editor_panel.refresh()
	await capture("res://.runtime/scenario_editor.png")
	app.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.BUILTINS[0]))
	app.game.start_game()
	app.game.manager.next_phase()
	var model: Miniature = app.game.battlefield.units.get_child(0).models[0]
	var origin := model.global_position
	model.global_position += Vector3(0, 0, 1)
	app.game.interaction.record_move(model, origin, "Move Alpha")
	var data := {"initial_scenario": app.game.initial_scenario.duplicate(true), "events": app.game.battle_log.entries.duplicate(true)}
	var replay := ReplayController.new()
	replay.game = app.game
	app.game.add_child(replay)
	replay.open(data)
	var panel := ReplayPanel.new()
	panel.controller = replay
	app.game.add_child(panel)
	replay.seek(replay.events.size())
	await capture("res://.runtime/replay.png")
	quit()
