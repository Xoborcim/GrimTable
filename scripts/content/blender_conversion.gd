class_name BlenderConversion
extends RefCounted

const SCRIPT := "import bpy,sys\nargs=sys.argv[sys.argv.index('--')+1:]\nsrc,dst=args\nbpy.ops.wm.read_factory_settings(use_empty=True)\nif src.lower().endswith('.fbx'):\n bpy.ops.import_scene.fbx(filepath=src)\nelse:\n bpy.ops.wm.obj_import(filepath=src)\nbpy.ops.export_scene.gltf(filepath=dst,export_format='GLB')\n"

static func detect() -> String:
	var file := ConfigFile.new()
	if file.load("user://blender.cfg") == OK:
		var path: String = file.get_value("converter","executable","")
		if FileAccess.file_exists(path): return path
	for folder in DirAccess.get_directories_at("C:/Program Files/Blender Foundation"):
		var path := "C:/Program Files/Blender Foundation/"+folder+"/blender.exe"
		if FileAccess.file_exists(path): return path
	return ""

static func configure(path: String) -> void:
	var file := ConfigFile.new()
	file.set_value("converter","executable",path)
	file.save("user://blender.cfg")

static func convert(source: String, executable: String) -> Dictionary:
	if source.get_extension().to_lower() not in ["obj","fbx"]: return {"error":"Select an OBJ or FBX file."}
	if not FileAccess.file_exists(executable): return {"error":"This OBJ/FBX needs conversion. Select your Blender installation, or export GLB in Blender manually."}
	var input := FileAccess.open(source,FileAccess.READ)
	if input == null or input.get_length()>MiniatureLibrary.LIMIT: return {"error":"Missing or oversized conversion source (maximum 32 MB)."}
	var folder := "user://miniature_conversion/"
	DirAccess.make_dir_recursive_absolute(folder)
	var script := FileAccess.open(folder+"convert.py",FileAccess.WRITE)
	script.store_string(SCRIPT); script.close()
	var destination := ProjectSettings.globalize_path(folder+ScenarioLibrary.new_id("converted")+".glb")
	var output: Array = []
	var code := OS.execute(executable,["--background","--factory-startup","--disable-autoexec","--python",ProjectSettings.globalize_path(folder+"convert.py"),"--",source,destination],output,true)
	if code != 0 or not FileAccess.file_exists(destination): return {"error":"Blender conversion failed. Open the model in Blender and export glTF Binary (.glb)."}
	return {"path":destination}
