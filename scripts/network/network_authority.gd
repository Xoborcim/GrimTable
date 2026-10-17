class_name NetworkAuthority
extends RefCounted

static func unit(game: Node3D, id: String) -> TableUnit:
	for squad: TableUnit in game.battlefield.units.get_children():
		if str(squad.name) == id: return squad
	return null

static func validate_request(game: Node3D, message: Dictionary, team: int, committed: Dictionary) -> String:
	if not message.get("command") is String or not message.get("args") is Dictionary: return "Invalid action request"
	if not ScenarioDefinition.integer(message.get("sequence"), 0, 1000000) or int(message.sequence) != game.battle_log.sequence: return "Table changed. Try again after synchronization."
	var command: String = message.command
	var args: Dictionary = message.args
	if command in AssistanceService.COMMANDS: return AssistanceService.validate(game, command, args, team)
	if command == "action": return validate_action(game, args.get("record"), team, committed)
	if game.interaction.session != null or game.interaction.dragging != null or game.interaction.drag_object != null: return "Confirm or cancel movement first"
	if command == "dice": return "" if ScenarioDefinition.integer(args.get("count"), 1, 100) else "Invalid dice count"
	if command in ["start_game", "undo", "redo", "previous_phase", "next_round"]:
		return "" if team == 0 else "Only the host can perform this session action"
	if command == "next_phase": return "" if game.manager.active_team == team and not game.manager.deployment else "Only the active player can advance the phase"
	if command == "attack":
		if not args.get("attacker") is String or not args.get("target") is String: return "Invalid attack request"
		var attacker := unit(game, args.attacker)
		var target := unit(game, args.target)
		if attacker == null or target == null or attacker.team != team or target.team == team: return "You may only attack an opposing unit with your own unit"
		if not ScenarioDefinition.integer(args.get("weapon_index", 0), 0, attacker.weapon_profiles.size() - 1): return "Invalid equipped weapon"
		if game.manager.active_team != team or game.manager.deployment: return "Wait for your active turn"
		return ""
	if command in ["allocate", "remove_casualty"]:
		var model: Miniature = WorldState.registry(game).get(args.get("model", "")) as Miniature
		if model == null or model.team != team: return "Only the owning player may allocate damage or remove casualties"
		if command == "allocate" and not ScenarioDefinition.integer(args.get("amount"), 1, 10000): return "Invalid damage amount"
		return ""
	if command == "discard_damage":
		return "" if game.combat.current != null and game.combat.current.target.team == team else "Only the target owner may discard pending damage"
	return "Unsupported action request"

