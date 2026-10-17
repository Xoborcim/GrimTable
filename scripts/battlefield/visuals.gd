class_name TableVisuals
extends RefCounted

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.position = pos
	item.material_override = material(color)
	parent.add_child(item)
	return item

static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	return mesh(parent, DioramaGeometry.box_mesh(size), pos, color)

static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	return mesh(parent, shape, pos, color)

static func line(parent: Node3D, points: PackedVector3Array, color: Color) -> MeshInstance3D:
	var geometry := ImmediateMesh.new()
	geometry.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material(color, true))
	for point in points:
		geometry.surface_add_vertex(point)
	geometry.surface_end()
	var item := MeshInstance3D.new()
	item.mesh = geometry
	parent.add_child(item)
	return item

static func ring(parent: Node3D, radius: float, color: Color, height: float = 0.08) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = maxf(0.01, radius - 0.035)
	shape.outer_radius = radius + 0.035
	shape.rings = 48
	shape.ring_segments = 6
	var item := mesh(parent, shape, Vector3(0, height, 0), color)
	item.material_override = material(color, true)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item

static func label(parent: Node3D, caption: String, pos: Vector3, color: Color = Color.WHITE) -> Label3D:
	var item := Label3D.new()
	item.text = caption
	item.position = pos
	item.font_size = 36
	item.outline_size = 7
	item.outline_modulate = Color("101821")
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.pixel_size = 0.018
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	item.modulate = color
	item.no_depth_test = true
	parent.add_child(item)
	return item
