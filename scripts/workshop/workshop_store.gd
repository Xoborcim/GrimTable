class_name WorkshopStore
extends RefCounted

# Local cosmetics never enter WorldState, profiles, mod packs or network packets.
const ROOT := "user://workshop/"
const VERSION := 1
const COLORS := {"primary":"315f86","secondary":"c5bda5","trim":"a08d5f","cloth":"665947","weapon":"414b50","metal":"727f86","glow":"62d0d3","body":"6d586c"}
const EFFECTS := {"wash":.32,"drybrush":.2,"highlight":.42,"weathering":.48,"metallic":0.0,"roughness":0.0,"glow":0.0}
const PARTS := {"head":3,"shoulders":3,"backpack":3,"weapon":3,"accessory":4,"decoration":4}
const PRESETS := {"Azure Sentinels":["315f86","c5bda5","a08d5f"],"Oxide Wardens":["8c4035","b7c4a1","bfa06d"],"Obsidian Surveyors":["343b44","a47e55","b4bac0"],"Verdant Watch":["536c57","dfcfac","8d7257"]}
static var variants_cache: Dictionary = {}
static var texture_cache: Dictionary = {}
static var assignments_cache: Dictionary = {}
static var assignments_loaded := false

static func fresh(source: String="legion_trooper") -> Dictionary:
	return {"version":VERSION,"id":"","name":"Untitled miniature","source":source,"colors":COLORS.duplicate(),"effects":EFFECTS.duplicate(),"parts":{"head":0,"shoulders":0,"backpack":0,"weapon":0,"accessory":0,"decoration":0},"pose":"Neutral","head_yaw":0.0,"torso_yaw":0.0,"base_style":"Rubble","rim":"202a34","ground":"a59b80","nameplate":"","scale":1.0,"rotation":0.0,"offset":0.0,"materials":{},"decals":[],"overlay":"","thumbnail":""}

static func valid_id(id: String) -> bool:
	return id.begins_with("figure_") and id.is_valid_identifier() and id.length()<80

static func color_valid(value: Variant) -> bool:
	return value is String and value.length() in [6,8] and value.is_valid_hex_number(false)

static func numeric(value: Variant, lo: float, hi: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value)>=lo and float(value)<=hi

