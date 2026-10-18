class_name BattlePreset
extends RefCounted
const ROOT:="user://battle_presets/"

static func error(value: Variant) -> String:
	if not value is Dictionary or value.get("kind")!="grimtable_battle_preset" or value.get("version")!=1:return "Unsupported battle preset."
	for key in ["name","army_a","army_b","scenario"]:
		if not value.get(key) is String or value[key].is_empty() or value[key].length()>120:return "Invalid preset reference."
	for field in [["points",100,10000],["width",60,120],["depth",44,120],["opponent",0,2],["difficulty",0,2],["primary",0,2],["seed",0,2147483647]]:
		if not ScenarioDefinition.integer(value.get(field[0]),field[1],field[2]):return "Invalid preset setting: "+field[0]
	if not value.get("tactical") is bool:return "Invalid tactical setting."
	return ""

static func records() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not DirAccess.dir_exists_absolute(ROOT):return result
	for file in DirAccess.get_files_at(ROOT):
		var data:=WorkshopStore.read_json(ROOT+file)
		if error(data).is_empty():result.append(data)
	return result

static func save(value: Dictionary) -> String:
	var issue:=error(value)
	if not issue.is_empty():return issue
	return "Saved battle preset." if WorkshopStore.atomic_json(ROOT+value.name.sha256_text()+".json",value) else "Could not save preset."
