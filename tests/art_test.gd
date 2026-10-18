extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("FAIL "+label)
func run() -> void:
	for id in AuthoredArt.MODELS:
		var profile:=ContentRegistry.unit({"unit_id":id})
		var visual:=AuthoredArt.miniature(profile)
		check(visual!=null,"Authored mesh loads "+id)
		if visual!=null:
			check(visual.has_meta("authored_art"),"Cosmetic provenance marker")
			check(not visual.find_children("*","MeshInstance3D",true,false).is_empty(),"Visible game mesh")
			check(visual.find_children("*","CollisionObject3D",true,false).is_empty(),"No gameplay bodies in visual")
			visual.free()
		var override:=profile.duplicate(true); override.preferred_scene="res://mods/custom.tscn"
		check(AuthoredArt.miniature(override)==null,"Explicit mod appearance retains priority")
		check(ResourceLoader.exists(profile.fallback_model_scene),"Original fallback preserved")
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
	game.scenario=ScenarioLibrary.read("res://resources/scenarios/iron_reliquary.json").data
	game.settings=AppSettings.new(); game.settings.autosave=false
	root.add_child(game)
	await physics_frame
	for unit: TableUnit in game.battlefield.units.get_children():
		for model in unit.models:
			check(is_equal_approx(model.base_radius,ContentRegistry.base_radius(unit.definition)),"Canonical base unchanged")
			check(is_equal_approx(model.los_origin.position.y,float(unit.definition.los_height)),"Canonical LOS unchanged")
			check(model.visual_root.get_child(0).has_meta("authored_art"),"New artwork used on table")
			check(is_equal_approx(model.get_node("Collision").shape.radius,model.base_radius),"Picking remains canonical")
			if unit.definition.id in ["legion_trooper","legion_walker"]: check(model.cosmetic_muzzle().distance_to(model.eye())>.1,"Cosmetic muzzle is separate from authoritative LOS")
	var piece: TerrainPiece=game.battlefield.terrain.get_child(0)
	check(piece.has_node("MonumentalArchitecture"),"Basilica art present")
	check(piece.footprint().size()==2 and piece.blocks_los and piece.blocks_movement,"Original L-shaped footprint and rules")
	check(piece.overlaps_base(piece.to_global(Vector3(0,0,-3.1)),.1),"Back wall remains blocking")
	check(not piece.overlaps_base(piece.to_global(Vector3(2,0,1)),.5),"Courtyard remains open")
	var before:=WorldState.capture(game)
	var camera_before: Transform3D=game.camera_rig.transform
	var inspector:=MiniatureInspector.new()
	inspector.game=game; inspector.model=game.battlefield.units.get_child(0).models[0]
	game.add_child(inspector)
	await process_frame
	check(game.menu_open and game.interaction.read_only and not game.camera_rig.is_processing_input(),"Inspection gates gameplay and camera input")
	var key:=InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=true
	inspector._input(key)
	check(before==WorldState.capture(game),"Inspection input does not mutate game")
	inspector.yaw=PI/2; inspector.pitch=.3; inspector.update_camera(1)
	check(inspector.camera.position.distance_to(inspector.focus)>1,"Close orbit stays outside sculpt")
	inspector.close(); await process_frame
	check(not game.menu_open and not game.interaction.read_only,"Return restores input state")
	check(camera_before.is_equal_approx(game.camera_rig.transform),"Return preserves tactical camera")
	check(before==WorldState.capture(game),"Inspect/orbit/return preserves canonical snapshot")
	var animation:=UnitAnimationController.new(game.battlefield.units.get_child(0).models[0])
	animation.react(UnitAnimationController.State.ATTACKING); animation.update(.01,.1,false,false,false)
	check(animation.state==UnitAnimationController.State.ATTACKING,"Existing animation fallback operates on authored GLB")
	var captured:=ScenarioFactory.capture(game)
	check(ScenarioDefinition.validate(captured).is_empty(),"Showcase scenario capture validates")
	check(captured.terrain[0].kind=="ruin" and captured.terrain[0].size==[13.0,10.0,7.0],"Art keeps persistence footprint")
	game.queue_free(); await process_frame
	# Mixed-source batch regression: all faces need indices before primitive batching.
	var box:=DioramaGeometry.box_mesh(Vector3(.3,.4,.5))
	var arrays:=box.surface_get_arrays(0)
	check(not (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty(),"Fallback chamfer mesh has explicit indices")
	print("GRIMTABLE ART 0120: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
