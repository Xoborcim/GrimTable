extends SceneTree

func _initialize() -> void: call_deferred("run")

func normalize_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var original: Material=node.material_override
		if original is ShaderMaterial:
			var material:=StandardMaterial3D.new()
			var paint: Variant=original.get_shader_parameter("paint")
			if paint is Color: material.albedo_color=paint
			var metal: Variant=original.get_shader_parameter("metal")
			if metal is float: material.metallic=metal
			material.roughness=.66
			node.material_override=material
	for child in node.get_children(): normalize_materials(child)

func run() -> void:
	for id in ["legion_trooper","legion_walker","swarm_hunter","ruined_basilica"]:
		var source: Node3D
		if id=="ruined_basilica":
			var piece:=TerrainPiece.new()
			piece.art_style="gothic"; piece.kind="ruin"; piece.size=Vector3(13,10,7); piece.object_id="basilica_nave"
			# Explicitly capture the 0.11 generator, bypassing the 0.12 cosmetic default.
			MonumentalTerrain.add(piece)
			source=Node3D.new()
			var geometry:=piece.get_node("MonumentalArchitecture")
			piece.remove_child(geometry); source.add_child(geometry); piece.free()
		else: source=load("res://assets/grimtable/models/"+id+".tscn").instantiate()
		root.add_child(source)
		normalize_materials(source)
		var document:=GLTFDocument.new()
		document.visibility_mode=GLTFDocument.VISIBILITY_MODE_EXCLUDE
		document.root_node_mode=GLTFDocument.ROOT_NODE_MODE_MULTI_ROOT
		var state:=GLTFState.new()
		var issue:=document.append_from_scene(source,state)
		if issue==OK: issue=document.write_to_filesystem(state,"res://art/reference/"+id+"_0110.glb")
		print("LEGACY ",id,": ",error_string(issue))
		source.free()
	quit()
