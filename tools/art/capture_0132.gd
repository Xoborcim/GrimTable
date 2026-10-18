extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size=Vector2i(1440,900)
	var args:=OS.get_cmdline_user_args()
	var phase: String=args[0] if not args.is_empty() else "after"
	var folder:="res://docs/environment/0132/"
	DirAccess.make_dir_recursive_absolute(folder)
	for id in ["hollow_basilica","ashfall_station"]:
		var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
		game.settings=AppSettings.new();game.settings.autosave=false;game.settings.camera_assistance=false
		game.settings.quality="Medium";game.settings.assistance="Tabletop"
		game.scenario=ScenarioLibrary.read("res://resources/scenarios/"+id+".json").data
		root.add_child(game)
		game.interaction.pointer=Vector2(-2000,-2000);game.hud.hide()
		game.camera_rig.heading=.08
		for view in ["wide","approach"]:
			game.camera_rig.distance=58 if view=="wide" else 24
			game.camera_rig.pitch=.82 if view=="wide" else .88
			game.camera_rig.destination=Vector3(0,.5,-2) if view=="wide" else (Vector3(-9,.4,8) if id=="hollow_basilica" else Vector3(-10,.4,8))
			game.camera_rig._update_camera(1)
			for i in 16:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder+id+"_"+view+"_"+phase+".png")
		game.queue_free();await process_frame
	print("GRIMTABLE 0132 NATIVE CAPTURE ",phase)
	quit()
