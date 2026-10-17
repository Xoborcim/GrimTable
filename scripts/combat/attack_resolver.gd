class_name AttackResolver
extends RefCounted

static func wound_target(strength: int, toughness: int) -> int:
	if strength >= toughness * 2: return 2
	if strength > toughness: return 3
	if strength == toughness: return 4
	if strength * 2 <= toughness: return 6
	return 5

static func save_target(save: int, ap: int) -> int:
	return clampi(save - ap, 2, 7)

# New profiles use positive AP as a penalty. Keep the legacy signed helper for
# older saves/profiles so their recorded semantics remain compatible.
static func modified_save_target(save: int, armor_penetration: int) -> int:
	return clampi(save + maxi(0, armor_penetration), 2, 7)

static func preview(attacker: TableUnit, target: TableUnit, world: World3D, weapon: Dictionary) -> Dictionary:
	var eligible := eligible_attackers(attacker, target, world, weapon)
	var in_range := 0
	var ids: Array[String] = []
	for model in attacker.living_models():
		for enemy in target.living_models():
			if MeasurementService.distance_between_bases(model, enemy) <= float(weapon.get("range", 0)) + 0.001:
				in_range += 1
				break
	for model in eligible: ids.append(model.model_id)
	return {"eligible_models": ids, "living": attacker.living_models().size(), "in_range": in_range, "eligible": eligible.size(), "attacks": eligible.size() * int(weapon.get("attacks", 1))}

static func normalize_result(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	if result.has("cover_bonus"): result.cover_bonus = int(result.cover_bonus)
	for key in ["attacks", "hit_target", "hits", "wound_target", "wounds", "save_target", "failed_saves", "damage"]:
		result[key] = int(result[key])
	for key in ["attack_rolls", "hit_rolls", "wound_rolls", "save_rolls"]:
		var rolls: Array[int] = []
		for value in result.get(key, []): rolls.append(int(value))
		result[key] = rolls
	var ids: Array[String] = []
	for id in result.eligible_models: ids.append(str(id))
	result.eligible_models = ids
	return result

static func valid_result(value: Variant) -> bool:
	if not value is Dictionary: return false
	var result: Dictionary = value
	for key in ["attacks", "hit_target", "hits", "wound_target", "wounds", "save_target", "failed_saves", "damage"]:
		var number: Variant = result.get(key)
		if not (number is float or number is int): return false
		if not is_finite(float(number)) or float(number) < 0 or float(number) > 1000000 or float(number) != int(number): return false
	for key in ["hit_rolls", "wound_rolls", "save_rolls"]:
		if not result.get(key) is Array or result[key].size() > 10000: return false
		for roll in result[key]:
			if not (roll is float or roll is int) or float(roll) < 1 or float(roll) > 6 or float(roll) != int(roll): return false
	if not result.get("eligible_models") is Array: return false
	for id in result.eligible_models:
		if not id is String: return false
	for key in ["attacking_unit", "target_unit", "attacker_id", "target_id"]:
		if not result.get(key) is String: return false
	if not result.get("weapon") is Dictionary or not result.weapon.get("name") is String: return false
	return result.hit_rolls.size() == int(result.attacks) and result.wound_rolls.size() == int(result.hits) and result.save_rolls.size() == int(result.wounds)

static func eligible_attackers(attacker: TableUnit, target: TableUnit, world: World3D, weapon: Dictionary) -> Array[Miniature]:
	var result: Array[Miniature] = []
	if attacker == target or attacker.team == target.team: return result
	for model in attacker.living_models():
		for enemy in target.living_models():
			if MeasurementService.distance_between_bases(model, enemy) <= float(weapon.get("range", 0)) and MeasurementService.line_of_sight(world, model, enemy).clear:
				result.append(model)
				break
	return result

static func resolve(dice: DiceManager, attacker: TableUnit, target: TableUnit, world: World3D, weapon: Dictionary) -> Dictionary:
	var eligible := eligible_attackers(attacker, target, world, weapon)
	if eligible.is_empty(): return {"error": "No living attacker has range and clear LOS to a living target"}
	var attacks := clampi(eligible.size() * int(weapon.get("attacks", 1)), 0, 10000)
	var hit := clampi(int(weapon.get("hit", 3)), 2, 7)
	var wound := wound_target(maxi(1, int(weapon.get("strength", 4))), maxi(1, int(target.definition.get("defense", target.definition.get("toughness", 4)))))
	var save := save_target(int(target.definition.get("save", 3)), int(weapon.get("ap", 0)))
	if weapon.get("ap_semantics", "legacy") == "penalty": save = modified_save_target(int(target.definition.get("save", 3)), int(weapon.get("ap", 0)))
	var cover := cover_for(target)
	save = clampi(save - cover, 2, 7)
	var hit_rolls := dice.roll_d6(attacks)
	var hits := DiceManager.count_successes(hit_rolls, hit)
	var wound_rolls := dice.roll_d6(hits)
	var wounds := DiceManager.count_successes(wound_rolls, wound)
	var save_rolls := dice.roll_d6(wounds)
	var failed := wounds - DiceManager.count_successes(save_rolls, save)
	var ids: Array[String] = []
	for model in eligible: ids.append(model.model_id)
	return {"cover_bonus": cover, "attacking_unit": attacker.display_name, "attacker_id": str(attacker.name), "target_unit": target.display_name, "target_id": str(target.name), "target_profile": target.definition.duplicate(true), "weapon": weapon.duplicate(true), "eligible_models": ids, "attacks": attacks, "attack_rolls": hit_rolls.duplicate(), "hit_target": hit, "hit_rolls": hit_rolls, "hits": hits, "wound_target": wound, "wound_rolls": wound_rolls, "wounds": wounds, "save_target": save, "save_rolls": save_rolls, "failed_saves": failed, "damage": failed * maxi(0, int(weapon.get("damage", 1)))}

# Explicit scenario cover area: every living defender base must touch the area.
# A wall does not magically grant cover merely by blocking a ray.
static func cover_for(target: TableUnit) -> int:
	if target.living_models().is_empty() or not target.is_inside_tree(): return 0
	var board := target.get_parent().get_parent() as Battlefield
	var manager: GameManager = board.get_parent().get("manager") if board != null else null
	if manager != null and manager.cover_overrides.has(str(target.name)): return int(manager.cover_overrides[str(target.name)])
	var bonus := 0
	for piece: TerrainPiece in target.get_tree().get_nodes_in_group("terrain"):
		if piece.cover_bonus <= 0: continue
		var all_inside := true
		for model in target.living_models():
			if not piece.overlaps_base(model.global_position, model.base_radius): all_inside = false; break
		if all_inside: bonus = maxi(bonus, piece.cover_bonus)
	return bonus
