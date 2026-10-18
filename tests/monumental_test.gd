extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("FAIL "+label)
func run() -> void:
	for id in ["ashen_basilica","ashfall_manufactorum","toxic_forge"]:
		var data:=ScenarioLibrary.read("res://resources/scenarios/"+id+".json")
		check(data.has("data"),"Scenario validates "+id+str(data.get("error","")))
		if not data.has("data"): continue
		var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
		game.settings=AppSettings.new(); game.settings.autosave=false
		game.scenario=data.data
		root.add_child(game)
		await physics_frame
		await process_frame
		for piece: TerrainPiece in game.battlefield.terrain.get_children():
			check(not piece.footprint().is_empty(),"Retained gameplay footprint")
			if not piece.visual_scene.is_empty():
				check(piece.get_children().any(func(child: Node): return child.scene_file_path==piece.visual_scene),"Explicit terrain scene loads and takes priority")
			elif not piece.art_style.is_empty(): check(piece.has_node("MonumentalArchitecture"),"Architecture scene loads")
		var roundtrip:=ScenarioFactory.capture(game)
		check(ScenarioDefinition.validate(roundtrip).is_empty(),"Scenario capture validates")
		check(roundtrip.terrain[5].art_style==data.data.terrain[5].art_style,"Art style persists")
		check(roundtrip.board==data.data.board,"Theme controls persist")
		for unit: TableUnit in game.battlefield.units.get_children():
			for model in unit.models:
				var clear:=true
				for piece: TerrainPiece in game.battlefield.terrain.get_children():
					if piece.blocks_movement and piece.overlaps_base(model.position,model.base_radius): clear=false
				check(clear,"Spawn clear "+model.model_id)
		game.queue_free(); await process_frame
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
	game.scenario=ScenarioLibrary.read("res://resources/scenarios/empty.json").data
	game.settings=AppSettings.new(); game.settings.autosave=false
	root.add_child(game)
	var editor:=ScenarioEditor.new()
	editor.game=game; game.add_child(editor)
	for i in range(5,ScenarioEditor.TERRAIN.size()):
		editor.terrain_index=i; editor.set_tool(ScenarioEditor.Tool.TERRAIN)
		check(editor.place(Vector3.ZERO),"Editor places "+str(ScenarioEditor.TERRAIN[i].name))
		var piece: TerrainPiece=game.battlefield.terrain.get_child(0)
		check(piece.get_children().any(func(child: Node):return child.scene_file_path==piece.visual_scene) if not piece.visual_scene.is_empty() else not piece.art_style.is_empty() and piece.has_node("MonumentalArchitecture"),"Editor builds selected architecture")
		editor.selected_kind="terrain"; editor.selected_id=piece.object_id
		editor.delete_selected()
	editor.terrain_index=5; editor.set_tool(ScenarioEditor.Tool.TERRAIN); editor.place(Vector3(-12,0,0))
	editor.selected_kind="terrain"; editor.selected_id=game.battlefield.terrain.get_child(0).object_id
	editor.duplicate_selected()
	check(game.battlefield.terrain.get_child_count()==2,"Terrain duplication preserves style")
	var captured:=ScenarioFactory.capture(game)
	check(ScenarioLibrary.save(captured,"user://scenarios/monumental_test.json").begins_with("Saved"),"New editor scenario saves")
	check(ScenarioLibrary.read("user://scenarios/monumental_test.json").has("data"),"New editor scenario loads")
	game.queue_free(); await process_frame
	print("GRIMTABLE MONUMENTAL: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
