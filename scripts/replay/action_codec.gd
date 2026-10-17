class_name ActionCodec
extends RefCounted

static func validate(events: Variant, scenario: Dictionary) -> String:
	if not events is Array or events.size() > 100000: return "Invalid or oversized event history"
	var ids := {}
	var unit_ids := {}
	for unit: Dictionary in scenario.armies:
		unit_ids[unit.id] = true
		for model: Dictionary in unit.models: ids[model.id] = "model"
	for key in ["terrain", "objectives"]:
		for item: Dictionary in scenario[key]: ids[item.id] = key
	var sequence := 0
	var attacks := {}
	for event in events:
		if not event is Dictionary or not ScenarioDefinition.integer(event.get("sequence"), sequence + 1, 1000000) or not event.get("kind") is String or not event.get("payload") is Dictionary: return "Invalid event sequence/header"
		sequence = int(event.sequence)
		var data: Dictionary = event.payload
		if event.kind == "attack":
			if not AttackResolver.valid_result(data): return "Invalid attack log"
			if not unit_ids.has(data.attacker_id) or not unit_ids.has(data.target_id): return "Unknown attack unit"
			attacks["attack_" + str(sequence)] = true
		elif event.kind in ["turn", "start_game"]:
			if not WorldState.turn_error(data.get("before")).is_empty() or not WorldState.turn_error(data.get("after")).is_empty(): return "Invalid turn event"
		elif event.kind in ["execute", "undo", "redo"]:
			if not data.get("changes") is Array or not data.get("kind") is String or not data.get("title") is String or data.changes.size() > 1000: return "Invalid action record"
			for change in data.changes:
				if not change is Dictionary or not change.get("id") is String or not change.get("property") is String or not change.has("before") or not change.has("after"): return "Invalid action delta"
				var id: String = change.id
				var property: String = change.property
				for field in ["before", "after"]:
					var value: Variant = change[field]
					if property == "global_position":
						if not ids.has(id) or not ScenarioDefinition.on_board(value, scenario.board): return "Invalid move delta or unknown object"
					elif property in ["wounds", "removed"]:
						if ids.get(id) != "model" or (property == "wounds" and not ScenarioDefinition.number(value, 0, 10000)) or (property == "removed" and not value is bool): return "Invalid model delta"
					elif property == "current":
						if id != "combat": return "Unknown combat object"
						if value != null:
							if not WorldState.combat_error(value, scenario).is_empty(): return "Invalid attack-state delta"
							attacks["attack_" + str(int(value.attack_id))] = true
					elif property == "remaining":
						if not attacks.has(id) or not ScenarioDefinition.number(value, 0, 1000000): return "Invalid pending damage delta"
					else: return "Unsupported action property: " + property
		elif event.kind == "dice":
			if not data.get("values") is Array or data.values.size() > 100 or not ScenarioDefinition.integer(data.get("count"), 1, 100) or data.values.size() != int(data.count): return "Invalid dice event"
			var total := 0
			for value in data.values:
				if not ScenarioDefinition.integer(value, 1, 6): return "Invalid die face"
				total += int(value)
			if not ScenarioDefinition.integer(data.get("total"), total, total): return "Invalid dice total"
		else: return "Unsupported replay event: " + event.kind
	return ""

static func resolution(data: Dictionary, game: Node3D, resolutions: Dictionary) -> AttackResolution:
	var id := "attack_" + str(int(data.attack_id))
	var result: AttackResolution = resolutions.get(id)
	if result == null:
		result = AttackResolution.new()
		result.attack_id = int(data.attack_id)
		result.result = AttackResolver.normalize_result(data.result)
		for unit: TableUnit in game.battlefield.units.get_children():
			if str(unit.name) == data.target: result.target = unit
		resolutions[id] = result
	result.remaining = int(data.remaining)
	return result

static func apply(event: Dictionary, game: Node3D, resolutions: Dictionary) -> void:
	var payload: Dictionary = event.payload
	if event.kind == "dice":
		game.dice.history.push_front(payload.duplicate(true))
		if game.dice.history.size() > 8: game.dice.history.pop_back()
		game.dice.rolled.emit(payload)
	elif event.kind == "attack":
		resolution({"attack_id": event.sequence, "result": payload, "target": payload.target_id, "remaining": payload.damage}, game, resolutions)
	elif event.kind in ["turn", "start_game"]:
		game.manager.restore(payload.after)
	elif event.kind in ["execute", "undo", "redo"]:
		var objects := WorldState.registry(game)
		var field := "before" if event.kind == "undo" else "after"
		for change: Dictionary in payload.changes:
			var value: Variant = change[field]
			if change.property == "current":
				game.combat.current = null if value == null else resolution(value, game, resolutions)
			elif change.property == "remaining":
				var attack := resolutions.get(change.id) as AttackResolution
				if attack != null: attack.remaining = int(value)
			else:
				var object: Node3D = objects[change.id]
				object.set(change.property, ScenarioFactory.vector(value) if change.property == "global_position" else value)
				if object is Miniature: object.refresh()
		game.combat.changed.emit()
	game.battlefield.invalidate_spatial()
