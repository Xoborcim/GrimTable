class_name ArmyDeployment
extends RefCounted

static func rotate(game: Node, unit: TableUnit, degrees: float) -> String:
	if not game.manager.deployment:return "Formation rotation is available during deployment."
	if unit==null or unit.living_models().is_empty():return "Select a living squad from the roster."
	if game.network_session!=null and unit.team!=(0 if game.network_session.host else 1):return "Only rotate your own squad."
	var session:=SquadMoveSession.new(unit,game.battlefield,game.deployment)
	var center:=FormationPlanner.center(unit.living_models())
	for model: Miniature in unit.living_models():
		model.global_position=center+(model.global_position-center).rotated(Vector3.UP,deg_to_rad(degrees))
		session.paths[model]=[ScenarioFactory.array(session.origins[model]),ScenarioFactory.array(model.global_position)]
	var issue:=session.validation_error()
	if not issue.is_empty():session.cancel();return issue
	var action:=session.action();session.cancel()
	game.history.perform(action)
	return "Formation rotated. Undo restores the previous deployment."
