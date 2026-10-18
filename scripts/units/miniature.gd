class_name Miniature
extends StaticBody3D

var profile: Dictionary = {}
var cosmetic_id := ""
var visual_root: Node3D
var los_origin: Marker3D
var status_indicator: MeshInstance3D
var attack_eligibility := -1
var model_id: String
var display_code := ""
var display_name := "Generic Trooper"
var team := 0
var base_radius := 0.63
var movement := 6.0
var wounds := 2
var max_wounds := 2
var selected := false
var target_candidate := false
var phase_ready := false
var target_hint := ""
var damage_recipient := false
var ready_ring: MeshInstance3D
var removed := false
var coherency_problem := false
var unit_name := ""
var weapon: Dictionary = {}
var selection_ring: MeshInstance3D
var base_mesh: MeshInstance3D
var caption: Label3D
var _was_selected := false
static var _state_materials: Dictionary = {}
var debug_ring: MeshInstance3D
var workshop_cosmetic: Dictionary={}

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("miniatures")
	var color := Color("48c9c1") if team == 0 else Color("ed9164")
	if ContentRegistry.catalog().factions.has(profile.get("faction", "")): color = Color(ContentRegistry.catalog().factions[profile.faction].color)
	var base := CylinderMesh.new()
	base.top_radius = base_radius * .91
	base.bottom_radius = base_radius
	base.height = .16
	base.radial_segments = 32
	base_mesh = TableVisuals.mesh(self, base, Vector3(0, .08, 0), Color("202a34"))
	TableVisuals.ring(self, base_radius * .96, color.darkened(.25), .08)
	TableVisuals.box(self, Vector3(base_radius * .5, .035, .09), Vector3(0, .19, -base_radius * .72), color.lightened(.15))
	var top := TableVisuals.cylinder(self, base_radius * 0.88, 0.04, Vector3(0, 0.18, 0), Color("42433a"))
	top.material_override = BakedMaterials.base()
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	visual_root.position.y = 0.2
	add_child(visual_root)
	var path: String = profile.get("preferred_scene", profile.get("model_scene", ""))
	var imported: Node3D = WorkshopAppearance.assigned(profile,cosmetic_id,str(get_parent().name))
	if imported!=null:workshop_cosmetic=imported.get_meta("workshop_data",{})
	if imported==null:imported=MiniatureLibrary.assigned(str(profile.get("id","")),cosmetic_id)
	var local_cosmetic := imported != null
	if local_cosmetic:
		top.material_override=BakedMaterials.base(str(imported.get_meta("base_style","Industrial")))
	if imported == null and profile.has("preferred_model"): imported = SafeModVisual.instantiate(str(profile.preferred_model))
	if imported == null: imported=AuthoredArt.miniature(profile)
	if not path.is_empty() and (not path.begins_with("res://assets/grimtable/models/") or ".." in path): path = ContentRegistry.fallback_path(str(profile.get("fallback_visual", "legion_trooper")))
	if imported == null and not path.is_empty() and ResourceLoader.exists(path):
		var resource := load(path) as PackedScene
		if resource != null: imported = resource.instantiate() as Node3D
	if imported == null and not profile.is_empty() and (profile.has("id") or profile.has("model_scene")):
		var fallback: String = profile.get("fallback_model_scene", ContentRegistry.fallback_path(str(profile.get("fallback_visual", "legion_trooper"))))
		if not fallback.begins_with("res://assets/grimtable/models/") or ".." in fallback: fallback = ContentRegistry.fallback_path("legion_trooper")
		var resource := load(fallback) as PackedScene if ResourceLoader.exists(fallback) else null
		if resource != null:
			push_warning("Missing preferred visual for " + str(profile.get("id", display_name)) + "; using GrimTable fallback")
			imported = resource.instantiate() as Node3D
	if imported != null:
		if imported.has_meta("authored_art") and workshop_cosmetic.is_empty():
			var ground:=AuthoredArt.instantiate(AuthoredArt.GROUND)
			if ground!=null:
				ground.name="ScenicBaseGround"
				ground.position.y=.21
				ground.scale=Vector3(base_radius/.63,1,base_radius/.63)
				add_child(ground)
		var variation := cosmetic_id.hash() & 0x7fffffff
		for property in imported.get_property_list():
			if property.name == "tint" and imported.get("tint") is Color:
				var original: Color = imported.get("tint")
				imported.set("tint", original.lightened(float(variation % 3) * 0.04))
		for property in imported.get_property_list():
			if property.name == "variation": imported.set("variation", variation % 3)
		visual_root.add_child(imported)
		visual_root.rotation.y = 0 if local_cosmetic else deg_to_rad(float(variation % 11 - 5))
		# Readable heroic proportions; picking/base/LOS remain profile-defined.
		var art_scale:=1.0 if imported.has_meta("authored_art") else 1.04+float(variation%3)*.02
		visual_root.scale = Vector3.ONE if local_cosmetic else Vector3.ONE * float(profile.get("visual_scale", 1)) * art_scale
	else:
		if not path.is_empty(): push_warning("Missing visual asset for " + str(profile.get("id", display_name)))
		TableVisuals.cylinder(self, 0.29, 1.1, Vector3(0, 0.75, 0), color)
		var head := SphereMesh.new()
		head.radius = 0.24
		head.height = 0.48
		TableVisuals.mesh(self, head, Vector3(0, 1.5, 0), color.lightened(0.2))
		TableVisuals.box(self, Vector3(0.75, 0.18, 0.22), Vector3(0.18, 1.02, -0.32), Color("26323c"))
		if team == 1:
			TableVisuals.box(self, Vector3(0.65, 0.2, 0.35), Vector3(0, 1.24, 0), color)
	if not workshop_cosmetic.is_empty():
		base_mesh.visible=false;top.visible=false
		var workshop_base:=Node3D.new();workshop_base.name="WorkshopBase";add_child(workshop_base)
		WorkshopAppearance.add_base(workshop_base,workshop_cosmetic,base_radius)
	los_origin = Marker3D.new()
	los_origin.name = "LOSOrigin"
	los_origin.position.y = float(profile.get("los_height", 1.35))
	add_child(los_origin)
	status_indicator = TableVisuals.ring(self, base_radius * 0.85, Color("ee9e55"), 0.24)
	status_indicator.name = "StatusIndicators"
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = base_radius
	shape.height = float(profile.get("gameplay_height", 1.9))
	collider.shape = shape
	collider.position.y = shape.height / 2.0
	collider.name = "Collision"
	add_child(collider)
	selection_ring = TableVisuals.ring(self, base_radius + 0.14, GrimTheme.PLAYER if team == 0 else GrimTheme.ENEMY, 0.23)
	ready_ring = TableVisuals.ring(self, base_radius * .98, Color("83c8e4") if team == 0 else Color("e9b783"), .20)
	# Team stripes supplement faction color; geometry is independent of the profile mesh.
	for i in (1 if team == 0 else 2):
		TableVisuals.box(self, Vector3(.11, .045, .22), Vector3((i - .5) * .18, .19, base_radius * .68), Color("83c8e4") if team == 0 else Color("e9b783"))
	debug_ring = TableVisuals.ring(self, base_radius, Color.WHITE, 0.2)
	debug_ring.visible = false
	caption = TableVisuals.label(self, code(), Vector3(0, float(profile.get("gameplay_height", 1.9)) + 0.2, 0), color)
	caption.font_size = 26
	caption.pixel_size = .012
	refresh()

