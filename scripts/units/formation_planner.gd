class_name FormationPlanner
extends RefCounted

# Geometry only: keep the existing shape first, then try fixed compact layouts
# near the requested anchor. Never score cover, objectives or enemy positions.
static func center(models: Array) -> Vector3:
	var point := Vector3.ZERO
	for model in models: point += model.global_position
	return point / maxi(1, models.size())

static func propose(session: SquadMoveSession, anchor: Vector3, layout: String = "Auto", adjust: bool = true) -> Dictionary:
	var models := session.unit.living_models()
	if models.is_empty(): return {"ok": false, "error": "This squad has no models left."}
	models.sort_custom(func(a, b): return a.model_id < b.model_id)
	var origin_center := Vector3.ZERO
	var radius := 0.0
	for model in models:
		origin_center += session.origins[model]
		radius = maxf(radius, model.base_radius)
	origin_center /= models.size()
	var anchors: Array[Vector3] = [Vector3(anchor.x, 0, anchor.z)]
	if adjust:
		for distance in [.5, 1.0, 2.0, 3.0]:
			for angle in 8: anchors.append(anchor + Vector3(cos(angle * TAU / 8), 0, sin(angle * TAU / 8)) * distance)
	var layouts: Array = ["Preserve", "Cluster", "Line", "Two Rows"] if layout == "Auto" else [layout]
	var error := "No legal formation fits here. Try a nearby destination or Manual."
	var problem := models[0].model_id
	var first_failure: Array = []
	var first_error := ""
	var blockers: Array[String] = []
	for point in anchors:
		for shape in layouts:
			for rotation in ([0.0, PI / 6, -PI / 6, PI / 2] if adjust else [0.0]):
				var columns := models.size() if shape == "Line" else ceili(models.size() / 2.0) if shape == "Two Rows" else ceili(sqrt(models.size()))
				var rows := ceili(float(models.size()) / columns)
				for i in models.size():
					var model: Miniature = models[i]
					var offset: Vector3 = session.origins[model] - origin_center if shape == "Preserve" else Vector3((i % columns - (columns - 1) / 2.0) * (radius * 2 + .2), 0, (floori(float(i) / columns) - (rows - 1) / 2.0) * (radius * 2 + .2))
					model.global_position = point + offset.rotated(Vector3.UP, rotation)
					session.paths[model] = [ScenarioFactory.array(session.origins[model]), ScenarioFactory.array(model.global_position)]
					session.spent[model] = MovementService.path_cost(session.board, model, session.paths[model])
				error = session.validation_error()
				if error.is_empty():
					for model in models:
						if session.deployment != null and session.deployment.manager.deployment: continue
						error = MovementService.move_error(session.board, model, session.origins[model], model.global_position, session.limit(model), session.unit)
						if not error.is_empty(): problem = model.model_id; break
				if error.is_empty():
					session.board.invalidate_spatial()
					return {"ok": true, "anchor": point, "adjusted": not point.is_equal_approx(anchor) or rotation != 0 or shape != layouts[0], "layout": shape, "rotation": rotation}
				if first_failure.is_empty():
					first_error = error
					for model in models:
						first_failure.append(model.global_position)
						for piece: TerrainPiece in session.board.terrain.get_children():
							if piece.blocks_movement and piece.overlaps_base(model.global_position, model.base_radius) and not blockers.has(piece.object_id): blockers.append(piece.object_id)
				for model in models: model.global_position = session.origins[model]
	for model in models:
		model.global_position = session.origins[model]
		session.spent[model] = 0.0
		session.paths[model] = [ScenarioFactory.array(model.global_position)]
	return {"ok": false, "error": first_error if not first_error.is_empty() else error, "model": problem, "ghosts": first_failure, "blockers": blockers}

static func deploy(session: SquadMoveSession) -> Dictionary:
	for zone in session.deployment.zones:
		if not zone is RectangleDeploymentZone or zone.team != session.unit.team: continue
		for z in range(ceili(zone.center.y - zone.size.y / 2 + 1), floori(zone.center.y + zone.size.y / 2), 2):
			for x in range(ceili(zone.center.x - zone.size.x / 2 + 1), floori(zone.center.x + zone.size.x / 2), 2):
				var result := propose(session, Vector3(x, 0, z), "Auto", false)
				if result.ok: return result
	return {"ok": false, "error": "No legal formation fits this squad's deployment zone.", "model": session.unit.models[0].model_id}
