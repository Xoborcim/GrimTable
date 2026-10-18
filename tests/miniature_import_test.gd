extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("FAIL "+label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://import_test")
	var source := Node3D.new()
	TableVisuals.box(source,Vector3(1,2,1),Vector3.UP,Color.WHITE)
	var image:=Image.create(2,2,false,Image.FORMAT_RGBA8)
	image.fill(Color("a88b5d"))
	(source.get_child(0).material_override as StandardMaterial3D).albedo_texture=ImageTexture.create_from_image(image)
	var document := GLTFDocument.new()
	document.root_node_mode=GLTFDocument.ROOT_NODE_MODE_MULTI_ROOT
	var state := GLTFState.new()
	document.append_from_scene(source,state)
	check(document.write_to_filesystem(state,"user://import_test/test.glb") == OK,"Create original fixture")
	check(document.write_to_filesystem(state,"user://import_test/test.gltf") == OK,"Create external dependency fixture")
	source.free()
	var gltf:=MiniatureLibrary.import_model("user://import_test/test.gltf")
	check(gltf.has("record"),"GLTF relative buffer and textures: "+str(gltf.get("error","OK")))
	if gltf.has("record"):
		var path: String=MiniatureLibrary.ROOT+str(gltf.record.id)+"/"+str(gltf.record.model)
		var copied:=MiniatureLibrary.read_document(path)
		check(not MiniatureLibrary.validate_document(copied.doc,copied.binary,path.get_base_dir()).has("error"),"Managed dependencies survive independently")
	var imported := MiniatureLibrary.import_model("user://import_test/test.glb")
	check(not imported.has("error"),"Runtime GLB import: "+str(imported.get("error","OK")))
	if imported.has("record"):
		var record: Dictionary = imported.record
		record.scale=.75; record.rotation=[0,90,0]; record.base_mm=60; record.profile="fixture_"+str(record.id)
		check(MiniatureLibrary.save_record(record),"Transforms and base saved")
		var visual := MiniatureLibrary.assigned(str(record.profile),"variant_1")
		check(visual != null,"Assigned visual available")
		if visual != null:
			check(visual.get_child(0).scale.is_equal_approx(Vector3.ONE*.75),"Scale restored")
			check(is_equal_approx(visual.get_child(0).rotation_degrees.y,90),"Rotation restored")
			visual.free()
		var file := FileAccess.open(MiniatureLibrary.ROOT+str(record.id)+"/miniature.json",FileAccess.READ)
		check(JSON.parse_string(file.get_as_text()).base_mm == 60,"Base preference persists")
		MiniatureLibrary.cache.clear()
		DirAccess.remove_absolute(MiniatureLibrary.ROOT+str(record.id)+"/model.glb")
		check(MiniatureLibrary.instantiate_record(record) == null,"Missing visual safely falls back")
	for path in ["../secret.bin","C:/secret.bin","https://bad.test/a.png","folder/../../bad","folder\\bad.png","%2e%2e/a"]: check(not MiniatureLibrary.safe_relative(path),"Reject traversal "+path)
	check(MiniatureLibrary.safe_relative("textures/paint.png"),"Relative dependencies allowed")
	var broken := FileAccess.open("user://import_test/broken.glb",FileAccess.WRITE)
	broken.store_string("broken"); broken.close()
	check(MiniatureLibrary.import_model("user://import_test/broken.glb").has("error"),"Malformed GLB rejected")
	check(MiniatureLibrary.import_model("user://import_test/test.fbx").has("error"),"FBX conversion guidance")
	check(MiniatureLibrary.validate_document({"asset":false},PackedByteArray(),"").has("error"),"Broken header type rejected")
	var oversized:=FileAccess.open("user://import_test/oversized.glb",FileAccess.WRITE)
	oversized.seek(MiniatureLibrary.LIMIT+1); oversized.store_8(0); oversized.close()
	check(MiniatureLibrary.import_model("user://import_test/oversized.glb").has("error"),"Oversized model rejected before parsing")
	var png:=PackedByteArray([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82,0,0,32,0,0,0,32,0])
	check(MiniatureLibrary.image_dimensions(png)==Vector2i(8192,8192),"Oversized texture header detected without decoding")
	var parsed := MiniatureLibrary.read_document("user://import_test/test.glb")
	parsed.doc.buffers[0].uri="../outside.bin"
	check(MiniatureLibrary.validate_document(parsed.doc,parsed.binary,"user://import_test").has("error"),"Traversal rejected before native importer")
	parsed.doc.erase("buffers")
	check(MiniatureLibrary.validate_document(parsed.doc,parsed.binary,"user://import_test").has("error"),"Invalid buffer reference rejected")
	var panel := MiniatureLibraryPanel.new()
	var fake_app:=Node.new()
	panel.app=fake_app
	root.add_child(panel)
	await process_frame
	check(panel.viewport != null,"Library interactive viewport created")
	panel.queue_free()
	fake_app.free()
	await process_frame
	if "--with-blender" in OS.get_cmdline_user_args():
		var blender:=BlenderConversion.detect()
		check(not blender.is_empty(),"Blender detected")
		var obj:=FileAccess.open("user://import_test/original.obj",FileAccess.WRITE)
		obj.store_string("v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n"); obj.close()
		var converted:=BlenderConversion.convert(ProjectSettings.globalize_path("user://import_test/original.obj"),blender)
		check(converted.has("path"),"Blender OBJ conversion")
		if converted.has("path"): check(MiniatureLibrary.import_model(converted.path).has("record"),"Converted OBJ imports")
		var fixture:=FileAccess.open("user://import_test/fbx_fixture.py",FileAccess.WRITE)
		fixture.store_string("import bpy,sys\nbpy.ops.wm.read_factory_settings(use_empty=True)\nbpy.ops.mesh.primitive_cube_add()\nbpy.ops.export_scene.fbx(filepath=sys.argv[-1])\n"); fixture.close()
		var output:=[]
		var target:=ProjectSettings.globalize_path("user://import_test/original.fbx")
		var code:=OS.execute(blender,["--background","--factory-startup","--disable-autoexec","--python",ProjectSettings.globalize_path("user://import_test/fbx_fixture.py"),"--",target],output,true)
		check(code==0,"Original FBX fixture generated")
		converted=BlenderConversion.convert(target,blender)
		check(converted.has("path"),"Blender FBX conversion")
		if converted.has("path"): check(MiniatureLibrary.import_model(converted.path).has("record"),"Converted FBX imports")
	print("GRIMTABLE IMPORT: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
