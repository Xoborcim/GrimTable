class_name ScenarioDefinition
extends RefCounted

const VERSION := 1

static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return number(value, minimum, maximum) and float(value) == int(value)

static func vector(value: Variant, count: int = 3) -> bool:
	if not value is Array or value.size() != count: return false
	for component in value:
		if not number(component, -1000, 1000): return false
	return true

static func valid_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 100: return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-": return false
	return true

static func profile_error(path: Variant) -> String:
	if not path is String or not path.begins_with("res://resources/units/") or not path.ends_with(".json") or ".." in path: return "Invalid unit resource path"
	if not FileAccess.file_exists(path): return "Missing unit resource: " + path
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return ContentRegistry.profile_error(value) if value is Dictionary else "Invalid unit definition"

static func validate(data: Variant) -> String:
	if not data is Dictionary: return "Scenario must contain a JSON object"
	if data.get("format_version") != VERSION: return "Unsupported scenario format version"
	if not ContentRegistry.content_id(data.get("id")) or not data.get("name") is String or data.name.strip_edges().is_empty(): return "Scenario ID/name missing or invalid"
	if not data.get("notes", "") is String: return "Scenario notes must be text"
	if not data.get("board") is Dictionary or not number(data.board.get("width"), 12, 120) or not number(data.board.get("depth"), 12, 120): return "Board dimensions must be 12–120 inches"
	if not data.board.get("theme", "industrial") in ["industrial", "desert", "alien", "ashfall", "cathedral", "toxic"]: return "Unknown board theme"
	if data.board.get("lighting","Dusk") not in ["Day","Dusk","Night"] or not number(data.board.get("atmosphere",.5),0,1): return "Invalid lighting or atmosphere preset"
	if data.board.get("clutter","Composed") not in ["None","Sparse","Composed","Dense"] or data.board.get("surround","Obsidian") not in ["Obsidian","Brass"] or data.board.get("weather","Theme") not in ["Theme","Clear","Dust","Vapor"]:return "Invalid environment appearance preset"
	if not data.board.get("environment_art",false) is bool:return "Invalid environment art flag"
	if data.board.get("surface_layout","Legacy") not in ["Legacy","Sanctum","Transport"]:return "Invalid location surface layout"
	if not data.get("rules", {}) is Dictionary: return "Rules must be an object"
	if not number(data.get("rules", {}).get("difficult_ground_penalty", 2), 0, 24): return "Invalid difficult ground penalty"
	var charge: Variant = data.get("rules", {}).get("charge", {})
	if not charge is Dictionary or not integer(charge.get("dice", 2), 1, 10) or not integer(charge.get("sides", 6), 2, 20) or not integer(charge.get("bonus", 0), -20, 20) or not number(charge.get("engagement_range", 1), .1, 6): return "Invalid charge rule configuration"
	if not number(data.get("coherency_distance", 2), 0, 24): return "Invalid coherency distance"
	var ids := {"combat": true, "turn": true}
	for key in ["terrain", "objectives", "armies", "deployment_zones"]:
		if not data.get(key) is Array or data[key].size() > 200: return "Missing or oversized collection: " + key
		for item in data[key]:
			if not item is Dictionary or not valid_id(item.get("id")) or ids.has(item.id): return "Missing or duplicate object ID in " + key
			ids[item.id] = true
			if key in ["terrain", "objectives"]:
				if not on_board(item.get("position"), data.board): return "Object position is outside the board: " + item.id
			if key == "terrain":
				if not number(item.get("movement_penalty", 0), 0, 24) or not item.get("difficult_ground", false) is bool: return "Invalid difficult terrain trait"
				if not integer(item.get("cover_bonus", 0), 0, 3): return "Invalid cover bonus"
				if not vector(item.get("size")): return "Invalid terrain size"
				for value in item.size:
					if not number(value, 0.1, 120): return "Terrain dimensions must be positive"
				if not item.get("footprint_parts",[]) is Array or item.get("footprint_parts",[]).size()>16:return "Invalid compound terrain footprint"
				for part in item.get("footprint_parts",[]):
					if not part is Dictionary or not vector(part.get("size")) or not vector(part.get("center")):return "Invalid compound terrain part"
					for axis in 3:
						if not number(part.size[axis],.1,120) or absf(float(part.center[axis]))+float(part.size[axis])*.5>float(item.size[axis])*.5+(.001 if axis!=1 else float(item.size[axis])*.5):return "Compound terrain part exceeds bounds"
					if float(part.center[1])-float(part.size[1])*.5<-.001:return "Compound terrain below ground"
				if not item.get("title") is String or not item.get("blocks_movement") is bool or not item.get("blocks_los") is bool or not number(item.get("rotation", 0), -36000, 36000): return "Invalid terrain properties"
				if item.get("art_style", "") not in MonumentalTerrain.STYLES: return "Invalid terrain art style"
				if item.get("kind", "box") not in ["box", "ruin"] or not item.get("tint", "#7a817c") is String or not Color.html_is_valid(item.get("tint", "#7a817c")): return "Invalid terrain kind/color"
			elif key == "objectives":
				if not number(item.get("number"), 1, 999) or not number(item.get("radius"), 0.1, 30) or not item.get("name") is String: return "Invalid objective properties"
			elif key == "deployment_zones":
				if item.get("shape") != "rectangle" or not integer(item.get("team"), 0, 1) or not item.get("name") is String or not vector(item.get("center"), 2) or not vector(item.get("size"), 2): return "Invalid rectangle deployment zone"
				for axis in 2:
					var extent := float(data.board.width if axis == 0 else data.board.depth)
					if float(item.size[axis]) <= 0 or absf(float(item.center[axis])) + float(item.size[axis]) / 2 > extent / 2 + 0.001: return "Deployment zone exceeds board"
			elif key == "armies":
				if not item.get("name") is String or not integer(item.get("team"), 0, 1) or not item.get("models") is Array or item.models.size() > 100: return "Invalid unit"
				var profile_path := ContentRegistry.path_for(str(item.get("unit_id", item.get("profile", ""))))
				if item.has("unit_id") and not item.get("profile_snapshot") is Dictionary and not ContentRegistry.catalog().units.has(ContentRegistry.resolve_id(str(item.unit_id))): return "Unknown scenario unit ID"
				var error := ContentRegistry.profile_error(item.profile_snapshot, true) if item.get("profile_snapshot") is Dictionary else (ContentRegistry.profile_error(ContentRegistry.unit(item)) if item.has("unit_id") else profile_error(profile_path))
				if not error.is_empty(): return error
				for model in item.models:
					if not model is Dictionary or not valid_id(model.get("id")) or ids.has(model.id) or not on_board(model.get("position"), data.board): return "Invalid or duplicate model"
					if not model.get("label", "") is String or not number(model.get("rotation", 0), -36000, 36000): return "Invalid model label/rotation"
					ids[model.id] = true
	if data.has("scoring"):
		if not data.scoring is Dictionary or not integer(data.scoring.get("objective_points_per_round", 0), 0, 100): return "Invalid scenario scoring"
	var state: Variant = data.get("starting_state")
	if not state is Dictionary or not integer(state.get("round"), 1, 10000) or not integer(state.get("phase"), 0, 5) or not integer(state.get("team"), 0, 1) or not state.get("deployment") is bool: return "Invalid starting round/phase/player"
	return ""

static func on_board(point: Variant, board: Dictionary) -> bool:
	return vector(point) and absf(float(point[0])) <= float(board.width) / 2 and absf(float(point[2])) <= float(board.depth) / 2 and is_zero_approx(float(point[1]))