static func validate(data: Variant, scheme: bool=false) -> String:
	if not data is Dictionary or data.get("version")!=VERSION:return "Unsupported Workshop format."
	var allowed := ["version","id","name","source","colors","effects","parts","pose","head_yaw","torso_yaw","base_style","rim","ground","nameplate","scale","rotation","offset","materials","decals","overlay","thumbnail"]
	if scheme:allowed=["version","kind","name","colors","effects"]
	for key in data:
		if key not in allowed:return "Unsupported field: "+str(key)
	if not data.get("name") is String or data.name.length()>100:return "Invalid name."
	for group in ["colors","effects"]:
		if not data.get(group) is Dictionary:return "Missing "+group
	for key in data.colors:
		if not COLORS.has(key) or not color_valid(data.colors[key]):return "Invalid paint color."
	for key in data.effects:
		if not EFFECTS.has(key) or not numeric(data.effects[key],-0.35 if key in ["roughness","metallic"] else 0,0.35 if key in ["roughness","metallic"] else 1):return "Invalid finishing value."
	if scheme:return "" if data.get("kind")=="grimtable_paint_scheme" else "Invalid paint-scheme type."
	if not valid_id(str(data.get("id",""))):return "Invalid collection ID."
	var source: Variant=data.get("source")
	if not source is String or (not AuthoredArt.MODELS.has(source) and not MiniatureLibrary.safe_id(source)):return "Unknown model identity."
	if not data.get("parts") is Dictionary:return "Missing parts."
	for key in data.parts:
		if not PARTS.has(key) or not ScenarioDefinition.integer(data.parts[key],0,PARTS[key]-1):return "Incompatible attachment."
		if source!="legion_trooper" and int(data.parts[key])!=0:return "This component belongs to the Legion infantry family."
	if data.get("pose") not in ["Neutral","Ready","Aiming","Advancing","Heroic Display"]:return "Invalid pose."
	if source!="legion_trooper" and (data.pose!="Neutral" or data.get("head_yaw")!=0 or data.get("torso_yaw")!=0):return "This model has no authored pose controls."
	for entry in [["head_yaw",-25,25],["torso_yaw",-8,8],["scale",.01,100],["rotation",-180,180],["offset",-10,10]]:
		if not numeric(data.get(entry[0]),entry[1],entry[2]):return "Invalid transform."
	if data.get("base_style") not in ["Rubble","Industrial","Stone","Ash"]:return "Invalid base style."
	if not color_valid(data.get("rim")) or not color_valid(data.get("ground")):return "Invalid base paint."
	if not data.get("nameplate") is String or data.nameplate.length()>24:return "Invalid nameplate."
	if not data.get("materials") is Dictionary or data.materials.size()>64:return "Invalid material overrides."
	for key in data.materials:
		if not str(key).is_valid_int() or int(key)<0 or int(key)>63 or not color_valid(data.materials[key]):return "Invalid material color."
	if not data.get("decals") is Array or data.decals.size()>16:return "Maximum sixteen markings."
	for decal in data.decals:
		if not decal is Dictionary or decal.keys().size()!=8 or not ScenarioDefinition.integer(decal.get("island"),1,65535):return "Invalid marking."
		if decal.get("kind") not in ["Stripe","Diamond","Hazard","Number","Text"] or not decal.get("text") is String or decal.text.length()>12 or not color_valid(decal.get("color")):return "Invalid marking."
		for entry in [["u",0,1],["v",0,1],["size",.005,.2],["angle",-180,180]]:
			if not numeric(decal.get(entry[0]),entry[1],entry[2]):return "Invalid marking position."
	for key in ["overlay","thumbnail"]:
		var path: Variant=data.get(key)
		if not path is String or (not path.is_empty() and (path!=path.get_file() or not path.begins_with(data.id+"_") or path.get_extension()!="png")):return "Invalid cosmetic texture path."
	return ""

static func atomic_json(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(data,"\t"));file.flush();file.close()
	# Rename replacement is atomic on the target filesystem; failed saves keep old data.
	return DirAccess.rename_absolute(path+".tmp",path)==OK

static func read_json(path: String, limit: int=262144) -> Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>limit:return {}
	var value: Variant=JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}

static func records() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	if not DirAccess.dir_exists_absolute(ROOT+"figures"):return result
	for name in DirAccess.get_files_at(ROOT+"figures"):
		if name.get_extension()!="json":continue
		var value:=read_json(ROOT+"figures/"+name)
		if validate(value).is_empty() and name==str(value.id)+".json":result.append(value)
	result.sort_custom(func(a: Dictionary,b: Dictionary):return str(a.name).naturalnocasecmp_to(str(b.name))<0)
	return result

static func image(data: Dictionary, key: String) -> Image:
	var path:=ROOT+"images/"+str(data.get(key,""))
	if str(data.get(key,"")).is_empty() or not FileAccess.file_exists(path):return null
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>5000000:return null
	var bytes:=file.get_buffer(file.get_length())
	# Inspect PNG IHDR before decoding; managed saves only use bounded PNGs.
	if bytes.size()<24 or bytes.slice(0,8)!=PackedByteArray([137,80,78,71,13,10,26,10]):return null
	var w:=0;var h:=0
	for i in 4:w=w*256+bytes[16+i];h=h*256+bytes[20+i]
	if w<1 or h<1 or w>1024 or h>1024:return null
	var img:=Image.new()
	if img.load_png_from_buffer(bytes)!=OK:return null
	img.convert(Image.FORMAT_RGBA8)
	return img

