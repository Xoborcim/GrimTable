class_name TerrainPiece
extends StaticBody3D

@export var blocks_movement := true
@export var blocks_los := true
@export var size := Vector3(6, 3, 1)
@export var title := "Wall"
@export var tint := Color("7a817c")
var footprint_overlay: Node3D
var debug_shape: MeshInstance3D
var object_id := ""
var kind := "box"
var visual_scene := ""
var cover_bonus := 0
var movement_penalty := 0.0
static var surface_materials: Dictionary = {}

func _ready() -> void:
	add_to_group("terrain")
	collision_layer = (4 if blocks_los else 0) | 16
	collision_mask = 0
	var has_visual := not visual_scene.is_empty() and ResourceLoader.exists(visual_scene)
	if has_visual:
		var resource := load(visual_scene) as PackedScene
		if resource != null: add_child(resource.instantiate())
		else: has_visual = false
	footprint_overlay = Node3D.new()
	add_child(footprint_overlay)
	footprint_overlay.hide()
	for part in footprint():
		var part_size: Vector3 = part.size
		var center: Vector3 = part.center
		var boundary := PackedVector3Array()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
			boundary.append(Vector3(center.x + corner.x * part_size.x / 2, .17, center.z + corner.y * part_size.z / 2))
		TableVisuals.line(footprint_overlay, boundary, Color("d6b77e"))
		if not has_visual:
			var body := TableVisuals.box(self, part_size, center, tint)
			var key := tint.to_html() + ("metal" if blocks_los else "ground")
			if not surface_materials.has(key):
				var surface := ShaderMaterial.new()
				surface.shader = preload("res://assets/grimtable/materials/terrain.gdshader")
				surface.set_shader_parameter("paint", tint if blocks_los else tint.darkened(.4))
				surface.set_shader_parameter("metal", .4 if blocks_los else .0)
				surface_materials[key] = surface
			body.material_override = surface_materials[key]
			IndustrialDressing.add(self,part_size,center)
		var part_collider := CollisionShape3D.new()
		var part_shape := BoxShape3D.new()
		part_shape.size = part_size
		part_collider.shape = part_shape
		part_collider.position = center
		add_child(part_collider)
	TableVisuals.box(self, Vector3(size.x + 0.25, 0.12, size.z + 0.25), Vector3(0, 0.06, 0), tint.darkened(0.3))
	if size.y > .3:
		var pad := PlaneMesh.new()
		pad.size = Vector2(size.x+1.2,size.z+1.2)
		var contact := TableVisuals.mesh(self,pad,Vector3(0,.015,0),Color.WHITE)
		var shadow := ShaderMaterial.new()
		shadow.shader = preload("res://assets/grimtable/materials/contact.gdshader")
		contact.material_override = shadow
		contact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	IndustrialDressing.merge(self)
	debug_shape = TableVisuals.box(self, size + Vector3(0.05, 0.05, 0.05), Vector3(0, size.y / 2, 0), Color(1, 0.4, 0.2, 0.25))
	var mat := debug_shape.material_override as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_shape.visible = false

func overlaps_base(point: Vector3, radius: float) -> bool:
	var local := to_local(point)
	for part in footprint():
		var relative: Vector3 = local - part.center
		var extent: Vector3 = part.size / 2
		var nearest := Vector2(clampf(relative.x, -extent.x, extent.x), clampf(relative.z, -extent.z, extent.z))
		if Vector2(relative.x, relative.z).distance_to(nearest) < radius: return true
	return false

func footprint() -> Array[Dictionary]:
	if kind == "ruin":
		return [{"size": Vector3(size.x, size.y, 0.8), "center": Vector3(0, size.y / 2, -size.z / 2 + 0.4)}, {"size": Vector3(0.8, size.y, size.z), "center": Vector3(-size.x / 2 + 0.4, size.y / 2, 0)}]
	return [{"size": size, "center": Vector3(0, size.y / 2, 0)}]

func path_touches(start: Vector3, finish: Vector3, radius: float) -> bool:
	for part in footprint():
		var extent: Vector3 = part.size / 2
		var point: Vector3 = part.center
		var area := AABB(Vector3(point.x - extent.x - radius, -10, point.z - extent.z - radius), Vector3((extent.x + radius) * 2, 20, (extent.z + radius) * 2))
		if area.has_point(to_local(start)) or area.has_point(to_local(finish)) or area.intersects_segment(to_local(start), to_local(finish)) != null: return true
	return false
