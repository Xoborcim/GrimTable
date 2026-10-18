extends SceneTree
var checks:=0
var failures:=0
var diagnostics: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL COMPOSITION "+label)

func open_game(id: String) -> Node3D:
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
	game.settings=AppSettings.new();game.settings.autosave=false;game.settings.cinematic_dice="Off"
	game.settings.camera_assistance=false;game.scenario=ScenarioLibrary.read("res://resources/scenarios/"+id+".json").data
	root.add_child(game);return game

func reachable(board: Battlefield,start: Vector3,goal: Vector3,radius: float) -> bool:
	# Test-only coarse search. Existing swept footprint queries validate each edge.
	var step:=1.6
	var begin:=Vector2i(roundi(start.x/step),roundi(start.z/step))
	var queue: Array[Vector2i]=[begin];var seen: Dictionary={begin:true};var index:=0
	var blocked:=board.terrain.get_children().filter(func(p: TerrainPiece):return p.blocks_movement)
	while index<queue.size():
		var cell: Vector2i=queue[index];index+=1
		var at:=Vector3(cell.x*step,0,cell.y*step)
		if Vector2(at.x-goal.x,at.z-goal.z).length()<=2.4:return true
		for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i=cell+direction
			if seen.has(next):continue
			var end:=Vector3(next.x*step,0,next.y*step)
			if not board.contains_base(end,radius):continue
			if blocked.any(func(p: TerrainPiece):return p.path_touches(at,end,radius)):continue
			seen[next]=true
			queue.append(next)
	return false

