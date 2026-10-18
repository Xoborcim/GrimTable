class_name WorldState
extends RefCounted

static func capture(game: Node3D) -> Dictionary:
	var data := {"models": [], "terrain": [], "objectives": [], "turn": game.manager.snapshot(), "combat": game.combat.snapshot()}
	for unit: TableUnit in game.battlefield.units.get_children():
		for model in unit.models:
			data.models.append({"id": model.model_id, "position": ScenarioFactory.array(model.global_position), "wounds": model.wounds, "removed": model.removed})
	for piece: TerrainPiece in game.battlefield.terrain.get_children():
		data.terrain.append({"id": piece.object_id, "title": piece.title, "position": ScenarioFactory.array(piece.global_position), "rotation": rad_to_deg(piece.rotation.y), "blocks_movement": piece.blocks_movement, "blocks_los": piece.blocks_los})
	for objective: TableObjective in game.battlefield.objectives.get_children():
		data.objectives.append({"id": objective.object_id, "number": objective.number, "position": ScenarioFactory.array(objective.global_position)})
	return data

static func registry(game: Node3D) -> Dictionary:
	var result := {"combat": game.combat, "turn": game.manager}
	for unit: TableUnit in game.battlefield.units.get_children():
		for model in unit.models: result[model.model_id] = model
	for piece: TerrainPiece in game.battlefield.terrain.get_children(): result[piece.object_id] = piece
	for objective: TableObjective in game.battlefield.objectives.get_children(): result[objective.object_id] = objective
	return result

static func turn_error(value: Variant) -> String:
	if not value is Dictionary or not ScenarioDefinition.integer(value.get("round"), 1, 10000) or not ScenarioDefinition.integer(value.get("phase"), 0, 5) or not ScenarioDefinition.integer(value.get("team"), 0, 1) or not value.get("deployment") is bool: return "Invalid round/phase/player"
	var extra := assistance_state_error(value)
	if not extra.is_empty(): return extra
	if value.has("missions"):
		extra = MissionRules.error(value.missions)
		if not extra.is_empty(): return extra
	if value.has("scores"):
		if not value.scores is Dictionary: return "Invalid objective scores"
		for team in ["0", "1"]:
			if not ScenarioDefinition.integer(value.scores.get(team), 0, 10000000): return "Invalid objective score"
	if value.has("scored_rounds"):
		if not value.scored_rounds is Array or value.scored_rounds.size() > 10000: return "Invalid scored rounds"
		for round in value.scored_rounds:
			if not ScenarioDefinition.integer(round, 1, 10000): return "Invalid scored round"
	return ""

static func combat_error(value: Variant, scenario: Dictionary) -> String:
	if not value is Dictionary: return "Invalid combat state"
	if value.is_empty(): return ""
	if not AttackResolver.valid_result(value.get("result")) or not ScenarioDefinition.number(value.get("remaining"), 0, float(value.result.damage)) or not ScenarioDefinition.number(value.get("attack_id"), 1, 1000000): return "Invalid recorded attack/damage"
	for unit: Dictionary in scenario.armies:
		if unit.id == value.get("target"): return ""
	return "Unknown attack target unit"

static func validate(data: Dictionary, scenario: Dictionary) -> String:
	var error := turn_error(data.get("turn"))
	if not error.is_empty(): return error
	error = combat_error(data.get("combat", {}), scenario)
	if not error.is_empty(): return error
	var expected := {"models": {}, "terrain": {}, "objectives": {}}
	for unit: Dictionary in scenario.armies:
		var definition: Dictionary = ContentRegistry.unit(unit)
		for model: Dictionary in unit.models: expected.models[model.id] = int(definition.max_wounds)
	for key in ["terrain", "objectives"]:
		for item: Dictionary in scenario[key]: expected[key][item.id] = true
	for key in ["models", "terrain", "objectives"]:
		if not data.get(key) is Array or data[key].size() != expected[key].size(): return "Missing/extra saved objects in " + key
		var seen := {}
		for item in data[key]:
			if not item is Dictionary or not item.get("id") is String or not expected[key].has(item.id) or seen.has(item.id) or not ScenarioDefinition.on_board(item.get("position"), scenario.board): return "Invalid saved object in " + key
			seen[item.id] = true
			if key == "models" and (not ScenarioDefinition.integer(item.get("wounds"), 0, int(expected.models[item.id])) or not item.get("removed") is bool): return "Invalid saved health"
			if key == "terrain" and (not ScenarioDefinition.number(item.get("rotation"), -36000, 36000) or not item.get("blocks_los") is bool or not item.get("blocks_movement") is bool): return "Invalid saved terrain"
	return ""

static func apply(game: Node3D, data: Dictionary) -> void:
	var objects := registry(game)
	for key in ["models", "terrain", "objectives"]:
		for item: Dictionary in data[key]:
			var object: Node3D = objects[item.id]
			object.global_position = ScenarioFactory.vector(item.position)
			if object is Miniature:
				object.wounds = clampi(int(item.wounds), 0, object.max_wounds)
				object.removed = item.removed
				object.refresh()
			if object is TerrainPiece:
				object.rotation.y = deg_to_rad(float(item.rotation))
				object.blocks_movement = item.blocks_movement
				object.blocks_los = item.blocks_los
				object.collision_layer = 16 | (4 if object.blocks_los else 0)
	game.manager.restore(data.turn)
	game.combat.restore(data.get("combat", {}), game)
	game.battlefield.invalidate_spatial()

static func assistance_state_error(value: Dictionary) -> String:
	for key in ["charges", "ready_teams", "objective_owners", "cover_overrides"]:
		if not value.get(key, {}) is Dictionary or value.get(key, {}).size() > 200: return "Invalid assistance state: " + key
	for team in value.get("ready_teams", {}):
		if team not in ["0", "1"] or not value.ready_teams[team] is bool: return "Invalid readiness state"
	for key in ["objective_owners", "cover_overrides"]:
		for id in value.get(key, {}):
			if not ScenarioDefinition.valid_id(id) or not ScenarioDefinition.integer(value[key][id], -1 if key == "objective_owners" else 0, 1 if key == "objective_owners" else 3): return "Invalid referee correction"
	for id in value.get("charges", {}):
		var charge: Variant = value.charges[id]
		if not ScenarioDefinition.valid_id(id) or not charge is Dictionary: return "Invalid charge record"
		if not ScenarioDefinition.valid_id(charge.get("target")) or not ScenarioDefinition.integer(charge.get("round"), 1, 10000) or not ScenarioDefinition.integer(charge.get("team"), 0, 1) or not ScenarioDefinition.integer(charge.get("distance"), 0, 220) or not ScenarioDefinition.number(charge.get("required"), 0, 200): return "Invalid charge values"
		if not charge.get("rolls") is Array or charge.rolls.size() < 1 or charge.rolls.size() > 10: return "Invalid charge dice"
		for roll in charge.rolls:
			if not ScenarioDefinition.integer(roll, 1, 20): return "Invalid charge die"
	return ""
