class_name ContentRegistry
extends RefCounted

# JSON IDs are the public API. Legacy path-based scenarios remain supported.
static var _catalog: Dictionary = {}
static var _builtin: Dictionary = {}
static var _definitions: Dictionary = {}

static func reload_content() -> void:
	_catalog = {}
	_definitions.clear()
	SafeModVisual.cache.clear()
	catalog()

static func read_json(path: String) -> Dictionary:
	if _definitions.has(path): return _definitions[path].duplicate(true)
	if not path.begins_with("res://resources/"): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return data if data is Dictionary else {}

static func resolve_id(id: String) -> String:
	return id.trim_prefix("grimtable:") if id.begins_with("grimtable:") else id

static func fallback_path(id: String) -> String:
	id = resolve_id(id)
	var profile := read_json(str(_builtin.get("units", {}).get(id, "res://resources/units/legion_trooper.json")))
	return str(profile.get("fallback_model_scene", profile.get("model_scene", "res://assets/grimtable/models/legion_trooper.tscn")))

static func required_for(data: Dictionary) -> Array[Dictionary]:
	var ids := {}
	var candidates: Array = [str(data.get("id", ""))]
	for army: Dictionary in data.get("armies", []): candidates.append(str(army.get("unit_id", "")))
	for id: String in candidates:
		if ":" in id and not id.begins_with("grimtable:"): ids[id.get_slice(":", 0)] = true
	var queue := ids.keys()
	while not queue.is_empty():
		var id: String = queue.pop_front()
		for dependency in ModLoader.loaded.get(id, {}).get("dependencies", []):
			if not ids.has(dependency):
				ids[dependency] = true
				queue.append(dependency)
	var result: Array[Dictionary] = []
	var sorted := ids.keys()
	sorted.sort()
	for id: String in sorted:
		if ModLoader.loaded.has(id): result.append({"id": id, "version": ModLoader.loaded[id].version})
	return result


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/content.json"))
		if parsed is Dictionary:
			_catalog = parsed
			_builtin = parsed.duplicate(true)
			ModLoader.load_all()
	return _catalog

static func path_for(id: String) -> String:
	return str(catalog().get("units", {}).get(resolve_id(id), id))

static func unit(item: Dictionary) -> Dictionary:
	if item.get("profile_snapshot") is Dictionary: return item.profile_snapshot.duplicate(true)
	var path := path_for(str(item.get("unit_id", item.get("profile", ""))))
	var value: Variant = read_json(path)
	return value if value is Dictionary else {}

