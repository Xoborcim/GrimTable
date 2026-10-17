extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 900)
	var game: Node3D = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new()
	game.settings.autosave = false
	root.add_child(game)
	for id in ["legion_vs_swarm", "horde_vs_synthetics"]:
		game.apply_scenario(ScenarioLibrary.read("res://resources/scenarios/" + id + ".json").data)
		game.hud.dice_panel.hide()
		game.hud.combat_panel.hide()
		game.selection.select_unit(game.battlefield.units.get_child(0))
		game.camera_rig.distance = 47
		game.camera_rig._update_camera(1)
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/" + id + ".png")
	game.queue_free()
	await process_frame
	quit()
