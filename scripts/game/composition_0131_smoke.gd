class_name Composition131Smoke
extends Node
var checks:=0
var failures: Array[String]=[]
var game: Node3D

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error("COMPOSITION PACKAGE "+label)
func capture(name: String) -> void:
	game.interaction.pointer=Vector2(-2000,-2000)
	for i in 8:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://"+name+"_0131.png")
func run(app: Node) -> void:
	get_window().size=Vector2i(1440,900)
	app.settings.autosave=false;app.settings.cinematic_dice="Off";app.settings.dice_volume=0
	app.settings.quality="Medium";app.settings.camera_assistance=false;app.settings.combat_camera=false
	app.settings.assistance="Tabletop";app.settings.auto_allocate_damage=true
	for id in ["hollow_basilica","ashfall_station"]:
		check(app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/"+id+".json")),"Packaged map opens "+id)
		game=app.game;game.hud.dice_panel.hide();game.guidance.hint_card.hide()
		await get_tree().physics_frame
		check(game.camera_rig.distance==53 and is_equal_approx(game.camera_rig.pitch,.92),"Default location framing")
		check(game.battlefield.visuals.has_node("EnvironmentComposition"),"Location surfaces load")
		await capture(id+"_gameplay")
		var unit: TableUnit=game.battlefield.units.get_child(0)
		game.selection.select_unit(unit);game.life.set_tactical(true)
		await capture(id+"_tactical");game.life.set_tactical(false)
		for objective: TableObjective in game.battlefield.objectives.get_children():
			check(game.interaction.pick(game.camera_rig.camera.unproject_position(objective.position+Vector3(0,.5,0)),8)==objective,"Objective remains clickable")
		var move:=SquadMoveSession.new(unit,game.battlefield,game.deployment)
		for model in unit.models:
			var start: Vector3=model.global_position;var end:=start+Vector3(0,0,-2)
			check(move.preview_error(model,start,end).is_empty(),"Legal squad approach")
			model.global_position=end;move.stage(model,start)
		check(move.validation_error().is_empty(),"Approach preserves coherency")
		game.history.perform(move.action());await get_tree().physics_frame
		var blocked: PhysicsRayQueryParameters3D
		var clear: PhysicsRayQueryParameters3D
		if id=="hollow_basilica":
			var nave: TerrainPiece=game.battlefield.terrain.get_node("nave")
			blocked=PhysicsRayQueryParameters3D.create(nave.to_global(Vector3(-7,1.3,-8)),nave.to_global(Vector3(-7,1.3,-4)),4)
			clear=PhysicsRayQueryParameters3D.create(Vector3(0,1.4,-12),Vector3(0,1.4,6),4)
		else:
			blocked=PhysicsRayQueryParameters3D.create(Vector3(2,1,2),Vector3(2,1,6),4)
			clear=PhysicsRayQueryParameters3D.create(Vector3(-10,1.4,-12),Vector3(-10,1.4,12),4)
		check(not game.get_world_3d().direct_space_state.intersect_ray(blocked).is_empty(),"Standing structure blocks LOS")
		check(game.get_world_3d().direct_space_state.intersect_ray(clear).is_empty(),"Open lane stays clear")
		var fired:=false
		for attacker: TableUnit in game.battlefield.units.get_children():
			if attacker.team!=0:continue
			for target: TableUnit in game.battlefield.units.get_children():
				if target.team==0:continue
				if AttackResolver.preview(attacker,target,game.get_world_3d(),attacker.weapon_profiles[0]).attacks>0:
					check(game.combat.resolve(attacker,target,game.get_world_3d()),"Attack resolves around architecture");fired=true;break
			if fired:break
		check(fired,"Legal ranged opportunity")
		var state:=WorldState.capture(game)
		check(SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://composition_battle.json").begins_with("Saved"),"Packaged battle saves")
		check(SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://composition_battle.json").begins_with("Loaded") and WorldState.capture(game)==state,"Packaged battle restores exactly")
		var replay:=ReplayController.new();replay.game=game;game.add_child(replay)
		var events: Array=game.battle_log.entries.duplicate(true)
		check(replay.open({"initial_scenario":game.initial_scenario,"events":events}).is_empty(),"Revised map replay opens")
		replay.seek(events.size())
		check(WorldState.capture(game)==state,"Revised map replay reproduces exact state")
	# Fresh editor instance avoids inheriting battle/replay modal state.
	check(app.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.FLAGSHIP),true),"Packaged scenario editor opens")
	game=app.game
	app.editor_panel.terrain_category.select(8);app.editor_panel.filter_terrain()
	check(app.editor_panel.terrain_choice.item_count==9,"Composed cluster palette available")
	app.editor.terrain_index=36;app.editor.set_tool(ScenarioEditor.Tool.TERRAIN)
	check(app.editor.place(Vector3(-20,0,15)),"Crater cluster places through editor")
	var piece: TerrainPiece=game.battlefield.terrain.get_children().back()
	app.editor.set_tool(ScenarioEditor.Tool.SELECT);app.editor.selected_kind="terrain";app.editor.selected_id=piece.object_id
	app.editor.rotate_selection(45);app.editor.duplicate_selected()
	check(game.battlefield.terrain.get_child_count()==13,"Cluster rotates and duplicates")
	var scenario:=ScenarioFactory.capture(game)
	check(ScenarioLibrary.save(scenario,"user://scenarios/composition_editor.json").begins_with("Saved"),"Editor scenario saves")
	var restored:=ScenarioLibrary.read("user://scenarios/composition_editor.json")
	check(restored.has("data") and JSON.stringify(restored.data)==JSON.stringify(JSON.parse_string(JSON.stringify(scenario,"",true,true))),"Editor scenario roundtrips")
	await capture("cluster_editor")
	var file:=FileAccess.open("user://composition_0131_smoke_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"maps":["hollow_basilica","ashfall_station"]},"\t"));file.close()
	print("GRIMTABLE COMPOSITION PACKAGED: ",checks," checks / ",failures.size()," failures")
	get_tree().quit(1 if not failures.is_empty() else 0)
