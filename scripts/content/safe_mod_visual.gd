class_name SafeModVisual
extends RefCounted

static var cache: Dictionary = {}

static func validate_glb(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return "Missing GLB"
	if file.get_length() > 16000000 or file.get_length() < 28: return "GLB must be under 16 MB"
	if file.get_32() != 0x46546c67 or file.get_32() != 2: return "Invalid GLB 2 header"
	if file.get_32() != file.get_length(): return "Invalid GLB length"
	var length := file.get_32()
	if file.get_32() != 0x4e4f534a or length > file.get_length() - 20: return "Invalid GLB JSON chunk"
	var parsed := JSON.new()
	if parsed.parse(file.get_buffer(length).get_string_from_utf8()) != OK or not parsed.data is Dictionary: return "Invalid GLB JSON"
	var doc: Dictionary = parsed.data
	var issue := check_value(doc)
	if not issue.is_empty(): return issue
	for key in ["nodes", "meshes", "materials", "images", "textures", "accessors", "bufferViews", "skins", "animations"]:
		if not doc.get(key, []) is Array or doc.get(key, []).size() > (2048 if key in ["accessors", "bufferViews"] else 256): return "GLB collection exceeds limit: " + key
	if doc.get("meshes", []).is_empty() or doc.get("nodes", []).is_empty(): return "GLB needs visible mesh nodes"
	if not doc.get("skins", []).is_empty() or not doc.get("animations", []).is_empty(): return "Basic mods support static GLB visuals; export a static pose"
	var visited := {}
	for index in doc.nodes.size():
		issue = check_node(index, doc.nodes, visited, {})
		if not issue.is_empty(): return issue
	var values := 0
	for accessor in doc.get("accessors", []):
		if not accessor is Dictionary or accessor.has("sparse") or not ScenarioDefinition.integer(accessor.get("count"), 1, 250000): return "Invalid/oversized GLB accessor"
		values += int(accessor.count)
	if values > 2000000: return "GLB geometry budget exceeded"
	var binary_bytes := file.get_length() - 20 - length - 8
	for view in doc.get("bufferViews", []):
		if not view is Dictionary or not ScenarioDefinition.integer(view.get("byteLength"), 0, binary_bytes) or not ScenarioDefinition.integer(view.get("byteOffset", 0), 0, binary_bytes): return "Invalid GLB buffer view"
		if int(view.get("byteOffset", 0)) + int(view.byteLength) > binary_bytes: return "GLB buffer view exceeds data"
	var pixels := 0
	for image in doc.get("images", []):
		if not image is Dictionary or image.get("mimeType") != "image/png" or not ScenarioDefinition.integer(image.get("bufferView"), 0, doc.get("bufferViews", []).size() - 1): return "Use embedded PNG images in GLB"
		var view: Dictionary = doc.bufferViews[int(image.bufferView)]
		if int(view.byteLength) < 24: return "Truncated PNG"
		file.seek(20 + length + 8 + int(view.get("byteOffset", 0)))
		var header := file.get_buffer(24)
		if header.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]): return "Invalid PNG header"
		var width := int(header[16]) * 16777216 + int(header[17]) * 65536 + int(header[18]) * 256 + int(header[19])
		var height := int(header[20]) * 16777216 + int(header[21]) * 65536 + int(header[22]) * 256 + int(header[23])
		if width < 1 or height < 1 or width > 4096 or height > 4096: return "GLB texture dimensions exceed limit"
		pixels += width * height
	if pixels > 16777216: return "GLB texture budget exceeded"
	return ""

static func check_value(value: Variant, depth: int = 0) -> String:
	if depth > 32: return "GLB nesting exceeds limit"
	if value is float and not is_finite(value): return "GLB numbers must be finite"
	if value is Dictionary:
		for key in value:
			# Embedded buffers/images only, no paths, custom extensions or scripts.
			if key == "uri": return "GLB must embed buffers/textures; external URI forbidden"
			if str(key).to_lower() in ["script", "extras", "extensions", "extensionsused", "extensionsrequired"]: return "GLB extensions/extras/scripts are not supported"
			var error := check_value(value[key], depth + 1)
			if not error.is_empty(): return error
	elif value is Array:
		if value.size() > 100000: return "GLB array exceeds limit"
		for item in value:
			var error := check_value(item, depth + 1)
			if not error.is_empty(): return error
	return ""

static func check_node(index: int, nodes: Array, visited: Dictionary, active: Dictionary) -> String:
	if active.has(index) or active.size() > 64: return "Cyclic/deep GLB node graph"
	if visited.has(index): return ""
	if not nodes[index] is Dictionary or not nodes[index].get("children", []) is Array: return "Invalid GLB node"
	active[index] = true
	for child in nodes[index].get("children", []):
		if not ScenarioDefinition.integer(child, 0, nodes.size() - 1): return "Invalid GLB child index"
		var issue := check_node(int(child), nodes, visited, active)
		if not issue.is_empty(): return issue
	active.erase(index)
	visited[index] = true
	return ""

static func instantiate(path: String) -> Node3D:
	if not ModLoader.visual_roots.has(path): return null
	var root: String = ModLoader.visual_roots[path]
	if ModLoader.safe_path(root, path.trim_prefix(root + "/")) != path: return null
	if not cache.has(path):
		cache[path] = null
		var issue := validate_glb(path)
		if not issue.is_empty():
			push_warning("Unavailable mod visual " + path + ": " + issue + "; using GrimTable fallback")
			return null
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_buffer(FileAccess.get_file_as_bytes(path), "", state) != OK: return null
		var scene := document.generate_scene(state)
		if scene == null: return null
		sanitize(scene)
		var packed := PackedScene.new()
		packed.pack(scene)
		scene.free()
		cache[path] = packed
	return cache[path].instantiate() as Node3D if cache[path] != null else null

static func sanitize(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		if child is Camera3D or child is Light3D or child is CollisionObject3D or child is CollisionShape3D or child is AnimationPlayer or child is AnimationTree:
			node.remove_child(child)
			child.free()
		else: sanitize(child)
