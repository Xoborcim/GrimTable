class_name SquadMovePreview
extends Node3D

var session: SquadMoveSession
var labels: Dictionary = {}
var links: Node3D
var last_layout: Array = []
var radius_rings: Array[MeshInstance3D] = []
var compact := false
var failure: Node3D
var soft_area: MeshInstance3D

func _ready() -> void:
	links = Node3D.new()
	add_child(links)
	failure = Node3D.new()
	add_child(failure)
	for model: Miniature in session.origins:
		var origin: Vector3 = session.origins[model]
		var ring := TableVisuals.ring(self, model.movement, Color("60877d"), 0.1)
		radius_rings.append(ring)
		ring.position = origin
		ring.visible = not session.deployment.manager.deployment
		var marker := TableVisuals.ring(self, model.base_radius, Color("c5b577"), 0.15)
		marker.position = origin
		var ghost := TableVisuals.cylinder(self, model.base_radius * .85, .06, origin + Vector3.UP * .06, Color(.5, .7, .75, .16))
		var material := ghost.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		labels[model] = TableVisuals.label(self, "", origin + Vector3.UP * 2.7)
		labels[model].font_size = 28
		model.caption.visible = false
		# Share the existing decorative meshes with a translucent original-position ghost.
		var ghost_root := Node3D.new()
		add_child(ghost_root)
		ghost_root.global_position = origin
		var ghost_material := TableVisuals.material(Color(.45, .74, .83, .17), true)
		ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for source: MeshInstance3D in model.visual_root.find_children("*", "MeshInstance3D", true, false):
			var copy := MeshInstance3D.new()
			copy.mesh = source.mesh
			copy.material_override = ghost_material
			ghost_root.add_child(copy)
			copy.transform = model.global_transform.affine_inverse() * source.global_transform
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(_delta: float) -> void:
	var layout: Array = [session.deployment.manager.deployment]
	for model: Miniature in session.origins: layout.append([model.global_position, model.wounds, model.removed, session.spent[model]])
	if layout == last_layout: return
	last_layout = layout
	for child in links.get_children():
		links.remove_child(child)
		child.queue_free()
	var invalid := CoherencyService.get_incoherent_models(session.unit)
	var models := session.unit.living_models()
	for i in models.size():
		var model := models[i]
		model.coherency_problem = invalid.has(model)
		var origin: Vector3 = session.origins[model]
		if not origin.is_equal_approx(model.global_position):
			TableVisuals.line(links, PackedVector3Array([origin + Vector3.UP * .22, model.global_position + Vector3.UP * .22]), GrimTheme.PLAYER.darkened(.2))
		model.selection_ring.material_override = TableVisuals.material(Color("ff7474") if model.coherency_problem else GrimTheme.PLAYER, true)
		var label := labels.get(model) as Label3D
		if label != null:
			label.visible = not compact
			label.position = model.global_position + Vector3.UP * 2.7
			label.text = '%s\n%.1f" left%s' % [model.code(), maxf(0, session.limit(model) - float(session.spent[model])), "\n! COHERENCY" if model.coherency_problem else ""]
			if session.deployment.manager.deployment: label.text = model.code() + " DEPLOY" + (" ! COHERENCY" if model.coherency_problem else "")
		for j in range(i + 1, models.size()):
			if MeasurementService.distance_between_bases(model, models[j]) <= session.unit.coherency_distance + 0.001:
				TableVisuals.line(links, PackedVector3Array([model.global_position + Vector3.UP * 0.3, models[j].global_position + Vector3.UP * 0.3]), Color("7dd9af"))

func clear_highlights() -> void:
	for model: Miniature in session.origins:
		model.coherency_problem = false
		model.caption.visible = true
		model.refresh()

func set_compact() -> void:
	compact = true
	for item in radius_rings: item.hide()
	for item in labels.values(): item.hide()
	if not radius_rings.is_empty() and not session.deployment.manager.deployment:
		var model: Miniature = session.unit.living_models()[0]
		radius_rings[0].show()
		radius_rings[0].position = FormationPlanner.center(session.unit.living_models())
		radius_rings[0].scale = Vector3(session.limit(model) / model.movement, 1, session.limit(model) / model.movement)
		soft_area = TableVisuals.cylinder(self, session.limit(model), .015, FormationPlanner.center(session.unit.living_models()) + Vector3.UP * .04, Color(.22, .6, .73, .065))
		var material := soft_area.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		soft_area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func show_failure(result: Dictionary) -> void:
	for child in failure.get_children(): child.queue_free()
	if result.ok: return
	for point: Vector3 in result.get("ghosts", []):
		var marker := TableVisuals.ring(failure, .7, Color("ffce85"), .2)
		marker.position = point
		TableVisuals.label(failure, "× Can't fit", point + Vector3.UP * 1.7).font_size = 24
	for id in result.get("blockers", []):
		var piece := session.board.terrain.get_node_or_null(str(id)) as TerrainPiece
		if piece == null: continue
		var points := PackedVector3Array()
		for corner in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1), Vector2(-1,-1)]:
			points.append(piece.to_global(Vector3(corner.x * (piece.size.x / 2 + .2), .25, corner.y * (piece.size.z / 2 + .2))))
		TableVisuals.line(failure, points, Color("ffd18b"))
		TableVisuals.label(failure, "Blocked by " + piece.title, piece.global_position + Vector3.UP * (piece.size.y + .5)).font_size = 25
