class_name SaveService
extends RefCounted

const PATH := "user://grimtable_save.json"

static func save_game(root: Node, manager: GameManager, log: BattleLog = null, combat: CombatController = null, path: String = PATH) -> String:
	var data := WorldState.capture(root)
	data["format_version"] = 2
	data["local_opponents"] = root.ai.snapshot() if root.get("ai") != null else {}
	if not data.local_opponents.is_empty(): data["local_dice"] = {"seed":str(root.dice.rng.seed),"state":str(root.dice.rng.state)}
	data["required_content"] = root.initial_scenario.get("required_content", [])
	data["replay_supported"] = root.replay_supported
	data["scenario_reference"] = {"id": root.scenario.id, "path": root.scenario_path}
	data["initial_scenario"] = root.initial_scenario.duplicate(true)
	data["battle_log"] = log.entries if log != null else []
	data["undo_redo"] = {"persisted": false, "reason": "Runtime command stacks reset on load; chronological events are retained."}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return "Save failed: " + error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(data, "\t", true, true))
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return "Save failed: " + error_string(write_error)
	var error := DirAccess.rename_absolute(path + ".tmp", path)
	return "Saved tabletop to " + path if error == OK else "Save failed: " + error_string(error)

static func load_game(root: Node, manager: GameManager, log: BattleLog = null, combat: CombatController = null, path: String = PATH) -> String:
	if not FileAccess.file_exists(path): return "No saved game found"
	var parsed := JsonStore.read(path)
	if parsed.has("error"): return "Load failed: " + str(parsed.error)
	if not parsed.data is Dictionary: return "Load failed: invalid JSON"
	var data: Dictionary = parsed.data
	if data.has("format_version"):
		if data.format_version != 2: return "Load failed: incompatible save format version"
		return _load_v2(root, data, log, combat)
	if data.get("version") != 1: return "Load failed: unsupported save version"
	# Validate every field before changing the current tabletop.
	if not data.get("models") is Array or not data.get("objectives") is Array or not data.get("terrain") is Array or not data.get("turn") is Dictionary:
		return "Load failed: incomplete save"
	for group in ["models", "objectives", "terrain"]:
		for item in data[group]:
			if not item is Dictionary or not _valid_position(item.get("position")): return "Load failed: invalid position"
			if group == "models" and (not item.get("id") is String or not _number(item.get("wounds")) or not item.get("removed") is bool): return "Load failed: invalid model"
			if group == "objectives" and not _number(item.get("number")): return "Load failed: invalid objective"
			if group == "terrain" and not item.get("title") is String: return "Load failed: invalid terrain"
	for field in ["round", "phase", "team"]:
		if not _number(data.turn.get(field)): return "Load failed: invalid turn"
	if data.turn.has("deployment") and not data.turn.deployment is bool: return "Load failed: invalid deployment state"
	if not data.get("battle_log", []) is Array: return "Load failed: invalid battle log"
	for entry in data.get("battle_log", []):
		if not entry is Dictionary or not _number(entry.get("sequence")) or not entry.get("kind") is String or not entry.get("payload") is Dictionary: return "Load failed: invalid log event"
		if entry.kind == "attack" and not AttackResolver.valid_result(entry.payload): return "Load failed: invalid attack log"
	var legacy_scenario := ScenarioLibrary.read(ScenarioLibrary.BUILTINS[0])
	if legacy_scenario.has("error"): return "Load failed: " + str(legacy_scenario.error)
	if not WorldState.combat_error(data.get("combat", {}), legacy_scenario.data).is_empty(): return "Load failed: invalid attack state"
	var allowed := {"models": {}, "terrain": {}, "objectives": {}}
	for unit: Dictionary in legacy_scenario.data.armies:
		for model: Dictionary in unit.models: allowed.models[model.id] = true
	for item: Dictionary in legacy_scenario.data.terrain: allowed.terrain[item.title] = true
	for item: Dictionary in legacy_scenario.data.objectives: allowed.objectives[int(item.number)] = true
	for key in ["models", "terrain", "objectives"]:
		var seen := {}
		if data[key].size() != allowed[key].size(): return "Load failed: legacy demo object count mismatch"
		for item: Dictionary in data[key]:
			var id: Variant = item.id if key == "models" else (item.title if key == "terrain" else int(item.number))
			if not allowed[key].has(id) or seen.has(id): return "Load failed: unknown/duplicate legacy object"
			seen[id] = true
	if JSON.stringify(root.initial_scenario) != JSON.stringify(legacy_scenario.data): root.apply_scenario(legacy_scenario.data)
	for model: Miniature in root.get_tree().get_nodes_in_group("miniatures"):
		for item: Dictionary in data.models:
			if item.id == model.model_id:
				model.position = _position(item.position)
				model.wounds = clampi(int(item.wounds), 0, model.max_wounds)
				model.removed = item.removed
				model.refresh()
	for objective: TableObjective in root.get_tree().get_nodes_in_group("objectives"):
		for item: Dictionary in data.objectives:
			if int(item.number) == objective.number: objective.position = _position(item.position)
	for piece: TerrainPiece in root.get_tree().get_nodes_in_group("terrain"):
		for item: Dictionary in data.terrain:
			if item.title == piece.title: piece.position = _position(item.position)
	manager.restore(data.turn)
	if log != null: log.restore(data.get("battle_log", []))
	if combat != null: combat.restore(data.get("combat", {}), root)
	root.replay_supported = false
	return "Loaded saved tabletop"

