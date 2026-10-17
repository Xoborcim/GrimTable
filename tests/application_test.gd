extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func frames(count: int = 3) -> void:
	for i in count: await process_frame

func run() -> void:
	root.size = Vector2i(1440, 900)
	var app: Node = load("res://scenes/main/app.tscn").instantiate()
	root.add_child(app)
	app.settings.autosave = false
	check(app.game == null and app.menu.visible, "Startup opens main menu")
	app.show_browser(true)
	check(app.browser_items.size() >= 2, "Browser lists demo and empty scenarios")
	check(app.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.BUILTINS[1]), true), "Editor launches from browser")
	await frames()
	check(app.game.editing and not app.game.hud.visible and app.editor_panel.visible, "Editor is separate from gameplay HUD")
	app.editor.set_tool(1)
	check(app.editor.place(Vector3.ZERO), "Editor placement works with UI connected")
	app.editor.set_tool(0)
	await physics_frame
	await physics_frame
	var piece := app.game.battlefield.terrain.get_child(0) as TerrainPiece
	var id := piece.object_id
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = app.game.camera_rig.camera.unproject_position(Vector3(0, 1.5, 0))
	root.push_input(press, true)
	check(app.editor.selected_kind == "terrain" and app.editor.selected_id == id, "Editor selection routed through existing interaction controller")
	var mouse := InputEventMouseMotion.new()
	mouse.position = app.game.camera_rig.camera.unproject_position(app.editor.drag_start + Vector3(3, 0, 0))
	root.push_input(mouse, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = mouse.position
	root.push_input(release, true)
	check(is_equal_approx(piece.position.x, 3), "Editor drag moves selected terrain")
	app.editor_panel.fields.rotation.value = 90
	app.editor_panel.fields.blocks_los.button_pressed = false
	app.editor_panel.apply_selected()
	piece = app.game.battlefield.terrain.get_child(0)
	check(is_equal_approx(rad_to_deg(piece.rotation.y), 90) and not piece.blocks_los, "Selected terrain properties update collision and transform")
	app.editor_panel.save_name.text = "UI Scenario"
	app.editor_panel.save_dialog.confirmed.emit()
	var custom_path: String = app.editor.path
	check(custom_path.begins_with("user://scenarios/") and FileAccess.file_exists(custom_path), "Save As writes custom scenario")
	check(app.editor_panel.scenario_name.text == "UI Scenario", "Save As updates scenario name field")
	app.editor_panel.apply_metadata()
	app.editor.save_scenario()
	check(ScenarioLibrary.read(custom_path).data.name == "UI Scenario", "Subsequent Save retains chosen scenario name")
	app.show_main()
	app.show_browser(false)
	check(app.browser_items.any(func(item: Dictionary): return item.get("path") == custom_path), "Saved scenario is discoverable after editor exit")
	var bad_path := ScenarioLibrary.DIRECTORY + "bad_validation.json"
	var file := FileAccess.open(bad_path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	app.show_browser(false)
	check(app.browser_items.any(func(item: Dictionary): return item.get("path") == bad_path and item.has("error")), "Malformed scenarios produce error entries, not crashes")
	check(not app.launch_scenario(ScenarioLibrary.read(bad_path)), "Malformed scenario cannot start")
	check(not app.status.text.is_empty(), "Scenario error is user-visible")
	DirAccess.remove_absolute(custom_path)
	DirAccess.remove_absolute(bad_path)
	app.settings.autosave = true
	app.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.BUILTINS[0]))
	app.game.start_game()
	await frames()
	DirAccess.remove_absolute("user://autosave.json")
	var unit := app.game.battlefield.units.get_child(0) as TableUnit
	app.game.selection.select_unit(unit)
	app.game.interaction.set_mode(1)
	var start := unit.models[0].global_position
	unit.models[0].global_position += Vector3(0, 0, 1)
	app.game.interaction.session.stage(unit.models[0], start)
	await frames()
	check(not FileAccess.file_exists("user://autosave.json"), "Provisional movement never auto-saves")
	check(app.game.interaction.confirm_unit_move(), "Confirmed squad action succeeds")
	await frames()
	check(FileAccess.file_exists("user://autosave.json"), "Confirmed movement triggers one auto-save")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://autosave.json"))
	check(SaveService.validate_document(saved).is_empty(), "Auto-save is a valid versioned game")
	app.game.manager.next_phase()
	await frames()
	saved = JSON.parse_string(FileAccess.get_file_as_string("user://autosave.json"))
	check(saved.turn.phase == 1, "Phase change auto-saves after recording transition")
	app.settings.autosave = false
	var message := ReplayController.save(app.game)
	check(message.begins_with("Saved"), "Replay archive saves independently")
	var replay_path := message.trim_prefix("Saved replay: ")
	check(app.open_replay(replay_path), "Replay screen loads saved action archive")
	check(app.game.replay_mode and app.game.interaction.read_only and app.replay_panel.visible, "Replay disables gameplay input")
	app.replay.seek(app.replay.events.size())
	check(app.replay.index == app.replay.events.size(), "Replay timeline reaches final action")
	check(app.replay_panel.caption.text.contains("Round 1") and app.replay_panel.caption.text.contains("Movement"), "Replayed phase/player state is visible")
	app.replay.seek(0)
	app.replay.play()
	check(app.replay.playing, "Replay play control")
	app.replay.pause()
	check(not app.replay.playing, "Replay pause control")
	DirAccess.remove_absolute(replay_path)
	audit("res://scripts")
	audit("res://resources")
	audit("res://scenes")
	app.show_main()
	await frames()
	print("GRIMTABLE APPLICATION: %d checks, %d failures" % [checks, failures])
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func audit(folder: String) -> void:
	for directory in DirAccess.get_directories_at(folder): audit(folder + "/" + directory)
	var expression := RegEx.new()
	expression.compile("res://[A-Za-z0-9_./-]+")
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() not in ["gd", "json", "tscn"]: continue
		var source := FileAccess.get_file_as_string(folder + "/" + file)
		for match in expression.search_all(source):
			var path := match.get_string()
			check(path == path.to_lower() and (FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)), "Portable resource reference: " + path)
