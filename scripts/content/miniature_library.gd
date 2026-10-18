class_name MiniatureLibrary
extends RefCounted

const ROOT := "user://miniatures/"
const BASES := [25,32,40,50,60,80,100]
const LIMIT := 32000000
static var cache := {}
static var warnings: Array[String] = []
static var record_cache: Array[Dictionary] = []
static var records_loaded := false

static func records() -> Array[Dictionary]:
	if records_loaded: return record_cache
	var result: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(ROOT): return result
	for folder in DirAccess.get_directories_at(ROOT):
		if not FileAccess.file_exists(ROOT+folder+"/miniature.json"): continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+folder+"/miniature.json"))
		if data is Dictionary and data.get("id","") == folder: result.append(data)
	record_cache = result
	records_loaded = true
	return result

static func safe_relative(uri: String) -> bool:
	if uri.is_empty() or uri.is_absolute_path() or uri.contains(":") or uri.contains("\\") or uri.contains("%") or uri.contains("?") or uri.contains("#"): return false
	for part in uri.split("/"):
		if part in ["..",".",""]: return false
	return true

static func safe_id(id: String) -> bool:
	return not id.is_empty() and id.is_valid_identifier() and id.begins_with("mini_")

static func read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error":"Model file not found."}
	if file.get_length() > LIMIT: return {"error":"Model is too large: maximum 32 MB."}
	var doc: Variant
	var binary := PackedByteArray()
	if path.get_extension().to_lower() == "glb":
		if file.get_length() < 28 or file.get_32() != 0x46546c67 or file.get_32() != 2 or file.get_32() != file.get_length(): return {"error":"Invalid GLB 2 header."}
		var length := file.get_32()
		if file.get_32() != 0x4e4f534a or length > file.get_length()-20: return {"error":"Invalid GLB JSON chunk."}
		doc = JSON.parse_string(file.get_buffer(length).get_string_from_utf8())
		if file.get_position()+8 <= file.get_length():
			var size := file.get_32()
			if file.get_32() != 0x004e4942 or size > file.get_length()-file.get_position(): return {"error":"Invalid GLB binary chunk."}
			binary = file.get_buffer(size)
	else: doc = JSON.parse_string(file.get_as_text())
	if not doc is Dictionary: return {"error":"The model contains invalid JSON."}
	return {"doc":doc,"binary":binary}

static func validate_document(doc: Dictionary, binary: PackedByteArray, folder: String) -> Dictionary:
	if not doc.get("asset") is Dictionary: return {"error":"Missing glTF asset header."}
	if doc.get("asset",{}).get("version","") != "2.0": return {"error":"Only glTF 2 models are supported."}
	var dependencies := {}
	var total := binary.size()
	var values := 0
	for key in ["nodes","meshes","materials","images","textures","accessors","bufferViews","skins","animations","buffers"]:
		if not doc.get(key,[]) is Array or doc.get(key,[]).size() > (4096 if key in ["accessors","bufferViews"] else 512): return {"error":"Model complexity limit exceeded: "+key}
	if doc.get("animations",[]).size() > 32: return {"error":"Maximum 32 animation clips."}
	# Only standard data, with no vendor extensions or scripted resources.
	var sanitized := doc.duplicate(true)
	remove_metadata(sanitized)
	var issue := check_structure(sanitized)
	if not issue.is_empty(): return {"error":issue}
	doc = sanitized
	var visited := {}
	for i in doc.get("nodes",[]).size():
		issue = SafeModVisual.check_node(i,doc.nodes,visited,{})
		if not issue.is_empty(): return {"error":issue}
	for accessor in doc.get("accessors",[]):
		if not accessor is Dictionary or accessor.has("sparse") or not ScenarioDefinition.integer(accessor.get("count"),1,300000): return {"error":"Invalid or oversized mesh accessor."}
		values += int(accessor.count)
	if values > 2000000: return {"error":"Model mesh complexity exceeds two million accessor values."}
	for collection in ["buffers","images"]:
		for resource in doc.get(collection,[]):
			if not resource is Dictionary: return {"error":"Invalid model dependency."}
			if resource.has("uri"):
				var uri := str(resource.uri).uri_decode()
				if not safe_relative(uri): return {"error":"Unsupported external resource path: "+uri}
				resource.uri = uri
				if not dependency_without_links(folder,uri): return {"error":"Linked external resources are not supported."}
				if uri.get_extension().to_lower() not in ["bin","png","jpg","jpeg"]: return {"error":"Unsupported dependency type."}
				if not dependencies.has(uri):
					var dep := FileAccess.open(folder.path_join(uri),FileAccess.READ)
					if dep == null: return {"error":"Missing material or buffer: "+uri}
					if dep.get_length() > LIMIT: return {"error":"Dependency exceeds 32 MB."}
					dependencies[uri] = dep.get_buffer(dep.get_length())
					total += dep.get_length()
	if total > LIMIT: return {"error":"Combined model resources exceed 32 MB."}
	var buffers: Array[PackedByteArray] = []
	for buffer in doc.get("buffers",[]):
		var data: PackedByteArray = dependencies.get(str(buffer.get("uri","")),binary)
		if not ScenarioDefinition.integer(buffer.get("byteLength"),0,data.size()): return {"error":"Buffer length exceeds data."}
		buffers.append(data)
	for view in doc.get("bufferViews",[]):
		if not view is Dictionary or not ScenarioDefinition.integer(view.get("buffer"),0,buffers.size()-1): return {"error":"Invalid buffer index."}
		var limit := buffers[int(view.buffer)].size()
		if not ScenarioDefinition.integer(view.get("byteOffset",0),0,limit) or not ScenarioDefinition.integer(view.get("byteLength"),1,limit) or int(view.get("byteOffset",0))+int(view.byteLength)>limit: return {"error":"Buffer view exceeds data."}
	var pixels := 0
	for image in doc.get("images",[]):
		var data: PackedByteArray
		if image.has("uri"): data = dependencies[str(image.uri)]
		else:
			if not ScenarioDefinition.integer(image.get("bufferView"),0,doc.get("bufferViews",[]).size()-1): return {"error":"Invalid texture buffer."}
			var view: Dictionary = doc.bufferViews[int(image.bufferView)]
			data = buffers[int(view.buffer)].slice(int(view.get("byteOffset",0)),int(view.get("byteOffset",0))+int(view.byteLength))
		# Header inspection happens before handing images to the runtime decoder.
		var dimensions := image_dimensions(data)
		if dimensions.x < 1 or dimensions.y < 1 or dimensions.x > 4096 or dimensions.y > 4096: return {"error":"Use PNG/JPEG textures no larger than 4096 pixels."}
		pixels += dimensions.x*dimensions.y
	if pixels > 16777216: return {"error":"Combined textures exceed 16 million pixels."}
	return {"dependencies":dependencies,"doc":sanitized}

