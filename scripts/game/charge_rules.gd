class_name ChargeRules
extends RefCounted

static func required(attacker: TableUnit, target: TableUnit, reach: float = 1.0) -> float:
	var distance := INF
	for model in attacker.living_models():
		for enemy in target.living_models(): distance = minf(distance, MeasurementService.distance_between_bases(model, enemy))
	return maxf(0, distance - reach)

static func reach(game: Node3D) -> float:
	return float(game.scenario.get("rules", {}).get("charge", {}).get("engagement_range", 1.0))

static func grant(game: Node3D, unit: TableUnit) -> Dictionary:
	var value: Dictionary = game.manager.charges.get(str(unit.name), {})
	if int(value.get("round", 0)) != game.manager.round_number or int(value.get("team", -1)) != unit.team: return {}
	var state := PhaseAssistant.states(game.battle_log, game.manager.round_number, int(game.initial_scenario.starting_state.round), bool(game.initial_scenario.starting_state.deployment))
	if int(state.get(str(unit.name), {}).get("charged", 0)) > 0: return {}
	return value

static func error_for(game: Node3D, attacker: TableUnit, target: TableUnit, team: int) -> String:
	if attacker == null or target == null or attacker.team != team or target.team == team: return "Choose one of your squads and an enemy to charge."
	if game.manager.deployment or game.manager.active_team != team or game.manager.phase != 3: return "Charges are available during your Charge phase."
	if attacker.living_models().is_empty() or target.living_models().is_empty(): return "Defeated squads cannot charge or be charged."
	if game.combat.current != null and game.combat.current.remaining > 0: return "Allocate pending damage first."
	var rule: Dictionary = game.scenario.get("rules", {}).get("charge", {})
	var maximum := int(rule.get("dice", 2)) * int(rule.get("sides", 6)) + int(rule.get("bonus", 0))
	if required(attacker, target, reach(game)) > maximum + .001: return "That target is beyond the maximum charge distance."
	var existing: Dictionary = game.manager.charges.get(str(attacker.name), {})
	if int(existing.get("round", 0)) == game.manager.round_number: return "This squad already rolled a charge this round. You can resume its movement."
	return ""

static func roll(game: Node3D, attacker: TableUnit, target: TableUnit) -> Dictionary:
	var issue := error_for(game, attacker, target, attacker.team if attacker != null else -1)
	if not issue.is_empty(): return {"error": issue}
	var config: Dictionary = game.scenario.get("rules", {}).get("charge", {})
	var rolls: Array[int] = []
	for i in int(config.get("dice", 2)): rolls.append(game.dice.rng.randi_range(1, int(config.get("sides", 6))))
	var distance := int(config.get("bonus", 0))
	for value in rolls: distance += value
	distance = maxi(0, distance)
	var before: Dictionary = game.manager.snapshot()
	var value := {"target": str(target.name), "round": game.manager.round_number, "team": attacker.team, "rolls": rolls, "distance": distance, "required": snappedf(required(attacker, target, reach(game)), .001)}
	game.manager.charges[str(attacker.name)] = value
	game.manager.changed.emit()
	game.manager.transitioned.emit(before, game.manager.snapshot())
	return value

static func anchor(attacker: TableUnit, target: TableUnit, engagement: float) -> Vector3:
	var best := INF
	var delta := Vector3.ZERO
	for model in attacker.living_models():
		for enemy in target.living_models():
			var gap := MeasurementService.distance_between_bases(model, enemy)
			if gap < best:
				best = gap
				delta = enemy.global_position - model.global_position
	return FormationPlanner.center(attacker.living_models()) + delta.normalized() * maxf(0, best - engagement + .08)
