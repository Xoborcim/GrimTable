class_name ScenarioFactory
extends RefCounted

static func vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

static func array(point: Vector3) -> Array:
	return [point.x, point.y, point.z]

static func populate(board: Battlefield, data: Dictionary) -> void:
	for item: Dictionary in data.terrain: add_terrain(board, item)
	for item: Dictionary in data.objectives: add_objective(board, item)
	for item: Dictionary in data.armies: add_unit(board, item, float(data.get("coherency_distance", 2)))

static func add_terrain(board: Battlefield, item: Dictionary) -> TerrainPiece:
	var piece := preload("res://scenes/terrain/terrain_piece.tscn").instantiate() as TerrainPiece
	piece.object_id = item.id
	piece.name = item.id
	piece.title = item.title
	piece.kind = item.get("kind", "box")
	piece.cover_bonus = int(item.get("cover_bonus", 0))
	piece.movement_penalty = float(item.get("movement_penalty", board.scenario.get("rules", {}).get("difficult_ground_penalty", 2) if item.get("difficult_ground", false) else 0))
	piece.visual_scene = item.get("visual_scene", "")
	piece.size = vector(item.size)
	piece.position = vector(item.position)
	piece.rotation.y = deg_to_rad(float(item.get("rotation", 0)))
	piece.tint = Color(item.get("tint", "#7a817c"))
	piece.blocks_movement = item.blocks_movement
	piece.blocks_los = item.blocks_los
	board.terrain.add_child(piece)
	return piece

static func add_objective(board: Battlefield, item: Dictionary) -> TableObjective:
	var objective := preload("res://scenes/battlefield/objective.tscn").instantiate() as TableObjective
	objective.object_id = item.id
	objective.name = item.id
	objective.display_name = item.name
	objective.number = int(item.number)
	objective.radius = float(item.radius)
	objective.position = vector(item.position)
	board.objectives.add_child(objective)
	return objective

static func add_unit(board: Battlefield, item: Dictionary, coherency: float = 2) -> TableUnit:
	var squad := preload("res://scenes/units/unit.tscn").instantiate() as TableUnit
	squad.name = item.id
	squad.display_name = item.name
	squad.team = int(item.team)
	squad.definition_path = ContentRegistry.path_for(str(item.get("unit_id", item.get("profile", ""))))
	squad.definition = ContentRegistry.unit(item)
	squad.weapon_profiles = ContentRegistry.weapons(squad.definition)
	squad.coherency_distance = coherency
	board.units.add_child(squad)
	for model_data: Dictionary in item.models:
		var model := preload("res://scenes/units/miniature.tscn").instantiate() as Miniature
		model.model_id = model_data.id
		model.display_code = model_data.get("label", ("A" if squad.team == 0 else "B") + str(squad.models.size() + 1))
		model.name = model_data.id
		model.team = squad.team
		model.unit_name = squad.display_name
		model.display_name = squad.definition.name
		model.movement = float(squad.definition.movement)
		model.base_radius = ContentRegistry.base_radius(squad.definition)
		model.profile = squad.definition
		model.cosmetic_id = str(model_data.get("cosmetic_id", model.model_id))
		model.max_wounds = int(squad.definition.max_wounds)
		model.wounds = model.max_wounds
		model.weapon = squad.weapon_profiles[0]
		model.position = vector(model_data.position)
		model.rotation.y = deg_to_rad(float(model_data.get("rotation", 0)))
		squad.add_child(model)
		squad.models.append(model)
	return squad

static func capture(game: Node3D) -> Dictionary:
	var data: Dictionary = game.scenario.duplicate(true)
	data.board = {"width": game.battlefield.width, "depth": game.battlefield.depth, "theme": game.scenario.board.get("theme", "industrial")}
	data.terrain = []
	data.objectives = []
	data.armies = []
	data.deployment_zones = []
	for piece: TerrainPiece in game.battlefield.terrain.get_children():
		data.terrain.append({"id": piece.object_id, "title": piece.title, "kind": piece.kind, "visual_scene": piece.visual_scene, "size": array(piece.size), "position": array(piece.position), "rotation": rad_to_deg(piece.rotation.y), "tint": "#" + piece.tint.to_html(false), "movement_penalty": piece.movement_penalty, "cover_bonus": piece.cover_bonus, "blocks_movement": piece.blocks_movement, "blocks_los": piece.blocks_los})
	for objective: TableObjective in game.battlefield.objectives.get_children():
		data.objectives.append({"id": objective.object_id, "name": objective.display_name, "number": objective.number, "radius": objective.radius, "position": array(objective.position)})
	for unit: TableUnit in game.battlefield.units.get_children():
		var models: Array[Dictionary] = []
		for model in unit.models: models.append({"id": model.model_id, "label": model.code(), "position": array(model.global_position), "rotation": rad_to_deg(model.rotation.y), "cosmetic_id": model.cosmetic_id})
		var army := {"id": str(unit.name), "name": unit.display_name, "team": unit.team, "profile": unit.definition_path, "models": models}
		if unit.definition.has("id"): army["unit_id"] = unit.definition.id
		data.armies.append(army)
	for zone in game.deployment.zones:
		if zone is RectangleDeploymentZone:
			data.deployment_zones.append({"id": zone.zone_id, "name": zone.display_name, "team": zone.team, "shape": "rectangle", "center": [zone.center.x, zone.center.y], "size": [zone.size.x, zone.size.y]})
	return data
