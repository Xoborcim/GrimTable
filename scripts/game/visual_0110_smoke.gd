class_name Visual0110Smoke
extends Node
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("FAIL "+label)
func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
func run(app: Node) -> void:
	app.settings.autosave=false
	app.settings.reduce_motion=false
	app.settings.cinematic_dice="Full"
	app.settings.dice_volume=0
	await get_tree().create_timer(.5).timeout
	check(app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/ashen_basilica.json")),"Packaged showcase opens")
	var game: Node3D=app.game
	game.camera_rig.distance=46
	game.camera_rig.destination=Vector3(0,0,0)
	game.camera_rig._update_camera(1)
	await get_tree().create_timer(2).timeout
	game.guidance.hint_card.hide()
	await capture("user://basilica_0110.png")
	for id in ["ashfall_manufactorum","toxic_forge"]:
		game.apply_scenario(ScenarioLibrary.read("res://resources/scenarios/"+id+".json").data)
		await get_tree().create_timer(.25).timeout
		await capture("user://"+id+"_0110.png")
	game.apply_scenario(ScenarioLibrary.read("res://resources/scenarios/ashen_basilica.json").data)
	var before:=WorldState.capture(game)
	game.dice_tray.enqueue("CANONICAL HIT ROLL",[6,6,6,1,1,2,3,4,5,6],4)
	await get_tree().create_timer(.3).timeout
	check(game.dice_tray.dice.size()==10 and game.dice_tray.dice[0].angular_velocity.length()>0,"Physics dice active")
	await capture("user://dice_tumble_0110.png")
	await get_tree().create_timer(1.85).timeout
	game.dice_tray.skip()
	await capture("user://dice_result_0110.png")
	for die in game.dice_tray.dice: check(CinematicDie.top_face(die.basis)==die.result,"Canonical packaged face")
	check(before==WorldState.capture(game),"Dice preserves gameplay snapshot")
	game.dice_tray.cancel()
	# Build an original local GLB at runtime, import through the same library API.
	var source:=Node3D.new()
	TableVisuals.box(source,Vector3(.6,1.4,.5),Vector3(0,.7,0),Color("a4b8ba"))
	TableVisuals.cylinder(source,.3,.35,Vector3(0,1.5,0),Color("b9ad86"))
	var document:=GLTFDocument.new()
	document.root_node_mode=GLTFDocument.ROOT_NODE_MODE_MULTI_ROOT
	var state:=GLTFState.new()
	document.append_from_scene(source,state)
	document.write_to_filesystem(state,"user://runtime_original.glb"); source.free()
	var imported:=MiniatureLibrary.import_model("user://runtime_original.glb")
	check(imported.has("record"),"Packaged native GLB import")
	if imported.has("record"):
		var record: Dictionary=imported.record
		record.scale=.8; record.rotation=[0,45,0]; record.base_mm=40; record.profile="legion_trooper"
		check(MiniatureLibrary.save_record(record),"Packaged adjustments saved")
		var model:=MiniatureLibrary.assigned("legion_trooper","fixture")
		check(model!=null,"Packaged profile assignment")
		if model!=null: model.free()
		var original: Miniature=game.battlefield.units.get_child(0).models[0]
		var radius:=original.base_radius
		var los_height:=original.los_origin.position.y
		game.apply_scenario(game.scenario)
		var replacement: Miniature=game.battlefield.units.get_child(0).models[0]
		check(replacement.visual_root.get_child(0).has_meta("animation_map"),"Imported model appears on canonical unit")
		check(replacement.base_radius==radius and replacement.los_origin.position.y==los_height,"Cosmetic base and LOS preserve gameplay")
		app.show_miniature_library()
		await get_tree().create_timer(.7).timeout
		await capture("user://miniature_library_0110.png")
		for child in app.root.get_children():
			if child is MiniatureLibraryPanel: child.queue_free()
	game.ai.configure({"teams":{"0":"Easy","1":"Easy"},"human_team":0,"seed":77,"round_limit":1,"speed":"Fast"})
	game.ai.set_process(false)
	var ticks:=0
	while not game.ai.finished and ticks<200:
		await game.ai.runtime_step()
		ticks+=1
		await get_tree().physics_frame
	check(game.ai.finished and game.ai.invalid_actions==0,"Showcase AI completes one round legally")
	var before_save:=WorldState.capture(game)
	check(SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://visual_0110_save.json").begins_with("Saved"),"Packaged save")
	check(SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://visual_0110_save.json").begins_with("Loaded") and WorldState.capture(game)==before_save,"Packaged exact load")
	var replay:=ReplayController.new()
	replay.game=game; game.add_child(replay)
	check(replay.open({"initial_scenario":game.initial_scenario,"events":game.battle_log.entries.duplicate(true)}).is_empty(),"Packaged replay opens")
	replay.seek(replay.events.size())
	check(before_save==WorldState.capture(game),"Packaged replay preserves final world")
	print("GRIMTABLE VISUAL 0110 SMOKE: ",checks," checks / ",failures," failures")
	get_tree().quit(1 if failures else 0)