func refresh() -> void:
	if removed and visible and is_inside_tree() and is_instance_valid(visual_root): casualty_effect()
	visible = not removed
	collision_layer = 0 if removed else 2
	if not is_instance_valid(selection_ring):
		return
	selection_ring.visible = selected or target_candidate or attack_eligibility >= 0 or damage_recipient
	ready_ring.visible = wounds > 0
	ready_ring.material_override = state_material((GrimTheme.PLAYER if team == 0 else GrimTheme.ENEMY).darkened(0 if phase_ready else .78))
	status_indicator.visible = wounds < max_wounds or coherency_problem
	status_indicator.material_override = state_material(GrimTheme.WARNING if wounds == 0 or coherency_problem else GrimTheme.ENEMY)
	selection_ring.material_override = state_material(GrimTheme.WARNING if coherency_problem else GrimTheme.PLAYER if team == 0 else GrimTheme.ENEMY)
	if attack_eligibility >= 0: selection_ring.material_override = state_material(GrimTheme.PLAYER if attack_eligibility == 1 else GrimTheme.INVALID)
	caption.visible = attack_eligibility >= 0 or damage_recipient or wounds == 0 or coherency_problem
	visual_root.scale.y = .65 if wounds == 0 else visual_root.scale.x
	if target_candidate: selection_ring.material_override = state_material(GrimTheme.ENEMY)
	if damage_recipient: selection_ring.material_override = state_material(GrimTheme.WARNING)
	caption.text = ("◇ " if target_candidate else "") + ("✓ " if attack_eligibility == 1 else "× " if attack_eligibility == 0 else "") + code() + (" · DOWN" if wounds == 0 else "")
	if damage_recipient: caption.text = "↓ " + code()
	elif wounds == 0: caption.text = "× " + code()
	caption.modulate = Color("ffdf92") if damage_recipient else Color("dce9ee")
	if selected and not _was_selected:
		var board := get_parent().get_parent().get_parent() as Battlefield
		var settings: AppSettings = board.get_parent().get("settings") if board != null else null
		if settings != null and not settings.reduce_motion:
			var pulse := create_tween()
			pulse.tween_property(selection_ring,"scale",Vector3(1.12,1,1.12),.10)
			pulse.tween_property(selection_ring,"scale",Vector3.ONE,.15)
	_was_selected = selected
	base_mesh.material_override = TableVisuals.material(Color("6c3b42") if wounds == 0 else Color("202a34"))

