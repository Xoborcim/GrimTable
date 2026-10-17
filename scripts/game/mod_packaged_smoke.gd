class_name ModPackagedSmoke
extends Node

func run(app: Node) -> void:
	var issues: Array[String] = []
	if ContentRegistry.catalog().units.size() < 16: issues.append("Built-in content missing")
	if not DirAccess.dir_exists_absolute("user://mods"): issues.append("Mods directory not created")
	if not ModLoader.loaded.has("example_army"): issues.append("Installed example_army not loaded: " + str(ModLoader.entries))
	if issues.is_empty():
		var path: String = ContentRegistry.catalog().scenarios.get("example_army:outpost", "")
		if path.is_empty() or not app.launch_scenario(ScenarioLibrary.read(path)): issues.append("External scenario cannot start")
	if issues.is_empty():
		app.settings.autosave = false
		await get_tree().physics_frame
		await get_tree().physics_frame
		if app.game.battlefield.units.get_child(0).definition.id != "example_army:infantry": issues.append("Wrong external profile")
		app.game.hud.dice_panel.hide()
		app.game.selection.select_unit(app.game.battlefield.units.get_child(0))
		for i in 6: await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://mod_packaged_smoke.png")
	var file := FileAccess.open("user://mod_packaged_smoke_result.txt", FileAccess.WRITE)
	file.store_string("PASS" if issues.is_empty() else "FAIL: " + str(issues))
	file.close()
	print("MOD PACKAGED SMOKE: ", "PASS" if issues.is_empty() else str(issues))
	get_tree().quit(0 if issues.is_empty() else 1)
