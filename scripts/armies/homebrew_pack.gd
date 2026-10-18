class_name HomebrewPack
extends RefCounted

const ROOT := "user://homebrew/"
const UNIT_FIELDS := ["id","name","faction","movement","defense","toughness","save","wounds","max_wounds","base_mm","gameplay_height","los_height","visual_scale","weapons","fallback_visual","roster"]
const WEAPON_FIELDS := ["id","name","range","attacks","hit","strength","ap","damage","type","tags","ap_semantics"]

static func fresh(id: String = "my_faction") -> Dictionary:
	return {"kind":"grimtable_content_pack","version":1,"manifest":{"id":id,"name":"My faction","version":"1.0.0","grimtable_version":">=0.10.0","author":"Local creator","description":"Original homebrew faction. Creator-assigned points; not competitively balanced.","dependencies":[]},"factions":[{"id":id+":faction","name":"My faction","description":"Original homebrew faction.","color":"#627d8e","accent":"#c9b583","emblem":"Diamond"}],"units":[],"weapons":[]}

static func next_number(items: Array) -> int:
	var number:=1
	var used:=[]
	for item in items:used.append(str(item.id).get_slice("_",str(item.id).get_slice_count("_")-1))
	while used.has(str(number)):number+=1
	return number

static func unit(data: Dictionary) -> Dictionary:
	var id: String=data.manifest.id
	return {"id":id+":unit_"+str(next_number(data.units)),"name":"New unit","faction":id+":faction","movement":6,"defense":4,"save":4,"max_wounds":2,"wounds":2,"base_mm":32,"gameplay_height":1.7,"los_height":1.36,"visual_scale":1.0,"weapons":["legion_rifle","combat_blade"],"fallback_visual":"legion_trooper","roster":{"role":"Infantry","points_per_model":15,"base_points":0,"min_size":5,"max_size":10,"max_units":6,"upgrades":[]}}

static func weapon(data: Dictionary) -> Dictionary:
	return {"id":str(data.manifest.id)+":weapon_"+str(next_number(data.weapons)),"name":"New weapon","range":24,"attacks":2,"hit":4,"strength":4,"ap":0,"damage":1,"type":"ranged","tags":[],"ap_semantics":"penalty"}

static func validate(data: Variant) -> String:
	if not data is Dictionary or data.get("kind")!="grimtable_content_pack" or data.get("version")!=1:return "Unsupported homebrew pack format."
	for key in data:
		if key not in ["kind","version","manifest","factions","units","weapons"]:return "Unsupported content field: "+str(key)
	if not data.get("manifest") is Dictionary:return "Missing manifest."
	for key in data.manifest:
		if key not in ["id","name","version","grimtable_version","author","description","dependencies","license","homepage"]:return "Unsupported manifest field."
	var issue:=ModLoader.manifest_error(data.manifest)
	if not issue.is_empty():return issue
	if not data.manifest.get("dependencies",[]).is_empty():return "This editor exports self-contained rules plus built-in references; external pack dependencies are not supported here."
	var definitions:={}
	for category in ["factions","units","weapons"]:
		if not data.get(category) is Array or data[category].size()>100:return "Invalid "+category+" collection."
		for item in data[category]:
			if not item is Dictionary or not ModLoader.own_id(item.get("id"),data.manifest.id) or definitions.has(item.id):return "Invalid or duplicate namespaced content ID."
			if not item.get("name") is String or item.name.is_empty() or item.name.length()>100:return "Content names must contain 1–100 characters."
			definitions[item.id]=category
	if data.factions.size()!=1:return "The faction editor requires exactly one faction."
	var faction: Dictionary=data.factions[0]
	for key in faction:
		if key not in ["id","name","description","color","accent","emblem"]:return "Unsupported faction field."
	for key in ["color","accent"]:
		if not faction.get(key) is String or not Color.html_is_valid(faction[key]):return "Invalid faction palette."
	if not faction.get("description","") is String or str(faction.get("description","")).length()>2000 or faction.get("emblem") not in ["Diamond","Circle","Chevron","Cross"]:return "Invalid faction description or emblem."
	var weapons:={}
	for id in ContentRegistry._builtin.weapons:weapons[id]=ArmyRoster.weapon(id)
	for item: Dictionary in data.weapons:
		for key in item:
			if key not in WEAPON_FIELDS:return "Unsupported weapon field: "+str(key)
		issue=ContentRegistry.weapon_error(item)
		if not issue.is_empty():return item.name+": "+issue
		if item.get("ap_semantics")!="penalty":return "Homebrew weapons use positive AP penalties."
		for tag in item.get("tags",[]):
			if tag not in ["anti_heavy","anti_infantry"]:return "Unsupported weapon trait."
		weapons[item.id]=item
	for item: Dictionary in data.units:
		for key in item:
			if key not in UNIT_FIELDS:return "Unsupported unit field: "+str(key)
		if item.get("faction")!=faction.id:return "Unit belongs to a different faction."
		if not item.get("weapons") is Array:return "Missing weapons."
		var check_profile:=item.duplicate(true);check_profile["weapon_snapshots"]=[]
		for id in item.weapons:
			if not id is String or not weapons.has(id):return "Missing weapon: "+str(id)
			check_profile.weapon_snapshots.append(weapons[id])
		issue=ContentRegistry.profile_error(check_profile,true)
		if not issue.is_empty():return item.name+": "+issue
		issue=ArmyRoster.rules_error(item.get("roster"))
		if not issue.is_empty():return item.name+": "+issue
		for option in item.roster.get("upgrades",[]):
			if not weapons.has(option.weapon) or not item.weapons.has(option.replaces):return "Invalid equipment replacement."
		if not ContentRegistry._builtin.units.has(item.get("fallback_visual")):return "Choose a built-in fallback miniature."
	return ""

static func install(data: Dictionary) -> String:
	var issue:=validate(data)
	if not issue.is_empty():return issue
	var id: String=data.manifest.id
	DirAccess.make_dir_recursive_absolute("user://mods")
	var destination:=ModLoader.safe_path("user://mods",id)
	if destination.is_empty():return "Unsafe content destination."
	if DirAccess.dir_exists_absolute(destination) and WorkshopStore.read_json(destination+"/grimtable_homebrew.json").get("kind")!="grimtable_content_pack":return "An existing non-editor content pack already owns this ID. Choose another pack ID."
	var stage:="user://content_staging/"+id+"_"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(stage)
	if not WorkshopStore.atomic_json(stage+"/manifest.json",data.manifest):return "Could not write manifest."
	for category in ["factions","units","weapons"]:
		for item in data[category]:
			if not WorkshopStore.atomic_json(stage+"/"+category+"/"+str(item.id).get_slice(":",1)+".json",item):return "Could not write content."
	if not WorkshopStore.atomic_json(stage+"/grimtable_homebrew.json",data):return "Could not write editor metadata."
	var backup:="user://content_backups/"+id+"_"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(backup.get_base_dir())
	var had_previous:=DirAccess.dir_exists_absolute(destination)
	if had_previous and DirAccess.rename_absolute(destination,backup)!=OK:return "Could not preserve the previous pack."
	if DirAccess.rename_absolute(stage,destination)!=OK:
		if had_previous:DirAccess.rename_absolute(backup,destination)
		return "Could not install content; previous pack was preserved."
	ModLoader.set_enabled(id,true)
	ContentRegistry.reload_content()
	if not ModLoader.loaded.has(id):return "Pack was saved but failed to load; inspect Mods for the validation error."
	return "Installed homebrew faction. It is now available in Army Builder."