func eye() -> Vector3:
	return los_origin.global_position if is_instance_valid(los_origin) else global_position + Vector3.UP * float(profile.get("los_height", 1.35))

func cosmetic_muzzle() -> Vector3:
	var marker:=visual_root.find_child("ArtMuzzle",true,false) as Marker3D
	return marker.global_position if marker!=null else eye()

func code() -> String:
	return model_id if display_code.is_empty() else display_code

# A short cosmetic copy can animate while authoritative picking/state updates
# immediately. Mesh resources are reused; no scripted model hierarchy is cloned.
func casualty_effect() -> void:
	var board := get_parent().get_parent().get_parent() as Battlefield
	if board == null: return
	var settings: AppSettings = board.get_parent().get("settings")
	if settings != null and (settings.reduce_motion or not settings.particles): return
	var ghost := Node3D.new()
	board.visuals.add_child(ghost)
	ghost.global_position = global_position
	for source in visual_root.find_children("*", "MeshInstance3D", true, false):
		var copy := MeshInstance3D.new()
		copy.mesh = source.mesh
		copy.material_override = source.material_override
		for surface in source.mesh.get_surface_count():copy.set_surface_override_material(surface,source.get_surface_override_material(surface))
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = source.global_transform
	var animation := ghost.create_tween().set_parallel(true)
	animation.tween_property(ghost, "scale", Vector3.ONE * .05, .18)
	animation.tween_property(ghost, "rotation:z", .8, .18)
	animation.chain().tween_callback(ghost.queue_free)


static func state_material(color: Color) -> StandardMaterial3D:
	if not _state_materials.has(color): _state_materials[color] = TableVisuals.material(color,true)
	return _state_materials[color]
