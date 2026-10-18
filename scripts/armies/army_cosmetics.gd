class_name ArmyCosmetics
extends RefCounted

static func family(profile: Dictionary) -> String:
	for source in ["legion_trooper","legion_walker","swarm_hunter"]:
		if profile.get("id")==source or profile.get("fallback_visual")==source:return source
		var builtin:=ArmyRoster.profile(source)
		if profile.get("model_scene","")==builtin.get("model_scene","missing"):return source
	return ""

static func apply_scheme(army: Dictionary, scheme: Dictionary, squad_index: int = -1) -> Dictionary:
	var issue:=WorkshopStore.validate(scheme,true)
	if not issue.is_empty():return {"error":issue}
	var applied:=0;var reused:={}
	for i in army.units.size():
		if squad_index>=0 and i!=squad_index:continue
		var item: Dictionary=army.units[i]
		var source:=family(ArmyRoster.profile(item.unit_id))
		if source.is_empty():continue
		var key:=source+":"+str(item.cosmetic)
		if reused.has(key):item.cosmetic=reused[key];applied+=1;continue
		var data:=WorkshopStore.fresh(source)
		for figure in WorkshopStore.records():
			if figure.id==item.cosmetic:data=figure.duplicate(true)
		if data.source!=source:continue
		var overlay:=WorkshopStore.image(data,"overlay")
		if not str(data.overlay).is_empty() and overlay==null:return {"error":"This figure's paint overlay is missing. Restore it before applying a scheme."}
		var thumbnail:=WorkshopStore.image(data,"thumbnail")
		data.id="";data.name=(scheme.name+" · "+item.name).left(100);data.overlay="";data.thumbnail=""
		data.colors.merge(scheme.colors,true);data.effects.merge(scheme.effects,true)
		var saved:=WorkshopStore.save(data,overlay,thumbnail)
		if saved.has("error"):return {"error":saved.error}
		item.cosmetic=saved.id;reused[key]=saved.id;applied+=1
	return {"applied":applied}
