class_name ArmyAgreement
extends RefCounted

static func rules_error(rules: Variant) -> String:
	if not rules is Dictionary:return "Missing battle agreement."
	if not ScenarioDefinition.integer(rules.get("points"),100,10000) or rules.get("primary") not in ["control","convergence","domination"] or not rules.get("tactical") is bool or not rules.get("homebrew") is bool:return "Invalid points, mission or homebrew policy."
	if not ScenarioDefinition.integer(rules.get("seed"),0,2147483647):return "Invalid mission seed."
	return ""

static func proposal_error(army: Variant, rules: Dictionary) -> String:
	var issue:=rules_error(rules)
	if not issue.is_empty():return issue
	var issues:=ArmyRoster.errors(army)
	if not issues.is_empty():return "\n".join(issues)
	if int(army.points_limit)!=int(rules.points):return "The selected army's points limit differs from the host's agreed budget. Choose a matching saved list."
	if not rules.homebrew and not ContentRegistry._builtin.factions.has(army.faction):return "The host has disabled homebrew factions."
	return ""

static func build(map: Dictionary, armies: Array, rules: Dictionary) -> Dictionary:
	for army in armies:
		var issue:=proposal_error(army,rules)
		if not issue.is_empty():return {"error":issue}
	var result:=ArmyRoster.scenario(map,armies,float(map.board.width),float(map.board.depth))
	if result.has("data"):
		result.data.starting_state["missions"]=MissionRules.initial(rules.primary,rules.tactical,int(rules.seed))
		result.data=ContentRegistry.freeze(result.data)
		result["agreement_hash"]=NetworkSession.state_hash({"scenario":result.data,"rules":rules})
	return result
