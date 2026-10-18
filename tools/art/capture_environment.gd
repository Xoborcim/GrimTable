extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1440,900)
	var args:=OS.get_cmdline_user_args()
	var phase: String=args[0] if not args.is_empty() else "before"
	var board_path: String=args[1] if args.size()>1 else "ashen_basilica"
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
	game.settings=AppSettings.new(); game.settings.autosave=false
	game.settings.camera_assistance=false; game.settings.quality="High"
	game.scenario=ScenarioLibrary.read("res://resources/scenarios/"+board_path+".json").data
	root.add_child(game)
	game.camera_rig.distance=63; game.camera_rig.pitch=.82
	game.camera_rig.destination=Vector3(0,0,-2); game.camera_rig._update_camera(1)
	for i in 20: await process_frame
	game.hud.hide()
	if game.guidance!=null: game.guidance.hint_card.hide()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/environment")
	root.get_texture().get_image().save_png("res://docs/environment/"+board_path+"_"+phase+".png")
	game.queue_free(); await process_frame
	quit()
