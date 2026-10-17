class_name SquadMoveSession
extends RefCounted

var unit: TableUnit
var origins: Dictionary = {}
var spent: Dictionary = {}
var paths: Dictionary = {}
var board: Battlefield
var allowance := -1.0
var charge_target := ""
var deployment: DeploymentManager

func _init(squad: TableUnit, table: Battlefield, deploy: DeploymentManager) -> void:
	unit = squad
	board = table
	deployment = deploy
	for model in unit.living_models():
		origins[model] = model.global_position
		spent[model] = 0.0
		paths[model] = [ScenarioFactory.array(model.global_position)]

func preview_error(model: Miniature, start: Vector3, point: Vector3) -> String:
	if deployment != null and deployment.manager.deployment: return deployment.placement_error(model, point)
	var route: Array = paths[model].duplicate(true)
	if not ScenarioFactory.vector(route.back()).is_equal_approx(start): route.append(ScenarioFactory.array(start))
	route.append(ScenarioFactory.array(point))
	if MovementService.path_cost(board, model, route) > limit(model) + .001: return "This model has insufficient movement after terrain costs."
	return MovementService.move_error(board, model, start, point, limit(model))

func stage(model: Miniature, start: Vector3) -> void:
	paths[model].append(ScenarioFactory.array(model.global_position))
	spent[model] = MovementService.path_cost(board, model, paths[model])

func validation_error(override_coherency: bool = false) -> String:
	for model: Miniature in origins:
		var error := MovementService.placement_error(board, model, model.global_position)
		if deployment != null and deployment.manager.deployment: error = deployment.placement_error(model, model.global_position)
		elif maxf(float(spent[model]), route_cost(model)) > limit(model) + 0.001: error = "Exceeds movement allowance"
		if not error.is_empty(): return model.model_id + ": " + error
	if not override_coherency and not CoherencyService.is_unit_coherent(unit): return "UNIT OUT OF COHERENCY"
	if not charge_target.is_empty():
		var game := board.get_parent()
		var target := NetworkAuthority.unit(game, charge_target)
		if target == null or ChargeRules.required(unit, target, ChargeRules.reach(game)) > .001: return "Finish within engagement range of the chosen target."
	return ""

func cancel() -> void:
	for model: Miniature in origins:
		model.global_position = origins[model]
		model.refresh()

func action() -> GameAction:
	var changes: Array[Dictionary] = []
	for model: Miniature in origins:
		if not model.global_position.is_equal_approx(origins[model]):
			changes.append({"object": model, "id": model.model_id, "property": "global_position", "before": origins[model], "after": model.global_position})
	var routes := {}
	for model: Miniature in paths: routes[model.model_id] = paths[model].duplicate(true)
	return GameAction.new("Move " + unit.display_name, "unit_move", changes, {"unit": unit.name, "movement_spent": costs(), "paths": routes, "charge_target": charge_target})

func costs() -> Dictionary:
	var result := {}
	for model: Miniature in origins: result[model.model_id] = spent[model]
	return result

func limit(model: Miniature) -> float:
	return model.movement if allowance < 0 else allowance

func route_cost(model: Miniature) -> float:
	var route: Array = paths[model].duplicate(true)
	if not ScenarioFactory.vector(route.back()).is_equal_approx(model.global_position): route.append(ScenarioFactory.array(model.global_position))
	return MovementService.path_cost(board, model, route)