static func validate_action(game: Node3D, record: Variant, team: int, committed: Dictionary) -> String:
	if not record is Dictionary or not record.get("changes") is Array or record.changes.is_empty() or record.changes.size() > 100: return "Invalid action changes"
	if not record.get("kind") in ["move", "unit_move", "wounds", "remove"]: return "Action type is not allowed over the network"
	var objects := WorldState.registry(game)
	var baseline := {}
	for category in ["models", "terrain", "objectives"]:
		for item: Dictionary in committed[category]: baseline[item.id] = item
	var seen := {}
	var moving: Array[Miniature] = []
	var origins := {}
	var routes := {}
	for change in record.changes:
		if not change is Dictionary or not change.get("id") is String or not change.get("property") is String or not change.has("before") or not change.has("after"): return "Invalid action delta"
		var object: Node3D = objects.get(change.id) as Node3D
		if object == null or not baseline.has(change.id) or seen.has(change.id): return "Unknown or repeated entity"
		seen[change.id] = true
		var property: String = change.property
		if object is Miniature:
			if object.team != team: return "You do not own this model"
			if property == "global_position":
				if record.kind not in ["move", "unit_move"] or object.removed or object.wounds <= 0: return "Model cannot move"
				if not game.manager.deployment and game.manager.active_team != team: return "Wait for your active turn"
				if not ScenarioDefinition.on_board(change.after, game.scenario.board) or not ScenarioDefinition.vector(change.before): return "Invalid model position"
				if not ScenarioFactory.vector(change.before).is_equal_approx(ScenarioFactory.vector(baseline[change.id].position)): return "Stale movement origin"
				if absf(float(change.after[1])) > 0.001: return "Models must stay on the tabletop"
				moving.append(object)
				origins[object] = object.global_position
				var route: Variant = record.get("metadata", {}).get("paths", {}).get(change.id, [change.before, change.after]) if record.get("metadata", {}) is Dictionary and record.get("metadata", {}).get("paths", {}) is Dictionary else null
				if not route is Array or route.size() < 2 or route.size() > 128: return "Invalid movement route"
				for point in route:
					if not ScenarioDefinition.vector(point): return "Invalid movement waypoint"
				if not ScenarioFactory.vector(route[0]).is_equal_approx(ScenarioFactory.vector(change.before)) or not ScenarioFactory.vector(route.back()).is_equal_approx(ScenarioFactory.vector(change.after)): return "Movement route endpoints differ"
				routes[object] = route
			elif property == "wounds":
				if record.kind != "wounds" or not ScenarioDefinition.integer(change.after, 0, object.max_wounds) or change.before != object.wounds: return "Invalid wound adjustment"
			elif property == "removed":
				if record.kind != "remove" or change.after != true or change.before != object.removed or object.wounds != 0: return "Only defeated models can be removed online"
			else: return "Unsupported model property"
		elif object is TableObjective:
			if team != 0 or not game.manager.deployment or record.kind != "move" or property != "global_position" or not ScenarioDefinition.on_board(change.after, game.scenario.board): return "Only host may reposition objectives during deployment"
			if not ScenarioDefinition.vector(change.before) or not ScenarioFactory.vector(change.before).is_equal_approx(ScenarioFactory.vector(baseline[change.id].position)) or absf(float(change.after[1])) > 0.001: return "Invalid objective movement origin"
		else: return "Terrain editing is disabled during online games"
	if record.kind == "unit_move" and not moving.is_empty():
		for model in moving:
			if model.get_parent() != moving[0].get_parent(): return "Move one squad at a time."
	var charge_target := str(record.get("metadata", {}).get("charge_target", "")) if record.get("metadata", {}) is Dictionary else ""
	var allowance := -1.0
	if not charge_target.is_empty():
		if moving.is_empty() or game.manager.phase != 3: return "Choose a squad during the Charge phase."
		var squad := moving[0].get_parent() as TableUnit
		for model in moving:
			if model.get_parent() != squad: return "Charge one squad at a time."
		var grant := ChargeRules.grant(game, squad)
		if grant.is_empty() or grant.target != charge_target: return "Roll this squad's charge before moving."
		allowance = float(grant.distance)
	var error := ""
	# Validate the completed formation together, then restore every temporary position.
	for change: Dictionary in record.changes:
		if change.property == "global_position": objects[change.id].global_position = ScenarioFactory.vector(change.after)
	for model in moving:
		var destination := model.global_position
		if game.manager.deployment: error = game.deployment.placement_error(model, destination)
		else:
			var route: Array = routes[model]
			var distance := MovementService.path_cost(game.battlefield, model, route)
			if distance > (model.movement if allowance < 0 else allowance) + .001: error = "Not enough movement after terrain costs."; break
			for index in range(1, route.size()):
				var start := ScenarioFactory.vector(route[index - 1])
				var finish := ScenarioFactory.vector(route[index])
				if absf(start.y) > 0.001 or absf(finish.y) > 0.001: error = "Movement must stay on tabletop"; break
				error = MovementService.move_error(game.battlefield, model, start, finish, model.movement if allowance < 0 else allowance, model.get_parent() as TableUnit if record.kind == "unit_move" else null)
				if not error.is_empty(): break
		if error.is_empty() and not CoherencyService.is_unit_coherent(model.get_parent()): error = "UNIT OUT OF COHERENCY"
		if not error.is_empty(): break
	if error.is_empty() and not charge_target.is_empty():
		var target := unit(game, charge_target)
		if target == null or ChargeRules.required(moving[0].get_parent(), target, ChargeRules.reach(game)) > .001: error = "Finish the charge within engagement range of the chosen target."
	for model in origins: model.global_position = origins[model]
	for change: Dictionary in record.changes:
		if change.property == "global_position" and objects[change.id] is TableObjective: objects[change.id].global_position = ScenarioFactory.vector(baseline[change.id].position)
	return error

static func to_action(game: Node3D, record: Dictionary) -> GameAction:
	var changes: Array[Dictionary] = []
	var objects := WorldState.registry(game)
	for delta: Dictionary in record.changes:
		var object: Node3D = objects[delta.id]
		changes.append({"object": object, "id": delta.id, "property": delta.property, "before": object.get(delta.property), "after": ScenarioFactory.vector(delta.after) if delta.property == "global_position" else (int(delta.after) if delta.property == "wounds" else delta.after)})
	var details: Dictionary = record.get("metadata", {}).duplicate(true)
	for change in changes:
		if change.object is Miniature: details.unit = str(change.object.get_parent().name); break
	return GameAction.new("Online " + str(record.kind), str(record.kind), changes, details)
