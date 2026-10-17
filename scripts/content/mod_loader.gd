class_name ModLoader
extends RefCounted

const VERSION := "0.10.0"
const ROOTS := ["user://mods", "res://mods"]
const SETTINGS := "user://mod_settings.cfg"
static var entries: Array[Dictionary] = []
static var loaded: Dictionary = {}
static var visual_roots: Dictionary = {}

static func enabled(id: String) -> bool:
	var settings := ConfigFile.new()
	settings.load(SETTINGS)
	return bool(settings.get_value("enabled", id, true))

static func set_enabled(id: String, value: bool) -> Error:
	if not ScenarioDefinition.valid_id(id) or id == "grimtable": return ERR_INVALID_PARAMETER
	var settings := ConfigFile.new()
	settings.load(SETTINGS)
	settings.set_value("enabled", id, value)
	return settings.save(SETTINGS)

static func version_number(value: String) -> int:
	var pattern := RegEx.create_from_string("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$")
	if pattern.search(value) == null: return -1
	var parts := value.split(".")
	return int(parts[0]) * 1000000 + int(parts[1]) * 1000 + int(parts[2])

static func supports(requirement: String) -> bool:
	if requirement.begins_with(">="): return version_number(requirement.substr(2)) >= 0 and version_number(VERSION) >= version_number(requirement.substr(2))
	return version_number(requirement) == version_number(VERSION)

# Only simple relative components are accepted. Every existing component is
# checked for links before opening files, including the mod's root directory.
static func safe_path(root: String, relative: Variant) -> String:
	if not relative is String or relative.is_empty() or relative.length() > 240 or "\\" in relative or ":" in relative or relative.begins_with("/"): return ""
	var current := root.trim_suffix("/")
	var root_dir := DirAccess.open(current.get_base_dir())
	if root_dir == null or root_dir.is_link(current.get_file()): return ""
	for component in relative.split("/"):
		if component in ["", ".", ".."] or component.ends_with(".") or component.ends_with(" "): return ""
		var stem: String = component.get_slice(".", 0).to_upper()
		if stem in ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"]: return ""
		for character in component:
			if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.- ": return ""
		var directory := DirAccess.open(current)
		if directory != null and directory.is_link(component): return ""
		current += "/" + component
	return current

static func read_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"error": "Missing file: " + path.get_file()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "Cannot open JSON: " + path.get_file()}
	if file.get_length() > 2000000: return {"error": "JSON exceeds 2 MB limit"}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK: return {"error": "Malformed JSON: " + path.get_file() + ": " + json.get_error_message()}
	if not json.data is Dictionary: return {"error": "Expected JSON object: " + path.get_file()}
	return {"data": json.data}

static func manifest_error(data: Dictionary) -> String:
	if not ScenarioDefinition.valid_id(data.get("id")) or data.id == "grimtable": return "Invalid or reserved pack ID"
	for key in ["name", "version", "grimtable_version", "author", "description"]:
		if not data.get(key) is String or data[key].is_empty() or data[key].length() > 2000: return "Manifest requires text: " + key
	if version_number(data.version) < 0: return "Invalid version; expected major.minor.patch"
	if not supports(data.grimtable_version): return "Unsupported GrimTable version requirement: " + data.grimtable_version
	for key in ["homepage", "license"]:
		if data.has(key) and (not data[key] is String or data[key].length() > 2000): return "Invalid manifest field: " + key
	if not data.get("dependencies", []) is Array or data.get("dependencies", []).size() > 32: return "Invalid dependencies"
	for dependency in data.get("dependencies", []):
		if not ScenarioDefinition.valid_id(dependency) or dependency == data.id: return "Invalid dependency ID"
	return ""

static func own_id(id: Variant, pack: String) -> bool:
	return id is String and id.begins_with(pack + ":") and ScenarioDefinition.valid_id(id.substr(pack.length() + 1))

static func allowed_reference(id: String, entry: Dictionary) -> bool:
	return ":" not in id or id.get_slice(":", 0) == entry.id or id.get_slice(":", 0) in entry.get("dependencies", [])

