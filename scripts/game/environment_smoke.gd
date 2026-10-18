class_name EnvironmentSmoke
extends Node
var checks:=0
var failures: Array[String]=[]
var capture_game: Node3D

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error("ENVIRONMENT SMOKE "+label)

func capture(name: String) -> void:
	if is_instance_valid(capture_game):capture_game.interaction.pointer=Vector2(-2000,-2000)
	for i in 8:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://"+name+"_0130.png")

func run(app: Node) -> void:
	app.settings.autosave=false;app.settings.cinematic_dice="Off";app.settings.dice_volume=0
	app.settings.camera_assistance=false;app.settings.combat_camera=false
	app.settings.assistance="Tabletop";app.settings.auto_allocate_damage=true
	check(app.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.FLAGSHIP)),"Flagship opens")
	var game: Node3D=app.game
	capture_game=game
	game.hud.dice_panel.hide();game.guidance.hint_card.hide()
	await get_tree().create_timer(.4).timeout
	await capture("flagship_gameplay")
	game.hud.hide()
	game.camera_rig.distance=63;game.camera_rig.pitch=.82;game.camera_rig.destination=Vector3(0,0,-2);game.camera_rig._update_camera(1)
	await capture("flagship_wide")
	game.camera_rig.distance=24;game.camera_rig.pitch=.60;game.camera_rig.heading=.16;game.camera_rig.destination=Vector3(-9,2,-4);game.camera_rig._update_camera(1)
	await capture("environment_detail")
	game.camera_rig.distance=63;game.camera_rig.pitch=.82;game.camera_rig.heading=0;game.camera_rig.destination=Vector3(0,0,-2);game.camera_rig._update_camera(1)
	game.life.set_tactical(true);await capture("flagship_tactical");game.life.set_tactical(false)
	for id in ["ashen_basilica","ashfall_manufactorum","toxic_forge"]:
		game.apply_scenario(ScenarioLibrary.read("res://resources/scenarios/"+id+".json").data)
		check(game.battlefield.visuals.has_node("EnvironmentComposition"),"Packaged theme "+id)
		await capture(id)
	game.apply_scenario(ScenarioLibrary.read(ScenarioLibrary.FLAGSHIP).data)
	if "--environment-capture-only" in OS.get_cmdline_user_args():
		finish(true);return
	game.hud.show()
	var unit: TableUnit=game.battlefield.units.get_child(0)
	var session:=SquadMoveSession.new(unit,game.battlefield,game.deployment)
	for model in unit.models:
		var start: Vector3=model.global_position
		var end:=start+Vector3(0,0,-3)
		check(session.preview_error(model,start,end).is_empty(),"Legal open-lane move")
		model.global_position=end;session.stage(model,start)
	check(session.validation_error().is_empty(),"Formation remains legal")
	game.history.perform(session.action());await get_tree().physics_frame
	var model: Miniature=unit.models[0]
	var cover_route: Array=[[ -13,0,10.2],[-13,0,7.3]]
	check(is_equal_approx(MovementService.path_penalty(game.battlefield,model,cover_route),2),"Trench difficult-ground cost retained")
	check(MovementService.move_error(game.battlefield,model,Vector3(-13,0,10.2),Vector3(-13,0,7.3),model.movement,unit).is_empty(),"Legal passage through low trench cover")
	var bunker: TerrainPiece=game.battlefield.terrain.get_node("bunker")
	var blocked:=PhysicsRayQueryParameters3D.create(bunker.to_global(Vector3(0,1,-4)),bunker.to_global(Vector3(0,1,4)),4)
	check(not game.get_world_3d().direct_space_state.intersect_ray(blocked).is_empty(),"Major blocker stops fire")
	var clear:=PhysicsRayQueryParameters3D.create(Vector3(0,1.4,-12),Vector3(0,1.4,12),4)
	check(game.get_world_3d().direct_space_state.intersect_ray(clear).is_empty(),"Crossing has a clear firing lane")
	var fired:=false
	for attacker: TableUnit in game.battlefield.units.get_children():
		if attacker.team!=0:continue
		for enemy: TableUnit in game.battlefield.units.get_children():
			if enemy.team==0:continue
			if AttackResolver.preview(attacker,enemy,game.get_world_3d(),attacker.weapon_profiles[0]).attacks>0:
				check(game.combat.resolve(attacker,enemy,game.get_world_3d()),"Attack resolves around landmarks")
				fired=true;break
		if fired:break
	check(fired,"A legal ranged attack exists")
	game.ai.configure({"teams":{"0":"Easy","1":"Easy"},"human_team":0,"seed":77,"round_limit":1,"speed":"Fast"});game.ai.set_process(false)
	var ticks:=0
	while not game.ai.finished and ticks<200:
		await game.ai.runtime_step();ticks+=1;await get_tree().physics_frame
	check(game.ai.finished and game.ai.invalid_actions==0,"One legal AI round on composed map")
	game.dice_tray.cancel()
	var before:=WorldState.capture(game)
	check(SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://environment_0130_save.json").begins_with("Saved"),"Packaged game save")
	check(SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://environment_0130_save.json").begins_with("Loaded") and WorldState.capture(game)==before,"Exact packaged game load")
	# Compose a fresh scenario through the actual editor, after battle smoke checks.
	game.apply_scenario(ScenarioLibrary.read(ScenarioLibrary.FLAGSHIP).data)
	var editor:=ScenarioEditor.new();editor.game=game;game.add_child(editor)
	var panel:=EditorPanel.new();panel.editor=editor;game.add_child(panel)
	panel.terrain_category.select(5);panel.filter_terrain()
	check(panel.terrain_choice.item_count==2,"Editor centerpiece browsing")
	editor.terrain_index=26;editor.set_tool(ScenarioEditor.Tool.TERRAIN)
	check(editor.place(Vector3(-26,0,16)),"Packaged authored landmark placement")
	editor.set_tool(ScenarioEditor.Tool.SELECT)
	await capture("editor_palette")
	var scenario:=ScenarioFactory.capture(game)
	check(ScenarioLibrary.save(scenario,"user://scenarios/environment_0130.json").begins_with("Saved"),"Packaged scenario save")
	var restored:=ScenarioLibrary.read("user://scenarios/environment_0130.json")
	check(restored.has("data") and JSON.stringify(restored.data)==JSON.stringify(JSON.parse_string(JSON.stringify(scenario,"",true,true))),"Exact packaged scenario load")
	finish(false)

func finish(capture_only: bool) -> void:
	var file:=FileAccess.open("user://environment_0130_"+("capture" if capture_only else "smoke")+"_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"capture_only":capture_only},"\t"));file.close()
	print("GRIMTABLE ENVIRONMENT PACKAGED: ",checks," checks / ",failures.size()," failures")
	get_tree().quit(1 if not failures.is_empty() else 0)
