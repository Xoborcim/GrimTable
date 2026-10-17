class_name MovementService
extends RefCounted

static func placement_error(board: Battlefield, model: Miniature, point: Vector3, ignore_unit: TableUnit = null) -> String:
	if not board.contains_base(point, model.base_radius):
		return "Base crosses board boundary"
	for other: Miniature in board.get_tree().get_nodes_in_group("miniatures"):
		if other.get_parent() != ignore_unit and other != model and not other.removed and MeasurementService.horizontal_distance(point, other.global_position) < model.base_radius + other.base_radius - 0.001:
			return "Base overlaps " + other.model_id
	for piece: TerrainPiece in board.get_tree().get_nodes_in_group("terrain"):
		if piece.blocks_movement and piece.overlaps_base(point, model.base_radius):
			return "Blocked by " + piece.title
	return ""

static func move_error(board: Battlefield, model: Miniature, origin: Vector3, point: Vector3, allowance: float = -1, ignore_unit: TableUnit = null) -> String:
	var distance := MeasurementService.horizontal_distance(origin, point)
	if path_cost(board, model, [ScenarioFactory.array(origin), ScenarioFactory.array(point)]) > (model.movement if allowance < 0 else allowance) + 0.001:
		return "Exceeds movement allowance"
	# Sample the swept base so a drag cannot jump through a wall or miniature.
	var steps := maxi(1, ceili(distance / 0.12))
	for i in range(1, steps + 1):
		var error := placement_error(board, model, origin.lerp(point, float(i) / steps), ignore_unit)
		if not error.is_empty(): return error
	return ""

# A route pays the strongest touched area's flat penalty once, not once per
# waypoint. Sampling a drag into more waypoints can never multiply the penalty.
static func path_penalty(board: Battlefield, model: Miniature, route: Array) -> float:
	var penalty := 0.0
	for piece: TerrainPiece in board.terrain.get_children():
		if piece.movement_penalty <= penalty: continue
		for index in range(1, route.size()):
			if piece.path_touches(ScenarioFactory.vector(route[index - 1]), ScenarioFactory.vector(route[index]), model.base_radius): penalty = maxf(penalty, piece.movement_penalty); break
	return penalty

static func path_cost(board: Battlefield, model: Miniature, route: Array) -> float:
	var cost := 0.0
	for index in range(1, route.size()): cost += MeasurementService.horizontal_distance(ScenarioFactory.vector(route[index - 1]), ScenarioFactory.vector(route[index]))
	return cost + path_penalty(board, model, route)
