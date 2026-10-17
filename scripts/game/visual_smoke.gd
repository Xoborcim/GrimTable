class_name VisualSmoke
extends GuidedSmoke

var application: Node
var extra_checked := false

func run(app: Node) -> void:
	application = app
	await settle()
	check(app.menu_diorama != null and app.menu_diorama.camera != null,"Live in-engine menu diorama")
	await capture("user://visual_menu.png")
	await app.launch_with_transition(ScenarioLibrary.read(ScenarioLibrary.BUILTINS[4]))
	game = app.game
	await settle()
	await capture("user://visual_intro.png")
	await get_tree().create_timer(1.8).timeout
	for unit: TableUnit in game.battlefield.units.get_children():
		for model in unit.models:
			var art: Node3D = model.visual_root.get_child(0)
			check(art.get_child_count() > 0,"Authored sculpt has visible geometry: " + model.model_id)
	await capture("user://visual_after_090.png")
	var before := WorldState.capture(game)
	await game.guidance.capture_clean()
	check(WorldState.capture(game)==before and game.hud.visible,"Screenshot mode restores rendering and changes no gameplay")
	if "--capture-only" in OS.get_cmdline_user_args(): finish(); return
	for size in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1920,1080),Vector2i(2560,1440)]:
		get_window().size = size
		await settle()
		game.guidance.label_layout.layout_labels()
		var rectangles: Array = game.guidance.label_layout.last_rects
		var separated := true
		for i in rectangles.size():
			for j in range(i+1,rectangles.size()):
				if rectangles[i].intersects(rectangles[j]): separated = false
		check(separated,"World plates never overlap at " + str(size))
		check(game.get_viewport().get_visible_rect().encloses(game.hud.dock.get_global_rect()),"Dock fits " + str(size))
		await capture("user://visual_"+str(size.x)+"x"+str(size.y)+".png")
	get_window().size = Vector2i(1440,900)
	await settle()
	# Reuse the established short move/attack/scoring walkthrough in this battle.
	await super.run(app)

func finish() -> void:
	if not extra_checked and "--capture-only" not in OS.get_cmdline_user_args():
		extra_checked = true
		call_deferred("faction_view")
		return
	super.finish()

func faction_view() -> void:
	check(application.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.BUILTINS[3])),"Horde/Synthetics presentation opens")
	game = application.game
	await settle()
	game.camera_rig.distance = 46
	game.camera_rig.destination = Vector3.ZERO
	game.camera_rig._update_camera(1)
	await capture("user://visual_horde_synthetics.png")
	check(game.battlefield.units.get_child_count()>2,"Other faction sculpts render")
	super.finish()
