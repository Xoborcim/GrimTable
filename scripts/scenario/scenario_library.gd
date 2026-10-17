class_name ScenarioLibrary
extends RefCounted

const DIRECTORY := "user://scenarios/"
const BUILTINS := ["res://resources/scenarios/demo.json", "res://resources/scenarios/empty.json", "res://resources/scenarios/legion_vs_swarm.json", "res://resources/scenarios/horde_vs_synthetics.json", "res://resources/scenarios/ashfall_station.json"]

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"error": "Scenario file not found: " + path}
	var cached := ContentRegistry.read_json(path)
	var parsed := {"data": cached} if not cached.is_empty() else JsonStore.read(path)
	if parsed.has("error"): return {"error": parsed.error, "path": path}
	var data: Variant = parsed.data
	var error := ScenarioDefinition.validate(data)
	if not error.is_empty(): return {"error": error, "path": path}
	return {"data": data, "path": path}

static func list_scenarios() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in BUILTINS: result.append(read(path))
	for path: String in ContentRegistry.catalog().scenarios.values():
		if path not in BUILTINS: result.append(read(path))
	if DirAccess.dir_exists_absolute(DIRECTORY):
		for file in DirAccess.get_files_at(DIRECTORY):
			if file.ends_with(".json"): result.append(read(DIRECTORY + file))
	return result

static func save(data: Dictionary, path: String) -> String:
	var error := ScenarioDefinition.validate(data)
	if not error.is_empty(): return "Scenario save failed: " + error
	if not path.begins_with(DIRECTORY) or ".." in path or not path.ends_with(".json"): return "Scenarios must be saved in user://scenarios/"
	var code := DirAccess.make_dir_recursive_absolute(DIRECTORY)
	if code != OK: return "Cannot create scenarios folder: " + error_string(code)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return "Cannot write scenario: " + error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(data, "\t", true, true))
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return "Scenario save failed: " + error_string(write_error)
	code = DirAccess.rename_absolute(path + ".tmp", path)
	return "Saved scenario: " + path if code == OK else "Scenario save failed: " + error_string(code)

static func new_id(prefix: String = "scenario") -> String:
	return prefix + "_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec())