static func image_dimensions(data: PackedByteArray) -> Vector2i:
	if data.size() >= 24 and data.slice(0,8) == PackedByteArray([137,80,78,71,13,10,26,10]):
		return Vector2i(be32(data,16),be32(data,20))
	if data.size() > 4 and data[0] == 255 and data[1] == 216:
		var i := 2
		while i+9 < data.size():
			if data[i] != 255: return Vector2i.ZERO
			var marker := data[i+1]
			var length := int(data[i+2])*256+int(data[i+3])
			if length < 2 or i+2+length > data.size(): return Vector2i.ZERO
			if marker in [192,193,194]: return Vector2i(int(data[i+7])*256+data[i+8],int(data[i+5])*256+data[i+6])
			i += length+2
	return Vector2i.ZERO

static func be32(data: PackedByteArray, at: int) -> int:
	return int(data[at])*16777216+int(data[at+1])*65536+int(data[at+2])*256+data[at+3]

static func dependency_without_links(folder: String, uri: String) -> bool:
	var current := folder
	for part in uri.split("/"):
		var directory := DirAccess.open(current)
		if directory == null or directory.is_link(part): return false
		current = current.path_join(part)
	return true

static func glb_bytes(doc: Dictionary, binary: PackedByteArray) -> PackedByteArray:
	var json := JSON.stringify(doc).to_utf8_buffer()
	while json.size()%4: json.append(32)
	var data := PackedByteArray()
	data.resize(20)
	data.encode_u32(0,0x46546c67); data.encode_u32(4,2)
	data.encode_u32(12,json.size()); data.encode_u32(16,0x4e4f534a)
	data.append_array(json)
	if not binary.is_empty():
		var header := PackedByteArray(); header.resize(8)
		header.encode_u32(0,binary.size()); header.encode_u32(4,0x004e4942)
		data.append_array(header); data.append_array(binary)
	data.encode_u32(8,data.size())
	return data

static func remove_metadata(value: Variant) -> void:
	if value is Dictionary:
		value.erase("extras")
		for key in value: remove_metadata(value[key])
	elif value is Array:
		for item in value: remove_metadata(item)

static func check_structure(value: Variant, depth: int = 0) -> String:
	if depth > 32: return "Model nesting exceeds limit."
	if value is float and not is_finite(value): return "Invalid numeric value."
	if value is Dictionary:
		for key in value:
			if str(key).to_lower() in ["extensions","extensionsused","extensionsrequired","script"]: return "This model contains unsupported extensions or scripts. Export standard glTF 2."
			var issue := check_structure(value[key],depth+1)
			if not issue.is_empty(): return issue
	elif value is Array:
		if value.size() > 100000: return "Model array exceeds limit."
		for item in value:
			var issue := check_structure(item,depth+1)
			if not issue.is_empty(): return issue
	return ""

