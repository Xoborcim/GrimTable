class_name CombatController
extends RefCounted

signal changed
signal message(text: String)
var dice: DiceManager
var history: ActionHistory
var log: BattleLog
var manager: GameManager
var interaction: InteractionController
var current: AttackResolution
var settings: AppSettings
var sandbox_override := false
var submit: Callable

func resolve(attacker: TableUnit, target: TableUnit, world: World3D, weapon_index: int = 0) -> bool:
	if submit.is_valid() and attacker != null and target != null and submit.call("attack", {"attacker": str(attacker.name), "target": str(target.name), "weapon_index": weapon_index}): return true
	if manager.deployment:
		message.emit("Start the battle before attacking")
		return false
	if interaction.session != null or interaction.dragging != null:
		message.emit("Confirm or cancel movement first")
		return false
	if current != null and current.remaining > 0:
		message.emit("Allocate or discard the pending damage first")
		return false
	if attacker == null or target == null or attacker.weapon_profiles.is_empty():
		message.emit("Select an attacking unit and an opposing target")
		return false
	if weapon_index < 0 or weapon_index >= attacker.weapon_profiles.size(): return false
	if not sandbox_override and attacker.team != manager.active_team:
		message.emit("Select a unit belonging to the active player (or enable offline sandbox override)")
		return false
	var result := AttackResolver.resolve(dice, attacker, target, world, attacker.weapon_profiles[weapon_index])
	if result.has("error"):
		message.emit(result.error)
		return false
	var resolution := AttackResolution.new()
	resolution.result = result
	resolution.target = target
	resolution.remaining = int(result.damage)
	resolution.attack_id = log.append("attack", result)
	var changes: Array[Dictionary] = [{"object": weakref(self), "id": "combat", "property": "current", "before": current, "after": resolution}]
	history.perform(GameAction.new("Resolve " + attacker.display_name + " attack", "resolve_attack", changes, {"attack_id": resolution.attack_id}))
	changed.emit()
	if settings != null and settings.auto_allocate_damage:
		while current.remaining > 0:
			var candidates := target.living_models()
			if candidates.is_empty(): break
			candidates.sort_custom(func(a: Miniature, b: Miniature):
				if (a.wounds < a.max_wounds) != (b.wounds < b.max_wounds): return a.wounds < a.max_wounds
				return a.model_id < b.model_id)
			if not allocate(candidates[0], mini(current.remaining, candidates[0].wounds)): break
	return true

func allocate(model: Miniature, amount: int) -> bool:
	if submit.is_valid() and model != null and submit.call("allocate", {"model": model.model_id, "amount": amount}): return true
	if current == null or current.remaining <= 0 or model == null or model.get_parent() != current.target or model.removed or model.wounds <= 0: return false
	if interaction.session != null or interaction.dragging != null:
		message.emit("Confirm or cancel movement before allocating damage")
		return false
	amount = mini(clampi(amount, 0, current.remaining), model.wounds)
	if amount == 0: return false
	var casualties: Array[String] = []
	if amount == model.wounds: casualties.append(model.model_id)
	var unused := current.remaining - amount if amount == model.wounds and current.target.living_models().size() == 1 else 0
	var properties: Array[Dictionary] = [
		{"object": model, "id": model.model_id, "property": "wounds", "before": model.wounds, "after": model.wounds - amount},
		{"object": current, "id": "attack_" + str(current.attack_id), "property": "remaining", "before": current.remaining, "after": current.remaining - amount - unused}]
	history.perform(GameAction.new("Allocate %d damage to %s" % [amount, model.model_id], "damage", properties, {"attack_id": current.attack_id, "damage": amount, "casualties": casualties, "overkill": unused}))
	changed.emit()
	if settings != null and settings.auto_remove_defeated and model.wounds == 0: remove_casualty(model)
	return true

func remove_casualty(model: Miniature) -> bool:
	if submit.is_valid() and model != null and submit.call("remove_casualty", {"model": model.model_id}): return true
	if model == null or model.wounds != 0 or model.removed: return false
	interaction.cancel()
	var changes: Array[Dictionary] = [{"object": model, "id": model.model_id, "property": "removed", "before": false, "after": true}]
	history.perform(GameAction.new("Remove casualty " + model.model_id, "remove", changes, {"casualties": [model.model_id]}))
	changed.emit()
	return true

func discard_pending() -> void:
	if submit.is_valid() and submit.call("discard_damage", {}): return
	if current == null or current.remaining <= 0: return
	var changes: Array[Dictionary] = [{"object": current, "id": "attack_" + str(current.attack_id), "property": "remaining", "before": current.remaining, "after": 0}]
	history.perform(GameAction.new("Discard unallocated damage", "discard_damage", changes, {"attack_id": current.attack_id}))
	changed.emit()

func reset() -> void:
	current = null
	changed.emit()

func snapshot() -> Dictionary:
	if current == null: return {}
	return current.snapshot()

static func valid_snapshot(data: Variant, root: Node) -> bool:
	if not data is Dictionary: return false
	if data.is_empty(): return true
	if not data.get("result") is Dictionary or not data.get("target") is String: return false
	if not SaveService._number(data.get("remaining")) or not SaveService._number(data.get("attack_id")): return false
	var result: Dictionary = data.result
	if not AttackResolver.valid_result(result): return false
	if int(data.remaining) < 0 or int(data.remaining) > int(result.damage): return false
	for unit: TableUnit in root.get_tree().get_nodes_in_group("units"):
		if str(unit.name) == data.target: return true
	return false

func restore(data: Dictionary, root: Node) -> void:
	current = null
	if not data.is_empty():
		current = AttackResolution.new()
		current.attack_id = int(data.attack_id)
		current.result = AttackResolver.normalize_result(data.result)
		current.remaining = int(data.remaining)
		for unit: TableUnit in root.get_tree().get_nodes_in_group("units"):
			if str(unit.name) == data.target: current.target = unit
	changed.emit()
