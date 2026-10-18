class_name ArmyRoster
extends RefCounted

# Canonical roster rules. Neither the editor nor AI may repair a list silently.
const VERSION := 1
const ROOT := "user://armies/"
const ROLES := ["Leader", "Infantry", "Specialist", "Heavy support", "Fast", "Vehicle", "Walker", "Creature"]

static func fresh(faction: String = "legion", limit: int = 500) -> Dictionary:
	return {"kind":"grimtable_army", "version":VERSION, "id":new_id(), "name":"New army", "faction":faction, "points_limit":limit, "homebrew":":" in faction, "units":[], "dependencies":[], "profiles":{}}

static func new_id() -> String:
	return "army_" + str(Time.get_unix_time_from_system()).replace(".", "_") + "_" + str(Time.get_ticks_usec())

static func profile(id: String) -> Dictionary:
	return ContentRegistry.unit({"unit_id":id}) if ContentRegistry.catalog().units.has(id) else {}

static func weapon(id: String) -> Dictionary:
	return ContentRegistry.read_json(str(ContentRegistry.catalog().weapons.get(id,"")))

static func rules_error(value: Variant) -> String:
	if not value is Dictionary: return "No army-building rules are defined for this profile."
	for field in [["points_per_model",1,10000],["base_points",0,10000],["min_size",1,100],["max_size",1,100],["max_units",1,100]]:
		if not ScenarioDefinition.integer(value.get(field[0]),field[1],field[2]): return "Invalid roster field: " + field[0]
	if value.min_size > value.max_size or value.get("role") not in ROLES: return "Invalid squad bounds or battlefield role."
	if not value.get("upgrades",[]) is Array or value.get("upgrades",[]).size()>16: return "Invalid equipment choices."
	var seen := {}
	for upgrade in value.get("upgrades",[]):
		if not upgrade is Dictionary or not upgrade.get("weapon") is String or not upgrade.get("replaces") is String: return "Invalid equipment choice."
		if seen.has(upgrade.weapon): return "Duplicate equipment choice."
		seen[upgrade.weapon] = true
		if not ScenarioDefinition.integer(upgrade.get("points"),0,10000) or not ScenarioDefinition.integer(upgrade.get("per_models"),1,100): return "Invalid equipment cost or allowance."
	return ""

static func entry(id: String) -> Dictionary:
	var p := profile(id)
	return {"id":"squad_"+str(Time.get_ticks_usec()),"unit_id":id,"name":str(p.get("name",id)),"count":int(p.get("roster",{}).get("min_size",1)),"upgrades":{},"cosmetic":""}

static func cost(item: Dictionary) -> int:
	var rules: Dictionary = profile(str(item.get("unit_id",""))).get("roster",{})
	var result := int(rules.get("base_points",0)) + int(item.get("count",0))*int(rules.get("points_per_model",0))
	for upgrade: Dictionary in rules.get("upgrades",[]): result += int(item.get("upgrades",{}).get(upgrade.weapon,0))*int(upgrade.points)
	return result

static func total(army: Dictionary) -> int:
	var result := 0
	for item: Dictionary in army.get("units",[]): result += cost(item)
	return result

static func schema_error(data: Variant) -> String:
	if not data is Dictionary or data.get("kind")!="grimtable_army" or data.get("version")!=VERSION: return "Unsupported army-list format."
	for field in ["id","name","faction"]:
		if not data.get(field) is String or data[field].is_empty() or data[field].length()>120: return "Invalid army " + field + "."
	if not data.id.is_valid_identifier() or not data.id.begins_with("army_"): return "Invalid army ID."
	if not ScenarioDefinition.integer(data.get("points_limit"),100,10000): return "Points limit must be 100–10,000."
	if not data.get("homebrew") is bool or not data.get("units") is Array or data.units.size()>100: return "Invalid army units."
	if not data.get("dependencies") is Array or data.dependencies.size()>32 or not data.get("profiles") is Dictionary or data.profiles.size()>100: return "Invalid content references."
	for dependency in data.dependencies:
		if not dependency is Dictionary or not dependency.get("id") is String or not dependency.get("version") is String: return "Invalid dependency."
	for key in data.profiles:
		if not key is String or not data.profiles[key] is String or data.profiles[key].length()!=64: return "Invalid profile fingerprint."
	var seen := {}
	for item in data.units:
		if not item is Dictionary: return "Invalid squad."
		for field in ["id","name","unit_id","cosmetic"]:
			if not item.get(field) is String or item[field].length()>120: return "Invalid squad " + field + "."
		if not ScenarioDefinition.valid_id(item.id) or seen.has(item.id): return "Squad IDs must be unique."
		seen[item.id] = true
		if not ScenarioDefinition.integer(item.get("count"),1,100) or not item.get("upgrades") is Dictionary or item.upgrades.size()>16: return "Invalid squad size or equipment."
		for key in item.upgrades:
			if not key is String or not ScenarioDefinition.integer(item.upgrades[key],0,100): return "Invalid equipment count."
		if not item.cosmetic.is_empty() and not WorkshopStore.valid_id(item.cosmetic) and not MiniatureLibrary.safe_id(item.cosmetic): return "Invalid cosmetic reference."
	return ""

