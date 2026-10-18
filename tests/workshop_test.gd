extends SceneTree

var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("WORKSHOP: "+label)

func run() -> void:
	var data:=WorkshopStore.fresh();data.id=ScenarioLibrary.new_id("figure");data.name="Workshop test"
	check(WorkshopStore.validate(data).is_empty(),"Valid local document")
	for pair in [["source","../../model.glb"],["id","../figure_bad"],["overlay","../../secret.png"],["scale",INF],["head_yaw",26],["pose","Arbitrary rig"]]:
		var bad:=data.duplicate(true);bad[pair[0]]=pair[1];check(not WorkshopStore.validate(bad).is_empty(),"Reject unsafe "+str(pair[0]))
	var bad:=data.duplicate(true);bad.parts.head=12;check(not WorkshopStore.validate(bad).is_empty(),"Reject incompatible part")
	bad=data.duplicate(true);bad.source="swarm_hunter";bad.parts.head=1;check(not WorkshopStore.validate(bad).is_empty(),"Reject wrong component family")
	bad=data.duplicate(true);bad.source="swarm_hunter";bad.pose="Aiming";check(not WorkshopStore.validate(bad).is_empty(),"Reject unsupported posing")
	bad=data.duplicate(true);bad.effects.wash=4;check(not WorkshopStore.validate(bad).is_empty(),"Bound finishing")
	bad=data.duplicate(true);bad.colors.primary="javascript";check(not WorkshopStore.validate(bad).is_empty(),"Validate paint colors")
	var scheme:=WorkshopStore.scheme(data,"Test scheme");check(WorkshopStore.validate(scheme,true).is_empty(),"Versioned scheme")
	scheme.script="bad.gd";check(not WorkshopStore.validate(scheme,true).is_empty(),"Reject executable/unknown scheme fields");scheme.erase("script")
	check(WorkshopStore.atomic_json(WorkshopStore.ROOT+"test_scheme.json",scheme),"Safe scheme write")
	var imported_scheme:=WorkshopStore.import_scheme(WorkshopStore.ROOT+"test_scheme.json")
	check(imported_scheme.get("colors",{})==scheme.colors and is_equal_approx(float(imported_scheme.get("effects",{}).get("wash",-1)),float(scheme.effects.wash)),"Scheme round trip")
	check(WorkshopStore.save_scheme(scheme),"Save named scheme")
	check(not WorkshopStore.saved_schemes().is_empty(),"Load saved schemes")
	for source in AuthoredArt.MODELS:
		var value:=WorkshopStore.fresh(source)
		var ids: Image=(load(WorkshopAppearance.ids_path(source)) as Texture2D).get_image()
		check(ids.get_width()==(2048 if source=="legion_walker" else 1024),"Categorical region texture budget")
		check(not ids.is_compressed(),"Categorical IDs stay lossless")
		var root:=WorkshopAppearance.instantiate(value);check(root!=null,"Model loads "+source)
		if root==null:continue
		var textured:=0
		for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
			var mat:=mesh.get_active_material(0) as ShaderMaterial
			if mat==null:continue
			textured+=1
			check(mat.get_shader_parameter("normal_tex")!=null and mat.get_shader_parameter("orm")!=null,"Recolor retains detail maps")
		check(textured>0,"Baked surfaces preserved")
		if source=="legion_trooper":
			value.parts.head=2;value.parts.backpack=1;value.pose="Aiming";value.head_yaw=4
			WorkshopAppearance.apply_parts(root,value)
			check(root.find_child("head_2",true,false).visible and not root.find_child("head_0",true,false).visible,"Helmet swap replaces original")
			check(root.find_child("backpack_1",true,false).visible,"Backpack socket fits")
			check(absf(root.find_child("head_2",true,false).rotation.y)>0,"Supported rigid pose visible")
		root.free()
	check(not WorkshopAppearance.capable("mini_unknown").brush and not WorkshopAppearance.capable("swarm_hunter").assembly,"Honest capability fallback")
	# Front square has one UV island; hidden square has a separate island. Rays
	# must not paint the hidden plane or an unrelated atlas location.
	var scene:=Node3D.new();get_root().add_child(scene)
	var camera:=Camera3D.new();camera.position=Vector3(0,0,3);scene.add_child(camera);camera.look_at(Vector3.ZERO)
	for z in [0.0,-1.0]:
		var mesh:=ArrayMesh.new();var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,-1,z),Vector3(1,-1,z),Vector3(1,1,z),Vector3(-1,1,z)])
		var lo:=.1 if z==0 else .65
		arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(lo,.1),Vector2(lo+.2,.1),Vector2(lo+.2,.3),Vector2(lo,.3)])
		arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3]);mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.material_override=ShaderMaterial.new();instance.material_override.shader=preload("res://assets/grimtable/materials/baked_finish.gdshader");scene.add_child(instance)
	var brush:=WorkshopBrush.new();brush.build(scene,true)
	var hit:=brush.hit(Vector3(0,0,3),Vector3.FORWARD)
	check(not hit.is_empty() and Vector3(hit.position).is_equal_approx(Vector3.ZERO),"Closest visible triangle")
	check(Vector2(hit.uv).is_equal_approx(Vector2(.2,.2)),"Barycentric UV lookup")
	await process_frame
	var at:=camera.unproject_position(Vector3.ZERO);var blank:=brush.image.save_png_to_buffer()
	brush.begin();brush.dab(camera,at,Color.RED,8,.8);check(brush.end(),"Player-style ray brush changes texture")
	var painted:=brush.image.save_png_to_buffer()
	check(brush.image.get_pixel(204,204).a>0,"Visible UV island painted")
	check(brush.image.get_pixel(768,204).a==0,"Occluded geometry unpainted")
	check(brush.image.get_pixel(500,500).a==0,"Unrelated UV island unpainted")
	brush.restore(blank);check(brush.image.get_pixel(204,204).a==0,"Brush undo restores original")
	brush.restore(painted);check(brush.image.get_pixel(204,204).a>0,"Brush redo restores stroke")
	brush.begin();brush.dab(camera,at,Color.WHITE,8,1,true);brush.end();check(brush.image.get_pixel(204,204).a==0,"Eraser clears paint")
	brush.restore(painted)
	var saved:=WorkshopStore.save(data,brush.image)
	check(not saved.has("error"),"Save editable overlay")
	if not saved.has("error"):
		var restored:=WorkshopStore.read_json(WorkshopStore.ROOT+"figures/"+saved.id+".json")
		check(WorkshopStore.validate(restored).is_empty(),"Saved data validation")
		check(WorkshopStore.image(restored,"overlay").get_pixel(204,204).a>0,"Paint survives disk round trip")
		check(WorkshopStore.save(restored,brush.image).get("id","")==saved.id,"Atomic replacement of existing figure")
		check(WorkshopStore.assign("profile","legion_trooper",saved.id),"Local profile assignment")
		check(WorkshopStore.assigned(ContentRegistry.unit({"unit_id":"legion_trooper"}),"test").id==saved.id,"Appearance resolves outside canonical state")
		check(WorkshopStore.assigned(ContentRegistry.unit({"unit_id":"swarm_hunter"}),"test").is_empty(),"Incompatible profile rejected")
		check(WorkshopStore.delete(saved.id),"Managed deletion")
		check(WorkshopAppearance.assigned(ContentRegistry.unit({"unit_id":"legion_trooper"}),"test","")==null,"Missing cosmetics fall back")
	var base:=Node3D.new();scene.add_child(base);WorkshopAppearance.add_base(base,data,.63)
	check(is_equal_approx((base.get_node("WorkshopRim").mesh as CylinderMesh).bottom_radius,.63),"Canonical base diameter retained")
	check(base.find_children("*","CollisionObject3D",true,false).is_empty(),"Cosmetics add no authoritative collision")
	check(WorkshopAppearance.stencil("A07").get_width()==18,"Original stencil letters and numbers")
	# Imported materials keep their textures and work without masks/rig/UV promises.
	var fixture:=Node3D.new();var cube:=TableVisuals.box(fixture,Vector3.ONE,Vector3.UP,Color.WHITE)
	var original_image:=Image.create(2,2,false,Image.FORMAT_RGBA8);original_image.fill(Color("a88b5d"))
	(cube.material_override as StandardMaterial3D).albedo_texture=ImageTexture.create_from_image(original_image)
	var gltf:=GLTFDocument.new();gltf.root_node_mode=GLTFDocument.ROOT_NODE_MODE_MULTI_ROOT
	var gltf_state:=GLTFState.new();gltf.append_from_scene(fixture,gltf_state)
	DirAccess.make_dir_recursive_absolute("user://workshop_fixture")
	check(gltf.write_to_filesystem(gltf_state,"user://workshop_fixture/original.glb")==OK,"Original import fixture")
	fixture.free()
	var imported:=MiniatureLibrary.import_model("user://workshop_fixture/original.glb")
	check(imported.has("record"),"Library import preserved / "+str(imported.get("error","OK")))
	if imported.has("record"):
		var record: Dictionary=imported.record;record.profile="legion_trooper";MiniatureLibrary.save_record(record)
		var foreign:=WorkshopStore.fresh(record.id);foreign.materials["0"]="8c4035"
		var visual:=WorkshopAppearance.instantiate(foreign)
		check(visual!=null,"Imported Workshop preview")
		if visual!=null:
			var meshes:=visual.find_children("*","MeshInstance3D",true,false)
			var material:=meshes[0].get_active_material(0) as StandardMaterial3D
			check(material.albedo_texture!=null,"Imported tint retains original texture")
			check(material.albedo_color.is_equal_approx(Color("8c4035")),"Imported per-material tint")
			visual.free()
		check(not WorkshopAppearance.capable(record.id).brush,"Unsupported imported UV painting disabled")
		var saved_foreign:=WorkshopStore.save(foreign)
		check(not saved_foreign.has("error"),"Imported appearance saves")
		if not saved_foreign.has("error"):
			WorkshopStore.assign("model","foreign_test",saved_foreign.id)
			check(not WorkshopStore.assigned(ContentRegistry.unit({"unit_id":"legion_trooper"}),"foreign_test").is_empty(),"Imported unit cosmetic resolves")
			DirAccess.remove_absolute(MiniatureLibrary.ROOT+record.id+"/model.glb")
			check(WorkshopAppearance.assigned(ContentRegistry.unit({"unit_id":"legion_trooper"}),"foreign_test","")==null,"Missing imported model gracefully falls back")
			WorkshopStore.delete(saved_foreign.id)
	# Island-clipped markings cannot spill into adjacent/unrelated UV charts.
	var uv:=Vector2(.5,.5)
	for y in range(10,1000,10):
		for x in range(10,1000,10):
			if WorkshopAppearance.island_at(Vector2(x,y)/1024.0)>0:uv=Vector2(x,y)/1024.0;break
		if WorkshopAppearance.island_at(uv)>0:break
	var island:=WorkshopAppearance.island_at(uv)
	data.decals=[{"kind":"Stripe","u":uv.x,"v":uv.y,"size":.03,"angle":30,"color":"ffffff","text":"07","island":island}]
	check(WorkshopStore.validate(data).is_empty(),"Marking schema validates")
	var marking:=WorkshopAppearance.markings(data);var ink_count:=0;var leaks:=0
	for y in range(maxi(0,int(uv.y*1024)-32),mini(1024,int(uv.y*1024)+32)):
		for x in range(maxi(0,int(uv.x*1024)-32),mini(1024,int(uv.x*1024)+32)):
			if marking.get_pixel(x,y).a>0:
				ink_count+=1
				if WorkshopAppearance.island_at(Vector2(x,y)/1024.0)!=island:leaks+=1
	check(ink_count>0,"Actual marking pixels")
	check(leaks==0,"Marking clipped to authored island")
	bad=data.duplicate(true);bad.decals[0].island=-1;check(not WorkshopStore.validate(bad).is_empty(),"Invalid marking rejected")
	scene.free()
	print("GRIMTABLE WORKSHOP: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
