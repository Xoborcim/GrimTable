class_name MovementService
extends RefCounted

static func placement_error(board: Battlefield, model: Miniature, point: Vector3, ignore_unit: TableUnit = null) -> String:
	return point_error(board,model,point,ignore_unit,board.get_tree().get_nodes_in_group("miniatures"),board.get_tree().get_nodes_in_group("terrain"))

static func point_error(board: Battlefield, model: Miniature, point: Vector3, ignore_unit: TableUnit, neighbors: Array, terrain: Array) -> String:
	if not board.contains_base(point, model.base_radius):
		return "Base crosses board boundary"
	for other: Miniature in neighbors:
		if other.get_parent() != ignore_unit and other != model and not other.removed and MeasurementService.horizontal_distance(point, other.global_position) < model.base_radius + other.base_radius - 0.001:
			return "Base overlaps " + other.model_id
	for piece: TerrainPiece in terrain:
		if piece.blocks_movement and piece.overlaps_base(point, model.base_radius):
			return "Blocked by " + piece.title
	return ""

static func move_error(board: Battlefield, model: Miniature, origin: Vector3, point: Vector3, allowance: float = -1, ignore_unit: TableUnit = null) -> String:
	var distance := MeasurementService.horizontal_distance(origin, point)
	if path_cost(board, model, [ScenarioFactory.array(origin), ScenarioFactory.array(point)]) > (model.movement if allowance < 0 else allowance) + 0.001:
		return "Exceeds movement allowance"
	# Sample the swept base so a drag cannot jump through a wall or miniature.
	# Broad phase once per route, instead of querying the entire scene for each
	# 0.12-inch sample. Temporary formation positions remain authoritative.
	var neighbors: Array=[]
	for other: Miniature in board.get_tree().get_nodes_in_group("miniatures"):
		var margin:=model.base_radius+other.base_radius
		if other.get_parent()==ignore_unit or other==model or other.removed:continue
		if other.global_position.x<minf(origin.x,point.x)-margin or other.global_position.x>maxf(origin.x,point.x)+margin:continue
		if other.global_position.z<minf(origin.z,point.z)-margin or other.global_position.z>maxf(origin.z,point.z)+margin:continue
		neighbors.append(other)
	var terrain: Array=board.get_tree().get_nodes_in_group("terrain")
	var steps := maxi(1, ceili(distance / 0.12))
	for i in range(1, steps + 1):
		var error := point_error(board, model, origin.lerp(point, float(i) / steps), ignore_unit,neighbors,terrain)
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
