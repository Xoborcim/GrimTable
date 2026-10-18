class_name WeaponUse
extends RefCounted

# Configured army battles use one weapon per model in each combat phase.
# Mixed squads may split distinct groups between different targets. Deriving
# expenditure from executed actions makes undo, replay and reload agree.
static var cache := {}

static func game_for(unit: TableUnit) -> Node:
	return unit.get_parent().get_parent().get_parent() if unit.is_inside_tree() else null

static func strict(unit: TableUnit) -> bool:
	var game := game_for(unit)
	return game != null and game.get("scenario") is Dictionary and game.scenario.get("strict_armies",false)

static func spent(unit: TableUnit) -> Dictionary:
	if not strict(unit): return {}
	var game := game_for(unit)
	var key := str(game.get_instance_id())+":"+str(game.battle_log.sequence)+":"+str(game.manager.round_number)+":"+str(game.manager.phase)
	if cache.has(key): return cache[key]
	var result := {}
	for event: Dictionary in game.battle_log.entries:
		if event.kind not in ["execute","undo","redo"] or event.payload.get("kind")!="resolve_attack": continue
		for change: Dictionary in event.payload.get("changes",[]):
			if change.get("property")!="current" or not change.get("after") is Dictionary: continue
			var attack: Dictionary = change.after.get("result",{})
			if int(attack.get("_round",0))!=game.manager.round_number or int(attack.get("_phase",-1))!=game.manager.phase: continue
			for id: String in attack.get("eligible_models",[]): result[id]=maxi(0,int(result.get(id,0))+(-1 if event.kind=="undo" else 1))
	if cache.size()>16: cache.clear()
	cache[key] = result
	return result

static func eligible(unit: TableUnit, model: Miniature, weapon: Dictionary) -> bool:
	if weapon.has("_equipped_models") and not weapon._equipped_models.has(model.model_id): return false
	if not strict(unit): return true
	var game := game_for(unit)
	if game.manager.deployment or game.manager.phase not in [2,4]: return false
	if (weapon.get("type","ranged")=="melee")!=(game.manager.phase==4): return false
	return int(spent(unit).get(model.model_id,0))==0
