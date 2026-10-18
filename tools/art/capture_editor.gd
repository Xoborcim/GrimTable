extends SceneTree

func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var app: Node=load("res://scripts/game/app.gd").new()
	root.add_child(app)
	app.settings.autosave=false;app.settings.camera_assistance=false
	assert(app.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.FLAGSHIP),true))
	app.editor_panel.terrain_category.select(5);app.editor_panel.filter_terrain()
	assert(app.editor_panel.terrain_choice.item_count==2)
	app.game.interaction.pointer=Vector2(-2000,-2000)
	for i in 16:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/environment/editor_palette_0130.png")
	print("GRIMTABLE ENVIRONMENT FRESH EDITOR CAPTURE PASS")
	app.queue_free();await process_frame
	quit()
