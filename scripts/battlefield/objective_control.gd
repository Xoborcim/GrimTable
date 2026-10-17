class_name ObjectiveControl
extends RefCounted

static func team_name(units: Array, team: int) -> String:
	var factions := {}
	for unit: TableUnit in units:
		if unit.team == team and unit.definition.has("faction"): factions[unit.definition.faction] = true
	if factions.size() == 1:
		var id: String = factions.keys()[0]
		return str(ContentRegistry.catalog().factions.get(id, {"name": id}).name).trim_prefix("The ")
	return "Team " + ("A" if team == 0 else "B")

# An objective is controlled by the unique team with the most living bases
# touching its control radius. Defeated/removed models never count. Ties are neutral.
static func evaluate(objective: TableObjective, units: Array) -> Dictionary:
	var counts := {"0": 0, "1": 0}
	for unit: TableUnit in units:
		for model in unit.living_models():
			var distance := MeasurementService.horizontal_distance(objective.global_position, model.global_position)
			if maxf(0, distance - model.base_radius) <= objective.radius + 0.001:
				counts[str(model.team)] += 1
	var owner := -1
	if counts["0"] > counts["1"]: owner = 0
	elif counts["1"] > counts["0"]: owner = 1
	var board := objective.get_parent().get_parent() as Battlefield
	if board != null:
		var manager: GameManager = board.get_parent().get("manager")
		if manager != null and manager.objective_owners.has(objective.object_id): owner = int(manager.objective_owners[objective.object_id])
	return {"counts": counts, "owner": owner}

static func scores(board: Battlefield, points: int) -> Dictionary:
	var result := {"0": 0, "1": 0}
	for objective: TableObjective in board.objectives.get_children():
		var control := evaluate(objective, board.units.get_children())
		if control.owner >= 0: result[str(control.owner)] += points
	return result
