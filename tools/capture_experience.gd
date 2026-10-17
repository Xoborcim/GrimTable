extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var game: Node3D = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new()
	game.settings.autosave = false
	game.scenario = ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json").data
	root.add_child(game)
	game.camera_rig.distance = 49
	game.camera_rig._update_camera(1)
	for i in 30: await process_frame
	game.selection.select_unit(game.battlefield.units.get_child(0))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/grimtable.png")
	game.selection.clear()
	game.hud.hide()
	game.camera_rig.distance = 43
	game.camera_rig.destination = Vector3(-5, 0, 1)
	game.camera_rig.heading = -.3
	game.camera_rig._update_camera(1)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets/grimtable/materials/menu_battlefield.png")
	print("GRIMTABLE visual capture PASS")
	quit()
