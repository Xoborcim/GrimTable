class_name NetworkCompatibility
extends RefCounted

const PROTOCOL := 2
const GAME_VERSION := "0.13.3"
const SCENARIO_SCHEMA := 1
const ACTION_SCHEMA := 1

static func manifest() -> Dictionary:
	ContentRegistry.catalog()
	var profiles := {"content": FileAccess.get_sha256("res://resources/content.json")}
	for folder in ["res://resources/units", "res://resources/weapons"]:
		var names := DirAccess.get_files_at(folder)
		names.sort()
		for file in names:
			if file.ends_with(".json"): profiles[folder + "/" + file] = FileAccess.get_sha256(folder + "/" + file)
	return {"protocol": PROTOCOL, "game_version": GAME_VERSION, "scenario_schema": SCENARIO_SCHEMA, "action_schema": ACTION_SCHEMA, "profiles": profiles, "packs": ModLoader.compatibility()}

static func error_for(remote: Variant) -> String:
	if not remote is Dictionary: return "This GrimTable build is incompatible with the host: missing compatibility information."
	var local := manifest()
	if not remote.get("packs", []) is Array: return "Invalid content-pack compatibility information"
	var local_packs := {}
	for pack in local.packs: local_packs[pack.id] = pack
	var seen := {}
	for pack in remote.get("packs", []):
		if not pack is Dictionary or not pack.get("id") is String: return "Invalid content-pack entry"
		if seen.has(pack.id): return "Duplicate content pack in compatibility information"
		seen[pack.id] = true
		if not local_packs.has(pack.id): return "Missing content pack: " + str(pack.get("name", pack.id)) + " " + str(pack.get("version", "?"))
		if local_packs[pack.id].version != pack.get("version") or local_packs[pack.id].gameplay_hash != pack.get("gameplay_hash"): return "Content pack differs: " + pack.id
	if remote.get("packs", []).size() != local.packs.size(): return "Enabled content packs differ; enable the same packs on both clients"
	var incompatible := "This GrimTable build is incompatible with the host. Use matching game versions and unit/weapon profiles."
	for key in ["protocol", "scenario_schema", "action_schema"]:
		if not ScenarioDefinition.integer(remote.get(key), int(local[key]), int(local[key])): return incompatible
	if remote.get("game_version") != GAME_VERSION or not remote.get("profiles") is Dictionary or remote.profiles.size() != local.profiles.size(): return incompatible
	for path in local.profiles:
		if remote.profiles.get(path) != local.profiles[path]: return incompatible
	return ""