static func load_all() -> void:
	entries.clear()
	loaded.clear()
	visual_roots.clear()
	DirAccess.make_dir_recursive_absolute("user://mods")
	for root in ROOTS:
		var directory := DirAccess.open(root)
		if directory == null: continue
		var names := directory.get_directories()
		names.sort()
		for name in names:
			var path := safe_path(root, name + "/manifest.json")
			if path.is_empty():
				entries.append({"id": name, "name": name, "enabled": false, "error": "Unsafe pack path/link"}); continue
			var parsed := read_object(path)
			var entry: Dictionary = parsed.get("data", {}).duplicate(true)
			entry["root"] = root + "/" + name
			entry["error"] = parsed.get("error", manifest_error(entry) if not entry.is_empty() else "Missing manifest")
			entry["id"] = entry.get("id", name)
			entry["name"] = entry.get("name", name)
			entry["enabled"] = enabled(str(entry.id))
			entries.append(entry)
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.id) < str(b.id))
	var counts := {}
	for entry in entries: counts[str(entry.id)] = int(counts.get(str(entry.id), 0)) + 1
	var pending: Array[Dictionary] = []
	for entry in entries:
		if counts[str(entry.id)] > 1: entry.error = "Duplicate pack ID: " + str(entry.id)
		if entry.enabled and str(entry.error).is_empty(): pending.append(entry)
	while not pending.is_empty():
		var progress := false
		for entry in pending.duplicate():
			var ready := true
			for dependency in entry.get("dependencies", []):
				if not loaded.has(dependency): ready = false
			if not ready: continue
			entry.error = load_pack(entry)
			if str(entry.error).is_empty(): loaded[entry.id] = entry
			pending.erase(entry)
			progress = true
		if not progress:
			for entry in pending: entry.error = "Missing, disabled, failed or cyclic dependency: " + str(entry.get("dependencies", []))
			break

static func load_pack(entry: Dictionary) -> String:
	var previous := ContentRegistry._catalog.duplicate(true)
	var definitions := ContentRegistry._definitions.duplicate(true)
	var visuals := visual_roots.duplicate()
	var error := register_pack(entry)
	if not error.is_empty():
		ContentRegistry._catalog = previous
		ContentRegistry._definitions = definitions
		visual_roots = visuals
	return error

