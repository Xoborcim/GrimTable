class_name IndustrialDressing
extends RefCounted

static func add(piece: TerrainPiece, extent: Vector3, center: Vector3) -> void:
	var dark := Color("1c2b32")
	var panel := Color("44545b") if piece.object_id.hash() % 3 == 0 else Color("606969")
	var ochre := Color("a58a4b")
	if extent.y < .35:
		# Embedded service mat rather than an oversized white slab.
		for i in range(maxi(2,int(extent.x))):
			TableVisuals.box(piece,Vector3(.035,.018,extent.z*.85),center+Vector3(-extent.x*.45+i*extent.x*.9/maxi(1,int(extent.x)-1),extent.y/2+.015,0),dark)
		return
	TableVisuals.box(piece,Vector3(extent.x+.12,.18,extent.z+.12),center+Vector3(0,extent.y/2,0),dark)
	TableVisuals.box(piece,Vector3(extent.x+.14,.23,extent.z+.14),center-Vector3(0,extent.y/2-.12,0),dark)
	for side in [-1,1]:
		for end in [-1,1]:
			TableVisuals.box(piece,Vector3(.20,extent.y,.19),center+Vector3(end*(extent.x/2-.08),0,side*extent.z/2),dark)
		var columns := maxi(1,int(extent.x/1.7))
		for i in columns:
			var width := (extent.x-.5)/columns
			var x := -extent.x/2+.25+width*(i+.5)
			TableVisuals.box(piece,Vector3(width-.09,extent.y*.62,.075),center+Vector3(x,.08,side*(extent.z/2+.025)),panel)
			TableVisuals.box(piece,Vector3(width*.7,.025,.09),center+Vector3(x,extent.y*.18,side*(extent.z/2+.06)),dark)
		# Access door with inset panel, latch and warning strip.
		if extent.x > 3.5:
			var x := extent.x*.18
			TableVisuals.box(piece,Vector3(.85,extent.y*.7,.12),center+Vector3(x,-extent.y*.08,side*(extent.z/2+.10)),dark)
			TableVisuals.box(piece,Vector3(.65,extent.y*.57,.13),center+Vector3(x,-extent.y*.08,side*(extent.z/2+.12)),Color("586567"))
			TableVisuals.box(piece,Vector3(.06,.26,.15),center+Vector3(x+.22,-.05,side*(extent.z/2+.16)),ochre)
		for j in 5:
			TableVisuals.box(piece,Vector3(.5,.035,.1),center+Vector3(-extent.x*.26,-.18+j*.10,side*(extent.z/2+.10)),dark)
		var lamp := TableVisuals.box(piece,Vector3(.32,.055,.12),center+Vector3(extent.x*.32,extent.y*.32,side*(extent.z/2+.08)),Color("8bb5ae"))
		lamp.material_override = TableVisuals.material(Color("7ca79f"),true)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in 5:
			var stripe := TableVisuals.box(piece,Vector3(.09,.12,.03),center+Vector3(-extent.x/2+.32+i*.16,-extent.y/2+.34,side*(extent.z/2+.12)),ochre)
			stripe.rotation.z = .45
	# Roof service inset and transverse slats.
	if extent.z > 1:
		TableVisuals.box(piece,Vector3(extent.x*.42,.10,extent.z*.60),center+Vector3(-extent.x*.15,extent.y/2+.12,0),Color("303e45"))
		for i in 5: TableVisuals.box(piece,Vector3(.07,.05,extent.z*.48),center+Vector3(-extent.x*.3+i*extent.x*.075,extent.y/2+.19,0),Color("71807f"))

static func merge(piece: Node3D) -> void:
	var groups := {}
	for child in piece.get_children():
		if not child is MeshInstance3D: continue
		var mat: Material = child.material_override
		var key := str(mat.get_instance_id())
		if mat is StandardMaterial3D: key = mat.albedo_color.to_html()+str(mat.shading_mode)
		if not groups.has(key): groups[key] = {"builder":SurfaceTool.new(),"material":mat,"shadow":child.cast_shadow}
		for surface in child.mesh.get_surface_count(): groups[key].builder.append_from(child.mesh,surface,child.transform)
		piece.remove_child(child)
		child.free()
	for group: Dictionary in groups.values():
		group.builder.set_material(group.material)
		var mesh := MeshInstance3D.new()
		mesh.mesh = group.builder.commit()
		mesh.material_override = group.material
		mesh.cast_shadow = group.shadow
		piece.add_child(mesh)