static func import_model(source: String) -> Dictionary:
	if source.get_extension().to_lower() not in ["glb","gltf"]: return {"error":"OBJ/FBX needs Blender conversion. Select your Blender installation or export GLB manually."}
	var parsed := read_document(source)
	if parsed.has("error"): return parsed
	var checked := validate_document(parsed.doc,parsed.binary,source.get_base_dir())
	if checked.has("error"): return checked
	var id := ScenarioLibrary.new_id("mini")
	var folder := ROOT+id+"/"
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return {"error":"Cannot create miniature folder."}
	var model := folder+"model."+source.get_extension().to_lower()
	var model_file := FileAccess.open(model,FileAccess.WRITE)
	if model_file == null: return {"error":"Cannot copy model."}
	if source.get_extension().to_lower()=="glb": model_file.store_buffer(glb_bytes(checked.doc,parsed.binary))
	else: model_file.store_string(JSON.stringify(checked.doc))
	model_file.close()
	for uri: String in checked.dependencies:
		var target := folder.path_join(uri)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var file := FileAccess.open(target,FileAccess.WRITE)
		if file == null: return {"error":"Cannot copy model dependency."}
		file.store_buffer(checked.dependencies[uri]); file.close()
	var record := {"id":id,"name":source.get_file().get_basename(),"model":model.get_file(),"scale":1.0,"rotation":[0,0,0],"offset":0.0,"base_mm":32,"los_marker":1.35,"profile":"","creator":"","source":"","license":"","notes":"","override":false,"primary":"#c3b59b","secondary":"#596875","metallic":.3,"roughness":.7,"emission":0.0,"base_style":"Industrial"}
	var scene := instantiate_record(record)
	if scene == null: return {"error":"The model could not be loaded. Export a standard glTF 2 mesh."}
	scene.free()
	save_record(record)
	return {"record":record}

static func save_record(record: Dictionary) -> bool:
	if not safe_id(str(record.get("id",""))): return false
	if int(record.get("base_mm",32)) not in BASES: return false
	if not ScenarioDefinition.number(record.get("scale"),.00001,10000): return false
	var file := FileAccess.open(ROOT+str(record.id)+"/miniature.json",FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(record,"\t")); file.close()
	records_loaded = false
	return true

static func instantiate_record(record: Dictionary) -> Node3D:
	if not safe_id(str(record.get("id",""))) or not safe_relative(str(record.get("model",""))): return null
	var path: String = ROOT+str(record.id)+"/"+str(record.model)
	if not FileAccess.file_exists(path):
		if not warnings.has(path): warnings.append(path); push_warning("Local miniature missing; using authored fallback: "+path)
		return null
	if not cache.has(path):
		var parsed := read_document(path)
		if parsed.has("error"): return null
		var checked := validate_document(parsed.doc,parsed.binary,path.get_base_dir())
		if checked.has("error"): return null
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var bytes: PackedByteArray = glb_bytes(checked.doc,parsed.binary) if path.get_extension()=="glb" else JSON.stringify(checked.doc).to_utf8_buffer()
		if document.append_from_buffer(bytes,ProjectSettings.globalize_path(path.get_base_dir())+"/",state) != OK: return null
		var scene := document.generate_scene(state) as Node3D
		if scene == null: return null
		sanitize(scene)
		var packed := PackedScene.new()
		packed.pack(scene); scene.free()
		cache[path] = packed
	var root := Node3D.new()
	var visual: Node3D = cache[path].instantiate()
	root.add_child(visual)
	root.set_meta("animation_map",record.get("animation_map",{}))
	root.set_meta("base_style",record.get("base_style","Industrial"))
	visual.scale = Vector3.ONE*float(record.get("scale",1))
	var rotation: Array = record.get("rotation",[0,0,0])
	visual.rotation_degrees = Vector3(float(rotation[0]),float(rotation[1]),float(rotation[2]))
	visual.position.y = float(record.get("offset",0))
	if record.get("override",false):
		var meshes := visual.find_children("*","MeshInstance3D",true,false)
		for i in meshes.size():
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(str(record.get("primary" if i%2==0 else "secondary","#aaaaaa")))
			material.metallic = clampf(float(record.get("metallic",.3)),0,1)
			material.roughness = clampf(float(record.get("roughness",.7)),0,1)
			material.emission_enabled = float(record.get("emission",0)) > 0
			material.emission = material.albedo_color
			material.emission_energy_multiplier = clampf(float(record.get("emission",0)),0,1)
			meshes[i].material_override = material
	return root

static func sanitize(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		if child is Camera3D or child is Light3D or child is CollisionObject3D or child is CollisionShape3D:
			node.remove_child(child); child.free()
		else: sanitize(child)
	if node is AnimationPlayer:
		node.stop()
		node.autoplay = ""

static func assigned(profile: String, variant: String) -> Node3D:
	var options: Array[Dictionary] = []
	for record in records():
		if record.id == variant and record.get("profile","") == profile: return instantiate_record(record)
		if record.get("profile","") == profile: options.append(record)
	if options.is_empty(): return null
	return instantiate_record(options[(variant.hash() & 0x7fffffff)%options.size()])

static func bounds(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh == null: continue
		var transform := Transform3D.IDENTITY
		var node: Node3D = mesh
		while node != root:
			transform = node.transform*transform
			node = node.get_parent() as Node3D
			if node == null: break
		var box: AABB = transform*mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