static func register_pack(entry: Dictionary) -> String:
	var records := {}
	var seen := {}
	for category in ["factions", "weapons", "units", "scenarios"]:
		records[category] = []
		var folder := safe_path(entry.root, category)
		if folder.is_empty(): return "Unsafe content folder: " + category
		var directory := DirAccess.open(folder)
		if directory == null: continue
		var files := directory.get_files()
		files.sort()
		if files.size() > 200: return "Too many definitions in " + category
		for name in files:
			if not name.ends_with(".json"): continue
			var path := safe_path(entry.root, category + "/" + name)
			if path.is_empty(): return "Unsafe filename/link: " + name
			var parsed := read_object(path)
			if parsed.has("error"): return parsed.error
			var data: Dictionary = parsed.data
			if not own_id(data.get("id"), entry.id): return "ID must use namespace " + str(entry.id) + ": " + str(data.get("id"))
			if seen.has(data.id): return "Duplicate content ID: " + data.id
			seen[data.id] = true
			if ContentRegistry.catalog()[category].has(data.id): return "Duplicate registered ID: " + data.id
			records[category].append({"path": path, "data": data})
	for record: Dictionary in records.factions:
		var faction: Dictionary = record.data
		if not faction.get("name") is String or not faction.get("color") is String or not Color.html_is_valid(faction.color): return "Invalid faction name/color"
		ContentRegistry._catalog.factions[faction.id] = faction
	for record: Dictionary in records.weapons:
		var weapon: Dictionary = record.data
		weapon["ap_semantics"] = "penalty"
		var error := ContentRegistry.weapon_error(weapon)
		if not error.is_empty(): return str(weapon.id) + ": " + error
		ContentRegistry._catalog.weapons[weapon.id] = record.path
		ContentRegistry._definitions[record.path] = weapon
	for record: Dictionary in records.units:
		var unit: Dictionary = record.data
		for key in unit:
			if key not in ["id", "name", "faction", "movement", "defense", "toughness", "save", "wounds", "max_wounds", "base_mm", "gameplay_height", "los_height", "visual_scale", "weapons", "fallback_visual", "visual"]: return "Unsupported unit field: " + str(key)
		if not unit.get("faction") is String or not unit.get("weapons") is Array: return "Missing faction/weapons"
		unit.faction = ContentRegistry.resolve_id(unit.faction)
		if not allowed_reference(unit.faction, entry): return "Undeclared faction dependency: " + unit.faction
		for i in unit.weapons.size():
			if not unit.weapons[i] is String: return "Invalid weapon reference"
			unit.weapons[i] = ContentRegistry.resolve_id(unit.weapons[i])
			if not allowed_reference(unit.weapons[i], entry): return "Undeclared weapon dependency: " + unit.weapons[i]
			if not ContentRegistry.catalog().weapons.has(unit.weapons[i]): return "Missing weapon reference \"%s\" in %s" % [unit.weapons[i], unit.id]
		unit["max_wounds"] = unit.get("max_wounds", unit.get("wounds"))
		var fallback: Variant = unit.get("fallback_visual", "legion_trooper")
		if not fallback is String or not ContentRegistry._builtin.units.has(ContentRegistry.resolve_id(fallback)): return "Unknown built-in fallback visual"
		unit["model_scene"] = ContentRegistry.fallback_path(fallback)
		unit["fallback_model_scene"] = unit.model_scene
		if unit.has("visual"):
			var path := safe_path(entry.root, unit.visual)
			if path.is_empty() or not path.ends_with(".glb"): return "Visual must be a safe pack-local .glb path"
			unit["preferred_model"] = path
			visual_roots[path] = entry.root
			if FileAccess.file_exists(path):
				var error := SafeModVisual.validate_glb(path)
				if not error.is_empty(): return error
		var error := ContentRegistry.profile_error(unit)
		if not error.is_empty(): return str(unit.id) + ": " + error
		ContentRegistry._catalog.units[unit.id] = record.path
		ContentRegistry._definitions[record.path] = unit
	for record: Dictionary in records.scenarios:
		var data: Dictionary = record.data
		data.erase("required_content")
		if not data.get("armies") is Array or not data.get("terrain") is Array: return "Invalid scenario collections"
		for terrain in data.terrain:
			if not terrain is Dictionary or terrain.has("visual_scene"): return "External terrain scenes are not supported"
		for army in data.armies:
			if not army is Dictionary or army.has("profile_snapshot") or army.has("profile") or not army.get("unit_id") is String: return "Mod armies require unit_id; external profiles/snapshots are forbidden"
			army.unit_id = ContentRegistry.resolve_id(army.unit_id)
			if not allowed_reference(army.unit_id, entry): return "Undeclared scenario dependency: " + army.unit_id
		var error := ScenarioDefinition.validate(data)
		if not error.is_empty(): return str(data.id) + ": " + error
		ContentRegistry._catalog.scenarios[data.id] = record.path
		ContentRegistry._definitions[record.path] = data
	return ""

static func compatibility() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids := loaded.keys()
	ids.sort()
	for id: String in ids:
		var gameplay := {}
		for category in ["units", "weapons"]:
			for key: String in ContentRegistry.catalog()[category]:
				if not key.begins_with(id + ":"): continue
				var profile := ContentRegistry.read_json(ContentRegistry.catalog()[category][key]).duplicate(true)
				for field in ["visual", "preferred_model", "model_scene", "fallback_model_scene", "fallback_visual", "visual_scale"]: profile.erase(field)
				gameplay[key] = profile
		result.append({"id": id, "name": loaded[id].name, "version": loaded[id].version, "gameplay_hash": JSON.stringify(gameplay, "", true, true).sha256_text()})
	return result

static func required_error(required: Variant) -> String:
	if not required is Array or required.size() > 128: return "Invalid required_content list"
	for pack in required:
		if not pack is Dictionary or not pack.get("id") is String or not pack.get("version") is String: return "Invalid required content entry"
		if not loaded.has(pack.id): return "Missing content pack: " + pack.id + " " + pack.version
		if loaded[pack.id].version != pack.version: return "Content pack version mismatch: " + pack.id + " requires " + pack.version
	return ""