static func weapons(profile: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if profile.get("weapon_snapshots") is Array:
		for weapon: Dictionary in profile.weapon_snapshots: result.append(weapon.duplicate(true))
		return result
	for id in profile.get("weapons", [profile.get("weapon", "")]):
		var path: String = catalog().get("weapons", {}).get(resolve_id(str(id)), id)
		if FileAccess.file_exists(path) or _definitions.has(path):
			var value: Variant = read_json(path)
			if value is Dictionary: result.append(value)
	return result

static func freeze(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	result["required_content"] = data.get("required_content", required_for(data)).duplicate(true)
	for army: Dictionary in result.armies:
		var profile := unit(army).duplicate(true)
		profile["weapon_snapshots"] = weapons(profile)
		army["profile_snapshot"] = profile
	return result

static func base_radius(profile: Dictionary) -> float:
	return float(profile.base_mm) / 25.4 / 2.0 if profile.has("base_mm") else float(profile.get("base_radius", 0.63))

static func profile_error(profile: Dictionary, snapshot: bool = false) -> String:
	if not profile.get("name") is String: return "Missing unit name"
	for field in ["model_scene", "preferred_scene", "preferred_model", "fallback_model_scene", "fallback_visual"]:
		if profile.has(field) and not profile[field] is String: return "Invalid visual reference: " + field
	for key in ["movement", "max_wounds"]:
		if not ScenarioDefinition.number(profile.get(key), 0.1, 100): return "Invalid unit stat: " + key
	if not ScenarioDefinition.integer(profile.max_wounds, 1, 100): return "Invalid maximum wounds"
	if profile.has("id"):
		if not ScenarioDefinition.integer(profile.get("defense"), 1, 100): return "Invalid defense"
		if not ScenarioDefinition.integer(profile.get("save"), 2, 7): return "Invalid save"
	if profile.has("base_mm"):
		if not ScenarioDefinition.number(profile.base_mm, 10, 200): return "Invalid base size"
	elif not ScenarioDefinition.number(profile.get("base_radius"), 0.1, 4): return "Invalid base size"
	for key in ["defense", "toughness", "save", "gameplay_height", "los_height", "visual_scale"]:
		if profile.has(key) and not ScenarioDefinition.number(profile[key], 0.01, 100): return "Invalid unit stat: " + key
	if not snapshot and profile.has("faction") and not catalog().get("factions", {}).has(profile.faction): return "Missing faction: " + str(profile.faction)
	if profile.has("roster"):
		var roster_issue := ArmyRoster.rules_error(profile.roster)
		if not roster_issue.is_empty():return roster_issue
	if profile.has("weapons"):
		if not profile.weapons is Array or profile.weapons.is_empty() or profile.weapons.size() > 32: return "Invalid equipped weapons"
		for id in profile.weapons:
			if not id is String: return "Invalid equipped weapon ID"
	elif not profile.get("weapon") is String: return "Invalid weapon reference"
	if profile.has("weapon_snapshots"):
		if not profile.weapon_snapshots is Array or profile.weapon_snapshots.size() > 32: return "Invalid weapon snapshots"
		for weapon in profile.weapon_snapshots:
			if not weapon is Dictionary: return "Invalid weapon snapshot"
	var loadout := weapons(profile)
	if loadout.is_empty() or loadout.size() != profile.get("weapons", [profile.get("weapon", "")]).size(): return "Missing weapon reference"
	for weapon in loadout:
		var error := weapon_error(weapon)
		if not error.is_empty(): return error
	return ""

static func weapon_error(weapon: Dictionary) -> String:
	if not weapon.get("name") is String: return "Missing weapon name"
	for key in ["range", "attacks", "hit", "strength", "damage"]:
		if not ScenarioDefinition.number(weapon.get(key), 0, 1000): return "Invalid weapon stat: " + key
	for key in ["attacks", "hit", "strength", "damage"]:
		if not ScenarioDefinition.integer(weapon.get(key), 1, 1000): return "Invalid integer weapon stat: " + key
	if not ScenarioDefinition.integer(weapon.get("hit"), 2, 7): return "Invalid hit threshold"
	if not ScenarioDefinition.number(weapon.get("ap", 0), -100, 100): return "Invalid AP"
	if weapon.get("ap_semantics", "legacy") == "penalty" and float(weapon.get("ap", 0)) < 0: return "AP penalty must be positive"
	if weapon.get("type", "ranged") not in ["ranged", "melee"]: return "Invalid weapon type"
	if not weapon.get("tags", []) is Array: return "Invalid weapon tags"
	return ""

static func validate() -> Array[String]:
	var errors: Array[String] = []
	var seen := {}
	for category in ["units", "weapons", "models", "scenarios", "factions"]:
		for id: String in catalog().get(category, {}):
			if seen.has(id): errors.append("Duplicate content ID: " + id)
			seen[id] = true
			if category == "units":
				var profile := unit({"unit_id": id})
				var error := profile_error(profile)
				if not error.is_empty(): errors.append(id + ": " + error)
				if profile.get("id") != id: errors.append("Mismatched unit ID: " + id)
				if not ResourceLoader.exists(str(profile.get("model_scene", ""))): errors.append("Missing unit model scene: " + id)
			elif category == "weapons":
				var value: Variant = read_json(catalog().weapons[id])
				if not value is Dictionary: errors.append("Invalid weapon: " + id)
				else:
					if value.get("id") != id: errors.append("Mismatched weapon ID: " + id)
					var error := weapon_error(value)
					if not error.is_empty(): errors.append(id + ": " + error)
			elif category == "models":
				if not ResourceLoader.exists(catalog().models[id]): errors.append("Missing model scene: " + id)
			elif category == "scenarios":
				var parsed := ScenarioLibrary.read(catalog().scenarios[id])
				if parsed.has("error"): errors.append(id + ": " + str(parsed.error))
			elif category == "factions":
				var faction: Variant = catalog().factions[id]
				if not faction is Dictionary or not faction.get("name") is String or not faction.get("color") is String or not Color.html_is_valid(str(faction.get("color", ""))): errors.append("Invalid faction palette/name: " + id)
	return errors

static func content_id(id: Variant) -> bool:
	if not id is String: return false
	var parts: PackedStringArray = id.split(":")
	if parts.size() > 2: return false
	for part in parts:
		if not ScenarioDefinition.valid_id(part): return false
	return true