static func fingerprint(id: String) -> String:
	var p := profile(id)
	for key in ["model_scene","fallback_model_scene","preferred_scene","preferred_model","visual","visual_scale","fallback_visual"]: p.erase(key)
	p["weapon_snapshots"] = ContentRegistry.weapons(p)
	for upgrade in p.get("roster",{}).get("upgrades",[]): p.weapon_snapshots.append(weapon(upgrade.weapon))
	# JSON key order is stable for definitions loaded from the same content pack.
	return JSON.stringify(p).sha256_text()

static func errors(data: Variant, check_fingerprints: bool = true) -> Array[String]:
	var result: Array[String] = []
	var issue := schema_error(data)
	if not issue.is_empty(): result.append(issue); return result
	if not ContentRegistry.catalog().factions.has(data.faction): result.append("Missing faction: "+data.faction+". Enable its content pack.")
	issue = ModLoader.required_error(data.dependencies)
	if not issue.is_empty(): result.append(issue)
	if data.units.is_empty(): result.append("Add at least one unit.")
	var models:=0
	for item in data.units:models+=int(item.count)
	if models>300:result.append("Supported limit: 300 models per army. Reduce squad sizes or select a more compact force.")
	var quantities := {}
	var leaders := 0
	for item: Dictionary in data.units:
		var p := profile(item.unit_id)
		if p.is_empty(): result.append(item.name+": missing profile "+item.unit_id+". Restore the content pack or choose a replacement explicitly."); continue
		var rules: Dictionary = p.get("roster",{})
		issue = rules_error(rules)
		if not issue.is_empty(): result.append(item.name+": "+issue); continue
		if p.get("faction")!=data.faction: result.append(item.name+": belongs to a different faction.")
		if item.count<rules.min_size or item.count>rules.max_size: result.append(item.name+": choose "+str(rules.min_size)+"–"+str(rules.max_size)+" models.")
		quantities[item.unit_id] = int(quantities.get(item.unit_id,0))+1
		if quantities[item.unit_id]>rules.max_units: result.append(item.name+": maximum "+str(rules.max_units)+" squads of this profile.")
		if rules.role=="Leader": leaders+=1
		var replacements := {}
		for key: String in item.upgrades:
			var option := {}
			for candidate: Dictionary in rules.get("upgrades",[]):
				if candidate.weapon==key: option = candidate
			if option.is_empty(): result.append(item.name+": unsupported equipment "+key+"."); continue
			if int(item.upgrades[key])>int(item.count)/int(option.per_models): result.append(item.name+": "+key+" allows one per "+str(option.per_models)+" models.")
			replacements[option.replaces]=int(replacements.get(option.replaces,0))+int(item.upgrades[key])
			if not p.weapons.has(option.replaces) or weapon(key).is_empty(): result.append(item.name+": missing weapon definition or invalid replacement.")
		for key in replacements:
			if int(replacements[key])>int(item.count): result.append(item.name+": more replacements than models with "+key+".")
		if check_fingerprints and data.profiles.has(item.unit_id) and data.profiles[item.unit_id]!=fingerprint(item.unit_id): result.append(item.name+": profile changed since saving. Review the current stats, then explicitly accept updated profiles.")
	if leaders==0: result.append("Add a Leader unit to command this army.")
	if total(data)>int(data.points_limit): result.append("Over budget by "+str(total(data)-int(data.points_limit))+" points. Remove models, equipment or units.")
	return result

static func stamp(data: Dictionary) -> void:
	data.profiles = {}
	var armies := []
	for item: Dictionary in data.units:
		if not profile(item.unit_id).is_empty(): data.profiles[item.unit_id] = fingerprint(item.unit_id)
		armies.append({"unit_id":item.unit_id})
	data.dependencies = ContentRegistry.required_for({"id":data.faction,"armies":armies})

static func save(data: Dictionary) -> String:
	var issue := schema_error(data)
	if not issue.is_empty(): return issue
	# Add references for newly added squads without accepting changed profiles
	# or dropping unavailable dependencies from an existing saved list.
	var selected_profiles:=[]
	for item: Dictionary in data.units:
		if not data.profiles.has(item.unit_id) and not profile(item.unit_id).is_empty():data.profiles[item.unit_id]=fingerprint(item.unit_id)
		selected_profiles.append({"unit_id":item.unit_id})
	for dependency in ContentRegistry.required_for({"id":data.faction,"armies":selected_profiles}):
		var known:=false
		for previous in data.dependencies:
			if previous.id==dependency.id:known=true
		if not known:data.dependencies.append(dependency)
	# Invalid drafts are preserved, but they cannot start battles.
	return "Saved army." if WorkshopStore.atomic_json(ROOT+data.id+".json",data) else "Could not save army; previous file is unchanged."

