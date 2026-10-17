extends SceneTree

# Usage: godot --headless --path . --script res://tools/import_visual.gd --
#   --asset=kenney_space_station_kit --file=res://assets/third_party/.../model.glb
#   --id=my_visual --height=2 --yaw=0
# Mesh bounds normalize ART ONLY. Base size, gameplay height and LOS stay in profiles.
func _initialize() -> void:
	call_deferred("run")

func bounds(node: Node, parent_transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var transform := parent_transform
	if node is Node3D: transform = parent_transform * node.transform
	var result := AABB()
	if node is MeshInstance3D and node.mesh != null: result = transform * node.mesh.get_aabb()
	for child in node.get_children():
		var child_bounds := bounds(child, transform)
		if child_bounds.has_volume(): result = child_bounds if not result.has_volume() else result.merge(child_bounds)
	return result

func fail(reason: String) -> void:
	push_error(reason)
	quit(1)

func run() -> void:
	var args := {}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		if parts.size() == 2: args[parts[0]] = parts[1]
	var source: String = args.get("file", "")
	var id: String = args.get("id", "")
	if not ScenarioDefinition.valid_id(id) or not source.begins_with("res://assets/third_party/") or ".." in source:
		fail("Expected a safe output ID and third_party GLB path"); return
	var height := float(args.get("height", 2))
	if not is_finite(height) or height < 0.1 or height > 30:
		fail("Visual height must be 0.1 to 30 inches"); return
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/third_party/assets.json"))
	var approved := false
	for asset: Dictionary in registry.assets:
		if asset.id != args.get("asset") or asset.status != "included" or asset.license not in ["CC0-1.0", "Public-Domain"]: continue
		if asset.get("license_verified") == null: continue
		for entry: Dictionary in asset.get("extracted_files", []):
			var expected := "res://" + str(asset.files[0].path).get_base_dir() + "/" + str(entry.archive_path)
			if source == expected and FileAccess.get_sha256(source) == entry.sha256: approved = true
	if not approved:
		fail("Source must match a checksum in a license-verified included asset entry"); return
	var resource := load(source) as PackedScene
	if resource == null: fail("Import the GLB in the Godot editor first"); return
	var visual := resource.instantiate() as Node3D
	var holder := Node3D.new()
	holder.rotation_degrees.y = float(args.get("yaw", 0))
	holder.add_child(visual)
	var box := bounds(holder)
	if not box.has_volume():
		holder.free(); fail("No visible mesh bounds"); return
	var scale := height / box.size.y
	var offset := Vector3(-(box.position.x + box.size.x / 2), -box.position.y, -(box.position.z + box.size.z / 2)) * scale
	var wrapper := Node3D.new()
	wrapper.name = id
	wrapper.set_script(load("res://scripts/content/imported_visual.gd"))
	wrapper.set("source", source)
	wrapper.set("artist_scale", Vector3.ONE * scale)
	wrapper.set("artist_offset", offset)
	wrapper.set("artist_rotation", holder.rotation_degrees)
	var packed := PackedScene.new()
	packed.pack(wrapper)
	var destination := "res://assets/grimtable/models/" + id + ".tscn"
	if FileAccess.file_exists(destination):
		holder.free(); wrapper.free(); fail("Output already exists; use a fresh ID to preserve authored scenes"); return
	var error := ResourceSaver.save(packed, destination)
	holder.free()
	wrapper.free()
	if error != OK: fail(error_string(error)); return
	print("Prepared visual: ", destination, " | source bounds: ", box, " | art scale: ", scale)
	quit()
