class_name DeploymentManager
extends Node3D

var zones: Array[DeploymentZone] = []
var board: Battlefield
var manager: GameManager

func _ready() -> void:
	load_zones(board.scenario)
	manager.changed.connect(func(): visible = manager.deployment)

func load_zones(scenario: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	zones.clear()
	for data: Dictionary in scenario.deployment_zones:
		var zone := DeploymentZone.from_data(data)
		if zone == null: continue
		zones.append(zone)
		var color := Color("51a99e") if zone.team == 0 else Color("b57b51")
		TableVisuals.line(self, zone.outline(), color)
		# Fill is derived from the representation's outline, independent of shape.
		var points := zone.outline()
		var body := StaticBody3D.new()
		body.collision_layer = 32
		body.collision_mask = 0
		body.set_meta("zone_id", zone.zone_id)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3((zone as RectangleDeploymentZone).size.x, 0.06, (zone as RectangleDeploymentZone).size.y)
		collider.shape = shape
		body.position = Vector3((zone as RectangleDeploymentZone).center.x, 0.03, (zone as RectangleDeploymentZone).center.y)
		body.add_child(collider)
		add_child(body)
		var geometry := ImmediateMesh.new()
		var mat := TableVisuals.material(Color(color, 0.12), true)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
		for i in range(1, points.size() - 2):
			for point in [points[0], points[i], points[i + 1]]: geometry.surface_add_vertex(point)
		geometry.surface_end()
		var fill := MeshInstance3D.new()
		fill.mesh = geometry
		add_child(fill)
		TableVisuals.label(self, zone.display_name, (points[0] + points[2]) / 2 + Vector3(0, 0.1, 2 if zone.team == 0 else -2), color)
	for unit: TableUnit in get_tree().get_nodes_in_group("units"):
		unit.coherency_distance = float(scenario.get("coherency_distance", 2))
	visible = manager.deployment

func placement_error(model: Miniature, point: Vector3) -> String:
	var error := MovementService.placement_error(board, model, point)
	if not error.is_empty(): return error
	for zone in zones:
		if zone.team == model.team and zone.contains_base(point, model.base_radius): return ""
	return "Base must be inside its team's deployment zone"

func validation_error() -> String:
	for unit: TableUnit in get_tree().get_nodes_in_group("units"):
		for model in unit.living_models():
			var error := placement_error(model, model.global_position)
			if not error.is_empty(): return model.model_id + ": " + error
		if not CoherencyService.is_unit_coherent(unit): return unit.display_name + ": UNIT OUT OF COHERENCY"
	return ""