static func records(starters: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for folder in [ROOT,"res://resources/armies/" if starters else ""]:
		if folder.is_empty() or not DirAccess.dir_exists_absolute(folder): continue
		for file in DirAccess.get_files_at(folder):
			if file.get_extension()!="json": continue
			var data := WorkshopStore.read_json(folder+file)
			if schema_error(data).is_empty(): result.append(data)
	result.sort_custom(func(a,b): return str(a.name).naturalnocasecmp_to(str(b.name))<0)
	return result

static func remove(id: String) -> bool:
	return id.is_valid_identifier() and id.begins_with("army_") and DirAccess.remove_absolute(ROOT+id+".json")==OK

static func loadout_error(value: Variant, unit_id: String) -> String:
	if not value is Dictionary or value.get("kind")!="grimtable_loadout" or value.get("version")!=1 or value.get("unit_id")!=unit_id:return "Invalid loadout preset."
	var item:=entry(unit_id)
	item.count=value.get("count");item.upgrades=value.get("upgrades")
	var army:=fresh(str(profile(unit_id).get("faction","")),10000);army.units=[item]
	var issues:=errors(army,false)
	issues.erase("Add a Leader unit to command this army.")
	return "\n".join(issues)

static func import_file(path: String) -> Dictionary:
	var data := WorkshopStore.read_json(path,1048576)
	var issue := schema_error(data)
	if not issue.is_empty(): return {"error":issue}
	# Import never overwrites another local list. Missing content remains visible.
	data.id = new_id()
	return {"data":data}

static func equipped(item: Dictionary, model_ids: Array) -> Array[Dictionary]:
	var p := profile(item.unit_id)
	var holders := {}
	for id: String in p.weapons: holders[id] = model_ids.duplicate()
	for option: Dictionary in p.get("roster",{}).get("upgrades",[]):
		var count := int(item.upgrades.get(option.weapon,0))
		if count==0: continue
		var chosen: Array = []
		for i in count: chosen.append(holders[option.replaces].pop_back())
		holders[option.weapon] = chosen
	var result: Array[Dictionary] = []
	for id: String in holders:
		if holders[id].is_empty(): continue
		var w := weapon(id)
		w["_equipped_models"] = holders[id]
		w["_weapon_id"] = id
		result.append(w)
	return result

static func scenario(map: Dictionary, armies: Array, width: float = 60, depth: float = 44) -> Dictionary:
	if armies.size()!=2: return {"error":"Choose two armies."}
	for army in armies:
		var issues := errors(army)
		if not issues.is_empty(): return {"error":"Army "+str(army.get("name","?"))+": "+"\n".join(issues)}
	if armies[0].points_limit!=armies[1].points_limit: return {"error":"Both armies must agree on the same points limit."}
	var data := map.duplicate(true)
	data.armies = []
	data.board.width = width
	data.board.depth = depth
	data["army_lists"] = armies.duplicate(true)
	data["strict_armies"] = true
	data["base_scenario_name"] = str(map.get("base_scenario_name",map.name))
	data.name = armies[0].name+" vs "+armies[1].name+" — "+str(data.base_scenario_name)
	data.deployment_zones = []
	data.starting_state = {"round":1,"phase":0,"team":0,"deployment":true}
	for team in 2:
		var sign_z := 1 if team==0 else -1
		data.deployment_zones.append({"id":"zone_"+str(team),"name":"Team "+str(team+1),"team":team,"shape":"rectangle","center":[0,sign_z*(depth/2.0-5.0)],"size":[width,10]})
		var cursor := Vector2(-width/2+2, float(sign_z)*(depth/2-2))
		for index in armies[team].units.size():
			var item: Dictionary = armies[team].units[index]
			var p := profile(item.unit_id)
			var models := []
			var ids := []
			var pitch := ContentRegistry.base_radius(p)*2+.25
			for i in int(item.count):
				if cursor.x+pitch>width/2-1: cursor.x=-width/2+2; cursor.y-=sign_z*(pitch+1)
				var id := "t"+str(team)+"s"+str(index)+"m"+str(i)
				ids.append(id)
				models.append({"id":id,"position":[cursor.x,0,cursor.y],"cosmetic_id":item.cosmetic if not item.cosmetic.is_empty() else id})
				cursor.x+=pitch
			cursor.x+=1
			p["weapon_snapshots"] = equipped(item,ids)
			p.weapons = []
			for w in p.weapon_snapshots: p.weapons.append(w._weapon_id)
			data.armies.append({"id":"t"+str(team)+"s"+str(index),"name":item.name,"team":team,"unit_id":item.unit_id,"profile_snapshot":p,"models":models})
	var issue := ScenarioDefinition.validate(data)
	return {"data":data} if issue.is_empty() else {"error":issue}
