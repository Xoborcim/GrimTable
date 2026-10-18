class_name AttackOptions
extends RefCounted

static func groups(unit: TableUnit, target: TableUnit, world: World3D, phase: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var melee := phase == 4
	if phase not in [2, 4]:
		for weapon in unit.weapon_profiles:
			if weapon.get("type", "ranged") == "melee" and not AttackResolver.eligible_attackers(unit, target, world, weapon).is_empty(): melee = true; break
	for index in unit.weapon_profiles.size():
		var weapon: Dictionary = unit.weapon_profiles[index]
		if (weapon.get("type", "ranged") == "melee") != melee: continue
		var preview := AttackResolver.preview(unit, target, world, weapon)
		if preview.attacks > 0: result.append({"index": index, "weapon": weapon, "preview": preview})
	return result

static func save_required(target: TableUnit, weapon: Dictionary) -> int:
	var save := AttackResolver.modified_save_target(int(target.definition.get("save", 3)), int(weapon.get("ap", 0))) if weapon.get("ap_semantics", "legacy") == "penalty" else AttackResolver.save_target(int(target.definition.get("save", 3)), int(weapon.get("ap", 0)))
	return clampi(save - AttackResolver.cover_for(target), 2, 7)

static func explanation(unit: TableUnit, target: TableUnit, available: Array[Dictionary], world: World3D) -> String:
	var lines := PackedStringArray([unit.display_name + " → " + target.display_name])
	for group in available:
		var weapon: Dictionary = group.weapon
		var preview: Dictionary = group.preview
		var strength := AttackResolver.strength_against(weapon,target.definition)
		var defense := int(target.definition.get("defense", target.definition.get("toughness", 4)))
		var save := save_required(target, weapon)
		lines.append('%s ×%d\n%d attacks / %d of %d models\nHit %d+ · Wound %d+ · Save %s' % [weapon.name, preview.eligible, preview.attacks, preview.eligible, preview.living, weapon.hit, AttackResolver.wound_target(strength, defense), "impossible" if save > 6 else str(save) + "+"])
		lines.append("Why: Strength %d vs Defense %d; base save %d+, AP %d, cover %d." % [strength, defense, int(target.definition.get("save", 3)), int(weapon.get("ap", 0)), AttackResolver.cover_for(target)])
		for model in unit.living_models():
			if preview.eligible_models.has(model.model_id): continue
			if not WeaponUse.eligible(unit,model,weapon):
				lines.append(model.code()+": not equipped, already used, or unavailable in this phase.")
				continue
			var nearest := INF
			var obstacle := ""
			for enemy in target.living_models():
				nearest = minf(nearest, MeasurementService.distance_between_bases(model, enemy))
				var los := MeasurementService.line_of_sight(world, model, enemy)
				if not los.clear and los.obstacle != null: obstacle = str(los.obstacle.title)
			lines.append('%s: %.1f" — out of range' % [model.code(), nearest] if nearest > float(weapon.range) else "%s: blocked by %s" % [model.code(), obstacle if not obstacle.is_empty() else "terrain"])
	return "\n\n".join(lines)

static func suggested(current: AttackResolution) -> Miniature:
	if current == null or current.target == null: return null
	var models := current.target.living_models()
	models.sort_custom(func(a, b):
		if (a.wounds < a.max_wounds) != (b.wounds < b.max_wounds): return a.wounds < a.max_wounds
		return a.model_id < b.model_id)
	return models[0] if not models.is_empty() else null

static func summary(unit: TableUnit, target: TableUnit, available: Array[Dictionary]) -> String:
	var lines := PackedStringArray([unit.display_name + " → " + target.display_name])
	for group in available:
		var weapon: Dictionary = group.weapon
		var preview: Dictionary = group.preview
		var save := save_required(target, weapon)
		lines.append("%s ×%d · %d attacks\n%d of %d models can attack\nAccuracy %d+ · Damage roll %d+\nEnemy armor %s" % [weapon.name, preview.eligible, preview.attacks, preview.eligible, preview.living, int(weapon.hit), AttackResolver.wound_target(AttackResolver.strength_against(weapon,target.definition), int(target.definition.get("defense", target.definition.get("toughness", 4)))), "cannot stop this attack" if save > 6 else str(save) + "+"])
	var cover := AttackResolver.cover_for(target)
	if cover > 0: lines.append("COVER: save improves by %d" % cover)
	lines.append("Why? explains distance, visibility and armor.")
	return "\n\n".join(lines)
