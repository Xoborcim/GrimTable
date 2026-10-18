extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL ENVIRONMENT "+label)

func run() -> void:
	for id in ["hollow_basilica","ashen_basilica","ashfall_manufactorum","toxic_forge"]:
		var loaded:=ScenarioLibrary.read("res://resources/scenarios/"+id+".json")
		check(loaded.has("data"),"Scenario validates "+id+str(loaded.get("error","")))
		if not loaded.has("data"):continue
		var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
		game.settings=AppSettings.new();game.settings.autosave=false;game.scenario=loaded.data
		root.add_child(game);await physics_frame;await process_frame
		check(game.battlefield.visuals.has_node("EnvironmentComposition"),"Composed environment loads")
		var decoration: Node3D=game.battlefield.visuals.get_node("EnvironmentComposition")
		check(decoration.find_children("*","CollisionObject3D",true,false).is_empty(),"Ground dressing adds no colliders")
		check(decoration.get_child_count()<=12,"Ground meshes batched by shared material")
		check(game.camera_rig.distance==(53 if loaded.data.board.get("surface_layout","Legacy")!="Legacy" else 60),"Default framing applied")
		for piece: TerrainPiece in game.battlefield.terrain.get_children():
			if not piece.visual_scene.is_empty():check(piece.get_children().any(func(child: Node):return child.scene_file_path==piece.visual_scene),"Authored landmark loads "+piece.object_id)
			if piece.visual_scene.begins_with(EnvironmentArt.ROOT):
				var meshes:=piece.find_children("*","MeshInstance3D",true,false)
				var atlas:=meshes[0].get_active_material(0) as ShaderMaterial
				check(atlas!=null and atlas.get_shader_parameter("pigment") is Texture2D and atlas.get_shader_parameter("orm") is Texture2D,"Shared pigment and PBR atlases retained")
		for unit: TableUnit in game.battlefield.units.get_children():
			for model in unit.models:check(MovementService.placement_error(game.battlefield,model,model.global_position,unit).is_empty(),"Spawn legal "+model.model_id)
		for objective: TableObjective in game.battlefield.objectives.get_children():
			check(game.battlefield.contains_base(objective.position,.65),"Objective on board")
			check(game.battlefield.terrain.get_children().all(func(piece: TerrainPiece):return not piece.blocks_movement or not piece.overlaps_base(objective.position,.65)),"Objective center reachable")
		var clear_lanes:=0
		for x in [-26.0,-.0,26.0]:
			if game.battlefield.terrain.get_children().all(func(piece: TerrainPiece):return not piece.blocks_movement or not piece.path_touches(Vector3(x,0,-18),Vector3(x,0,18),.65)):clear_lanes+=1
		check(clear_lanes>=2,"Two continuous infantry flank lanes")
		var firing_lane:=false
		for attacker: TableUnit in game.battlefield.units.get_children():
			if attacker.team!=0:continue
			for enemy: TableUnit in game.battlefield.units.get_children():
				if enemy.team!=0 and AttackResolver.preview(attacker,enemy,game.get_world_3d(),attacker.weapon_profiles[0]).attacks>0:firing_lane=true
		check(firing_lane,"Ranged firing opportunity around major landmarks")
		var terrain: TerrainPiece=game.battlefield.terrain.get_node("bunker")
		var ray:=PhysicsRayQueryParameters3D.create(terrain.to_global(Vector3(0,1,-4)),terrain.to_global(Vector3(0,1,4)),4)
		check(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Bunker LOS body blocks")
		check(terrain.path_touches(terrain.to_global(Vector3(0,0,-4)),terrain.to_global(Vector3(0,0,4)),.6),"Bunker movement body blocks")
		game.life.set_tactical(true)
		check(game.life.overlay.visible and game.battlefield.terrain.get_children().all(func(p: TerrainPiece):return p.footprint_overlay.visible),"Tactical footprints cover new landmarks")
		game.life.set_tactical(false)
		var snapshot:=ScenarioFactory.capture(game)
		check(snapshot.board==loaded.data.board,"Appearance settings persist in capture")
		check(ScenarioLibrary.save(snapshot,"user://scenarios/environment_test.json").begins_with("Saved"),"Map saves")
		var restored: Dictionary=ScenarioLibrary.read("user://scenarios/environment_test.json").data
		check(JSON.stringify(restored)==JSON.stringify(JSON.parse_string(JSON.stringify(snapshot,"",true,true))),"Exact map roundtrip")
		game.queue_free();await process_frame
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
	game.settings=AppSettings.new();game.settings.autosave=false;game.scenario=ScenarioLibrary.read("res://resources/scenarios/empty.json").data
	root.add_child(game)
	var editor:=ScenarioEditor.new();editor.game=game;game.add_child(editor)
	for index in range(21,ScenarioEditor.TERRAIN.size()):
		editor.terrain_index=index;editor.set_tool(ScenarioEditor.Tool.TERRAIN)
		check(editor.place(Vector3.ZERO),"Place authored terrain")
		var piece: TerrainPiece=game.battlefield.terrain.get_child(0)
		check(not piece.visual_scene.is_empty(),"Editor persists explicit scene")
		editor.selected_kind="terrain";editor.selected_id=piece.object_id
		editor.duplicate_selected();check(game.battlefield.terrain.get_child_count()==2,"Duplicate preserves authored scene")
		# Remove both pieces through normal editor deletion.
		while game.battlefield.terrain.get_child_count()>0:
			editor.selected_kind="terrain";editor.selected_id=game.battlefield.terrain.get_child(0).object_id;editor.delete_selected()
	var panel:=EditorPanel.new();panel.editor=editor;game.add_child(panel)
	panel.terrain_category.select(5);panel.filter_terrain()
	check(panel.terrain_choice.item_count==2,"Centerpiece filter")
	check(panel.terrain_preview.art.get_child_count()>0,"Actual terrain preview")
	panel.theme_choice.select(4);panel.environment_enabled.button_pressed=true;panel.clutter_choice.select(1);panel.weather_choice.select(1);panel.surround_choice.select(1)
	check(panel.apply_metadata(),"Appearance controls apply")
	check(game.scenario.board.clutter=="Sparse" and game.scenario.board.surround=="Brass" and game.scenario.board.weather=="Clear","Appearance controls retained")
	check(not game.battlefield.visuals.has_node("EnvironmentalVapor"),"Clear atmosphere disables emitters")
	game.queue_free();await process_frame
	print("GRIMTABLE ENVIRONMENT: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
