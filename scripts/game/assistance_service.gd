class_name AssistanceService
extends RefCounted

const COMMANDS := ["charge", "auto_deploy", "ready", "referee", "remove_defeated", "end_turn"]

static func request(game: Node3D, command: String, args: Dictionary = {}) -> bool:
	if game.network_session != null and not game.network_session.applying:
		return game.network_session.request(command, args)
	var issue := validate(game, command, args, game.manager.active_team)
	if issue.is_empty(): issue = execute(game, command, args, game.manager.active_team)
	if not issue.is_empty(): game.hud.set_status(issue); return false
	return true

static func validate(game: Node3D, command: String, args: Dictionary, team: int) -> String:
	if command not in COMMANDS: return "Unknown assistance action."
	if game.replay_mode or game.editing: return "Return to a live battle to change the table."
	if game.interaction.session != null: return "Confirm or cancel the movement preview first."
	if command == "end_turn":
		if game.hud.combat_panel.batch_running: return "Finish the attack groups before ending your turn."
		if game.manager.deployment or game.manager.active_team != team: return "Only the active player may end their turn."
		if game.combat.current != null and game.combat.current.remaining > 0: return "Allocate pending damage before ending your turn."
		return ""
	if command == "charge":
		if not args.get("attacker") is String or not args.get("target") is String: return "Choose a squad and charge target."
		return ChargeRules.error_for(game, NetworkAuthority.unit(game, args.attacker), NetworkAuthority.unit(game, args.target), team)
	if command in ["auto_deploy", "ready"]:
		if not game.manager.deployment: return "Deployment is already complete."
		return ""
	if command == "remove_defeated":
		var target := NetworkAuthority.unit(game, str(args.get("unit", "")))
		if target == null or (game.network_session != null and target.team != team): return "Only the owning player may remove casualties."
		return ""
	if command == "referee":
		if game.network_session != null and team != 0: return "Only the host may use Manual Override."
		var action: String = str(args.get("field", ""))
		var value: Variant = args.get("value")
		if action == "score":
			return "" if ScenarioDefinition.integer(args.get("team"), 0, 1) and ScenarioDefinition.integer(value, 0, 10000000) else "Choose a valid score and team."
		if action == "phase": return "" if ScenarioDefinition.integer(value, 0, 5) else "Choose a valid phase."
		if action == "objective":
			if not ScenarioDefinition.valid_id(args.get("id")) or not game.battlefield.objectives.has_node(NodePath(str(args.id))): return "Select an existing objective."
			return "" if ScenarioDefinition.integer(value, -2, 1) else "Choose Automatic, Neutral, A or B."
		if action == "cover":
			return "" if NetworkAuthority.unit(game, str(args.get("id", ""))) != null and ScenarioDefinition.integer(value, -1, 3) else "Choose a valid squad and cover bonus."
		if action == "wounds":
			var model := WorldState.registry(game).get(str(args.get("id", ""))) as Miniature
			return "" if model != null and ScenarioDefinition.integer(value, 0, model.max_wounds) else "Choose a valid model and wound count."
		return "Unsupported referee correction."
	return ""

static func execute(game: Node3D, command: String, args: Dictionary, team: int) -> String:
	if command == "end_turn":
		var original_team: int = game.manager.active_team
		for step in 6:
			game.manager.next_phase()
			if game.manager.active_team != original_team: break
		return ""
	if command == "charge":
		var result := ChargeRules.roll(game, NetworkAuthority.unit(game, args.attacker), NetworkAuthority.unit(game, args.target))
		return str(result.get("error", ""))
	if command == "auto_deploy":
		var errors: Array[String] = []
		for unit: TableUnit in game.battlefield.units.get_children():
			if unit.team != team and game.network_session != null: continue
			if unit.living_models().is_empty(): continue
			var session := SquadMoveSession.new(unit, game.battlefield, game.deployment)
			var result := FormationPlanner.deploy(session)
			if not result.ok: session.cancel(); errors.append(unit.display_name + ": " + result.error); continue
			var action := session.action()
			if not action.changes.is_empty(): game.history.perform(action)
		game.battlefield.invalidate_spatial()
		return "\n".join(errors)
	if command == "ready":
		var teams: Array = [0, 1] if game.network_session == null else [team]
		for current in teams:
			var problem := deployment_problem(game, current)
			if not problem.is_empty(): return str(problem.error)
		var before: Dictionary = game.manager.snapshot()
		for current in teams: game.manager.ready_teams[str(current)] = true
		game.manager.changed.emit()
		game.manager.transitioned.emit(before, game.manager.snapshot())
		if game.manager.ready_teams.get("0", false) and game.manager.ready_teams.get("1", false):
			return "" if game.start_game() else "Check the deployment problems before starting."
		return ""
	if command == "remove_defeated":
		var target := NetworkAuthority.unit(game, args.unit)
		for model in target.models:
			if model.wounds == 0 and not model.removed: game.combat.remove_casualty(model)
		return ""
	if command == "referee":
		if args.field == "wounds":
			var model: Miniature = WorldState.registry(game)[args.id]
			game.history.perform(GameAction.new("Referee wound correction", "wounds", [{"object": model, "id": model.model_id, "property": "wounds", "before": model.wounds, "after": int(args.value)}]))
			return ""
		var before: Dictionary = game.manager.snapshot()
		match args.field:
			"score": game.manager.scores[str(int(args.team))] = int(args.value)
			"phase": game.manager.phase = int(args.value)
			"objective":
				if int(args.value) == -2: game.manager.objective_owners.erase(args.id)
				else: game.manager.objective_owners[args.id] = int(args.value)
			"cover":
				if int(args.value) == -1: game.manager.cover_overrides.erase(args.id)
				else: game.manager.cover_overrides[args.id] = int(args.value)
		game.manager.changed.emit()
		game.manager.transitioned.emit(before, game.manager.snapshot())
	return ""

static func deployment_problem(game: Node3D, team: int) -> Dictionary:
	for expected: Dictionary in game.initial_scenario.armies:
		if int(expected.team) != team: continue
		var unit := NetworkAuthority.unit(game, expected.id)
		if unit == null or unit.living_models().size() != expected.models.size(): return {"error": str(expected.name) + ": required models are missing or defeated.", "unit": str(expected.id)}
		for model in unit.living_models():
			var issue: String = game.deployment.placement_error(model, model.global_position)
			if not issue.is_empty(): return {"error": unit.display_name + ": " + issue, "model": model.model_id}
		if not CoherencyService.is_unit_coherent(unit): return {"error": unit.display_name + ": squad is out of coherency.", "model": unit.models[0].model_id}
	return {}