static func save(data: Dictionary, overlay: Image=null, thumbnail: Image=null) -> Dictionary:
	var result:=data.duplicate(true)
	if str(result.id).is_empty():result.id=ScenarioLibrary.new_id("figure")
	var problem:=validate(result)
	if not problem.is_empty():return {"error":problem}
	DirAccess.make_dir_recursive_absolute(ROOT+"images")
	var revision:=str(Time.get_ticks_usec())
	for pair in [["overlay",overlay],["thumbnail",thumbnail]]:
		if pair[1]==null:continue
		var img: Image=pair[1].duplicate();img.clear_mipmaps()
		if img.get_width()>1024 or img.get_height()>1024:return {"error":"Cosmetic image exceeds 1024 pixels."}
		var name: String=result.id+"_"+revision+"_"+pair[0]+".png"
		if img.save_png(ROOT+"images/"+name)!=OK:return {"error":"Could not save paint texture."}
		result[pair[0]]=name
	if not atomic_json(ROOT+"figures/"+result.id+".json",result):return {"error":"Could not safely save miniature."}
	variants_cache.clear();texture_cache.clear()
	# Only remove old managed revisions after the record is safely replaced.
	cleanup_images()
	return result

static func cleanup_images() -> void:
	var used: Dictionary={}
	for entry in records():
		for key in ["overlay","thumbnail"]:used[str(entry[key])]=true
	for name in DirAccess.get_files_at(ROOT+"images"):
		if name.begins_with("figure_") and name.get_extension()=="png" and not used.has(name):DirAccess.remove_absolute(ROOT+"images/"+name)

static func delete(id: String) -> bool:
	if not valid_id(id):return false
	var ok:=DirAccess.remove_absolute(ROOT+"figures/"+id+".json")==OK
	variants_cache.clear();texture_cache.clear();cleanup_images()
	return ok

static func scheme(data: Dictionary, title: String) -> Dictionary:
	return {"version":VERSION,"kind":"grimtable_paint_scheme","name":title.left(100),"colors":data.colors.duplicate(),"effects":data.effects.duplicate()}

static func import_scheme(path: String) -> Dictionary:
	var data:=read_json(path)
	var issue:=validate(data,true)
	return data if issue.is_empty() else {"error":issue}

static func saved_schemes() -> Array:
	var result: Array=[]
	for item in read_json(ROOT+"schemes.json").get("schemes",[]):
		if validate(item,true).is_empty():result.append(item)
	return result.slice(0,64)

static func save_scheme(value: Dictionary) -> bool:
	if not validate(value,true).is_empty():return false
	var schemes:=saved_schemes()
	for i in range(schemes.size()-1,-1,-1):
		if schemes[i].name==value.name:schemes.remove_at(i)
	schemes.push_front(value)
	return atomic_json(ROOT+"schemes.json",{"schemes":schemes.slice(0,64)})

static func assignments() -> Dictionary:
	if not assignments_loaded:
		assignments_cache=read_json(ROOT+"assignments.json");assignments_loaded=true
	return assignments_cache

static func assign(scope: String, key: String, figure: String) -> bool:
	if scope not in ["model","squad","profile","faction"] or key.is_empty() or key.length()>160 or not valid_id(figure):return false
	var data:=assignments().duplicate(true);data[scope+":"+key]=figure
	if not atomic_json(ROOT+"assignments.json",data):return false
	assignments_cache=data
	return true

static func assigned(profile: Dictionary, model: String, squad: String="") -> Dictionary:
	for key in ["model:"+model,"squad:"+squad,"profile:"+str(profile.get("id","")),"faction:"+str(profile.get("faction",""))]:
		var id: String=model if valid_id(model) else str(assignments().get(key,""))
		if not valid_id(id):continue
		var path:=ROOT+"figures/"+id+".json"
		if not FileAccess.file_exists(path):continue
		var data: Dictionary=variants_cache.get(id,{})
		if data.is_empty():data=read_json(path);variants_cache[id]=data
		if not validate(data).is_empty():continue
		if data.source==profile.get("id","") or data.source==ArmyCosmetics.family(profile):return data
		for imported in MiniatureLibrary.records():
			if imported.id==data.source and imported.get("profile","")==profile.get("id",""):return data
	return {}