static func validate_document(data: Variant) -> String:
	if not data is Dictionary or data.get("format_version") != 2: return "Incompatible save format version"
	if not data.get("initial_scenario") is Dictionary: return "Invalid saved scenario"
	var missing := ModLoader.required_error(data.get("required_content", data.get("initial_scenario", {}).get("required_content", [])))
	if not missing.is_empty(): return missing
	var reference: Variant = data.get("scenario_reference", {})
	if not reference is Dictionary or not reference.get("path", "") is String: return "Invalid scenario reference"
	var path: String = reference.get("path", "")
	if not path.is_empty() and not path.begins_with("res://") and not path.begins_with("user://"): return "Scenario reference must use portable paths"
	if not AIController.valid_config(data.get("local_opponents", {})): return "Invalid local AI settings"
	if data.has("local_dice"):
		if not data.local_dice is Dictionary: return "Invalid saved dice state"
		for key in ["seed","state"]:
			if not data.local_dice.get(key) is String or data.local_dice[key].length()>21 or not data.local_dice[key].is_valid_int(): return "Invalid saved dice state"
	var error := ScenarioDefinition.validate(data.get("initial_scenario"))
	if not error.is_empty(): return "Invalid saved scenario: " + error
	error = WorldState.validate(data, data.initial_scenario)
	if not error.is_empty(): return error
	if not data.get("replay_supported", true) is bool: return "Invalid replay compatibility flag"
	if data.get("replay_supported", true): error = ActionCodec.validate(data.get("battle_log"), data.initial_scenario)
	else: error = validate_legacy_log(data.get("battle_log"))
	return error

static func validate_legacy_log(records: Variant) -> String:
	if not records is Array: return "Invalid legacy battle log"
	for record in records:
		if not record is Dictionary or not _number(record.get("sequence")) or not record.get("kind") is String or not record.get("payload") is Dictionary: return "Invalid legacy log record"
		if record.kind == "attack" and not AttackResolver.valid_result(record.payload): return "Invalid legacy attack"
		if record.kind in ["turn", "start_game"] and record.payload.has("after") and not WorldState.turn_error(record.payload.after).is_empty(): return "Invalid legacy turn"
	return ""

static func _load_v2(root: Node3D, data: Dictionary, log: BattleLog, combat: CombatController) -> String:
	var error := validate_document(data)
	if not error.is_empty(): return "Load failed: " + error
	root.interaction.cancel()
	root.selection.clear()
	if JSON.stringify(root.initial_scenario) != JSON.stringify(data.initial_scenario): root.apply_scenario(data.initial_scenario)
	root.initial_scenario = data.initial_scenario.duplicate(true)
	root.replay_supported = data.get("replay_supported", true)
	if data.get("scenario_reference") is Dictionary: root.scenario_path = str(data.scenario_reference.get("path", ""))
	WorldState.apply(root, data)
	if log != null: log.restore(data.battle_log)
	if combat != null: combat.restore(data.get("combat", {}), root)
	root.history.clear()
	if root.get("ai") != null:
		root.ai_config = data.get("local_opponents", {}).duplicate(true)
		root.ai.configure(root.ai_config)
	if data.has("local_dice"):
		root.dice.rng.seed = int(data.local_dice.seed)
		root.dice.rng.state = int(data.local_dice.state)
	return "Loaded saved tabletop"

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _valid_position(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for component in value:
		if not _number(component): return false
	return absf(float(value[0])) <= 30 and absf(float(value[2])) <= 22 and is_zero_approx(float(value[1]))

static func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _position(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
