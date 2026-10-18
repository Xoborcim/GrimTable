class_name PhaseAssistant
extends RefCounted

# Derived entirely from canonical records: old saves/replays need no migration,
# and undo/redo changes the assistance without introducing a second authority.
static func states(log: BattleLog, round_number: int, initial_round: int = 1, initial_deployment: bool = false) -> Dictionary:
	var result := {}
	var round_at_entry := initial_round
	var deploying := initial_deployment
	for event in log.entries:
		if event.kind in ["turn", "start_game"] and event.payload.get("before") is Dictionary:
			deploying = bool(event.payload.before.get("deployment", deploying))
			break
	for entry in log.entries:
		var payload: Dictionary = entry.payload
		if entry.kind in ["turn", "start_game"]:
			round_at_entry = int(payload.get("after", {}).get("round", round_at_entry))
			deploying = bool(payload.get("after", {}).get("deployment", deploying))
			for id in payload.get("after", {}).get("charges", {}):
				if int(payload.after.charges[id].round) == round_number:
					if not result.has(id): result[id] = {}
					result[id]["charge_rolled"] = 1
		if round_at_entry != round_number or entry.kind not in ["execute", "undo", "redo"]: continue
		var id := str(payload.get("actor", ""))
		var field := ""
		if payload.get("kind") in ["unit_move", "move"]: field = "deployed" if deploying else "charged" if not str(payload.get("metadata", {}).get("charge_target", "")).is_empty() else "moved"
		if payload.get("kind") == "resolve_attack":
			for change in payload.get("changes", []):
				if change.get("property") != "current" or not change.get("after") is Dictionary: continue
				var resolution: Dictionary = change.after.get("result", {})
				id = str(resolution.get("attacker_id", ""))
				field = "melee" if resolution.get("weapon", {}).get("type", "ranged") == "melee" else "ranged"
		if id.is_empty() or field.is_empty(): continue
		if not result.has(id): result[id] = {}
		result[id][field] = maxi(0, int(result[id].get(field, 0)) + (-1 if entry.kind == "undo" else 1))
	return result

static func pending(board: Battlefield, manager: GameManager, log: BattleLog) -> Array[TableUnit]:
	var found: Array[TableUnit] = []
	var state := states(log, manager.round_number, int(board.scenario.starting_state.round), bool(board.scenario.starting_state.deployment))
	var field := "charged" if manager.phase == 3 else "moved" if manager.phase == 1 else "melee" if manager.phase == 4 else "ranged"
	for unit: TableUnit in board.units.get_children():
		if unit.team != manager.active_team or unit.living_models().is_empty(): continue
		if int(state.get(str(unit.name), {}).get(field, 0)) > 0 and not (board.scenario.get("strict_armies",false) and manager.phase in [2,4]): continue
		if manager.phase == 3 and int(manager.charges.get(str(unit.name), {}).get("round", 0)) == manager.round_number: continue
		if manager.phase == 3:
			var rules: Dictionary = board.scenario.get("rules", {}).get("charge", {})
			var maximum := int(rules.get("dice", 2)) * int(rules.get("sides", 6)) + int(rules.get("bonus", 0))
			var possible := false
			for enemy: TableUnit in board.units.get_children():
				if enemy.team != unit.team and ChargeRules.required(unit, enemy, float(rules.get("engagement_range", 1))) <= maximum: possible = true; break
			if not possible: continue
		if manager.phase in [2, 4]:
			var available := false
			for weapon in unit.weapon_profiles:
				if (weapon.get("type", "ranged") == "melee") != (manager.phase == 4): continue
				for target: TableUnit in board.units.get_children():
					if not AttackResolver.eligible_attackers(unit, target, board.get_world_3d(), weapon).is_empty(): available = true; break
				if available: break
			if not available: continue
		found.append(unit)
	found.sort_custom(func(a: TableUnit, b: TableUnit): return str(a.name) < str(b.name))
	return found
