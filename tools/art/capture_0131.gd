extends SceneTree

func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,900)
	var args:=OS.get_cmdline_user_args()
	var phase: String=args[0] if not args.is_empty() else "before"
	DirAccess.make_dir_recursive_absolute("res://docs/environment/0131")
	for id in ([args[1]] if args.size()>1 else ["hollow_basilica","ashfall_station"]):
		var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
		game.settings=AppSettings.new();game.settings.autosave=false;game.settings.camera_assistance=false
		game.settings.quality="Medium";game.settings.assistance="Tabletop"
		game.scenario=ScenarioLibrary.read("res://resources/scenarios/"+id+".json").data
		root.add_child(game)
		game.camera_rig.distance=58;game.camera_rig.pitch=.82;game.camera_rig.heading=.08
		game.camera_rig.destination=Vector3(0,.5,-2);game.camera_rig._update_camera(1)
		game.interaction.pointer=Vector2(-2000,-2000);game.hud.hide()
		for i in 16:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/environment/0131/"+id+"_"+phase+".png")
		if phase!="before":
			game.battlefield.units.hide()
			for i in 4:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/environment/0131/"+id+"_location.png")
			game.battlefield.units.show()
			game.camera_rig.distance=28;game.camera_rig.pitch=.64
			game.camera_rig.destination=Vector3(-9,1,-5) if id=="hollow_basilica" else Vector3(13,1,-6)
			game.camera_rig._update_camera(1)
			for i in 8:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/environment/0131/"+id+"_detail.png")
			game.camera_rig.distance=15;game.camera_rig.pitch=.78
			game.camera_rig.destination=Vector3(-17,.4,1) if id=="hollow_basilica" else Vector3(15,.4,-3)
			game.camera_rig._update_camera(1)
			for i in 8:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/environment/0131/"+id+"_integration.png")
		game.queue_free();await process_frame
	print("GRIMTABLE 0131 NATIVE CAPTURE ",phase)
	quit()