func run() -> void:
	var maps: Array=["hollow_basilica","ashfall_station"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):maps=[arg.trim_prefix("--map=")]
	for id: String in maps:
		var loaded:=ScenarioLibrary.read("res://resources/scenarios/"+id+".json")
		check(loaded.has("data"),"Scenario validates "+id)
		if not loaded.has("data"):continue
		var game:=open_game(id);await physics_frame;await process_frame
		check(game.battlefield.visuals.has_node("EnvironmentComposition"),"Location dressing loads")
		check(game.battlefield.visuals.find_children("*","CollisionObject3D",true,false).is_empty(),"Cosmetic ground has no collision bodies")
		var material: ShaderMaterial=game.battlefield.visuals.get_node("GroundSurface").material_override
		check(material.get_shader_parameter("location_ground"),"Authored surface layout used")
		check(material.get_shader_parameter("layout_mask") is Texture2D,"Authored map mask loads")
		check(material.get_shader_parameter("relief_normal") is Texture2D and material.get_shader_parameter("relief_ao") is Texture2D,"Runtime uses actual baked maps")
		for piece: TerrainPiece in game.battlefield.terrain.get_children():
			if piece.footprint_parts.is_empty():continue
			check(piece.footprint().size()==piece.footprint_parts.size(),"All authored footprint parts load")
			var collisions:=piece.get_children().filter(func(n: Node):return n is CollisionShape3D)
			check(collisions.size()==piece.footprint_parts.size(),"One simple collider per declared part")
			for mesh: MeshInstance3D in piece.find_children("*","MeshInstance3D",true,false):
				if str(mesh.name).ends_with("_GroundContact"):check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Thin ground avoids shadow acne")
		for unit: TableUnit in game.battlefield.units.get_children():
			for model in unit.models:check(MovementService.placement_error(game.battlefield,model,model.global_position,unit).is_empty(),"Legal spawn "+model.model_id)
		for objective: TableObjective in game.battlefield.objectives.get_children():
			check(game.battlefield.terrain.get_children().all(func(p: TerrainPiece):return not p.blocks_movement or not p.overlaps_base(objective.position,.65)),"Objective center accessible")
			for index in [0,2,3]:
				var model: Miniature=game.battlefield.units.get_child(index).models[0]
				check(reachable(game.battlefield,model.position,objective.position,model.base_radius),"Terrain route to objective / "+str(index))
		if id=="hollow_basilica":
			var nave: TerrainPiece=game.battlefield.terrain.get_node("nave")
			check(not nave.overlaps_base(nave.to_global(Vector3(-8.4,0,0)),.55),"West breach is genuinely open")
			check(not nave.path_touches(nave.to_global(Vector3(-10,0,0)),nave.to_global(Vector3(-6.7,0,0)),.55),"Infantry can cross the west breach")
			check(nave.path_touches(nave.to_global(Vector3(-7,0,-8)),nave.to_global(Vector3(-7,0,-4)),.55),"Standing rear wall blocks movement")
			var ray:=PhysicsRayQueryParameters3D.create(nave.to_global(Vector3(-7,1.3,-8)),nave.to_global(Vector3(-7,1.3,-4)),4)
			check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Rear wall blocks canonical eye-height LOS")
			var gate: TerrainPiece=game.battlefield.terrain.get_node("gate")
			check(not gate.path_touches(gate.to_global(Vector3(0,0,-4)),gate.to_global(Vector3(0,0,4)),1.18),"Walker fits the gate breach")
		game.life.set_tactical(true)
		check(game.battlefield.terrain.get_children().all(func(p: TerrainPiece):return p.footprint_overlay.visible),"Tactical footprints show compound geometry")
		game.life.set_tactical(false)
		var snapshot:=ScenarioFactory.capture(game)
		check(ScenarioLibrary.save(snapshot,"user://scenarios/composition_0131.json").begins_with("Saved"),"Map saves")
		var restored:=ScenarioLibrary.read("user://scenarios/composition_0131.json")
		check(restored.has("data") and JSON.stringify(restored.data)==JSON.stringify(JSON.parse_string(JSON.stringify(snapshot,"",true,true))),"Compound footprint and appearance roundtrip")
		var bad:=snapshot.duplicate(true)
		bad.terrain[0].footprint_parts=[{"center":[500,1,0],"size":[1,2,1]}]
		check(not ScenarioDefinition.validate(bad).is_empty(),"Out-of-bounds compound parts rejected")
		var state:=WorldState.capture(game)
		check(SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://composition_save.json").begins_with("Saved"),"New map game saves")
		check(SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://composition_save.json").begins_with("Loaded") and WorldState.capture(game)==state,"New map game restores exactly")
		var guest:=open_game("demo");await physics_frame
		var network:=NetworkSession.new();network.game=guest;guest.add_child(network)
		network._apply_canonical({"type":"snapshot","compatibility":NetworkCompatibility.manifest(),"scenario":game.initial_scenario,"state":state,"events":[],"sequence":0,"hash":NetworkSession.state_hash(state),"dice":[]})
		check(network.hash_status=="matched","Second client accepts canonical map snapshot")
		check(ScenarioFactory.capture(guest).terrain==snapshot.terrain,"Second client retains compound collision metadata")
		guest.queue_free();await process_frame;await physics_frame
		if "--ai" in OS.get_cmdline_user_args():
			game.ai.configure({"teams":{"0":"Easy","1":"Easy"},"human_team":0,"seed":131,"round_limit":1,"speed":"Fast"});game.ai.set_process(false)
			var ticks:=0
			while not game.ai.finished and ticks<200:
				await game.ai.runtime_step();ticks+=1;await physics_frame
			var moves: int=game.battle_log.entries.filter(func(entry):return entry.kind=="execute" and entry.payload.get("kind")=="unit_move").size()
			check(game.ai.finished and game.ai.invalid_actions==0,"One legal AI round on "+id)
			diagnostics.append({"map":id,"ticks":ticks,"invalid_actions":game.ai.invalid_actions,"finished":game.ai.finished,"movement_actions":moves})
		game.queue_free();await process_frame
	# Exercise palette placement, rotation, duplication and appearance persistence.
	var game:=open_game("empty")
	var editor:=ScenarioEditor.new();editor.game=game;game.add_child(editor)
	var panel:=EditorPanel.new();panel.editor=editor;game.add_child(panel)
	panel.terrain_category.select(8);panel.filter_terrain()
	check(panel.terrain_choice.item_count==9,"All nine composed clusters exposed")
	for index in range(29,38):
		editor.terrain_index=index;editor.set_tool(ScenarioEditor.Tool.TERRAIN)
		check(editor.place(Vector3.ZERO),"Cluster placement "+str(index))
		var piece: TerrainPiece=game.battlefield.terrain.get_child(0)
		var parts:=piece.footprint_parts.duplicate(true)
		editor.set_tool(ScenarioEditor.Tool.SELECT);editor.selected_kind="terrain";editor.selected_id=piece.object_id
		editor.rotate_selection(90)
		check(game.battlefield.terrain.get_child(0).footprint_parts==parts,"Rotation keeps local footprint")
		editor.duplicate_selected()
		check(game.battlefield.terrain.get_child_count()==2 and game.battlefield.terrain.get_child(1).footprint_parts==parts,"Duplicate retains compound footprint")
		while game.battlefield.terrain.get_child_count()>0:
			editor.selected_kind="terrain";editor.selected_id=game.battlefield.terrain.get_child(0).object_id;editor.delete_selected()
	panel.surface_choice.select(2)
	check(panel.apply_metadata() and game.scenario.board.surface_layout=="Transport","Editor surface layout persists")
	game.queue_free();await process_frame
	print("GRIMTABLE COMPOSITION 0131: ",checks," checks / ",failures," failures")
	var file:=FileAccess.open("user://composition_0131_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"ai":diagnostics},"\t"));file.close()
	quit(1 if failures else 0)
