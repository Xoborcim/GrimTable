extends SceneTree

var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("FAIL: "+message)

func run() -> void:
	ContentRegistry.catalog()
	check(ContentRegistry.validate().is_empty(),"Existing and expanded content validates")
	var lists := ArmyRoster.records()
	check(lists.size()==12,"Twelve built-in starter armies")
	for army in lists:
		check(ArmyRoster.errors(army).is_empty(),army.name+": "+str(ArmyRoster.errors(army)))
		check(ArmyRoster.total(army)<=army.points_limit and ArmyRoster.total(army)>=army.points_limit*.95,"Starter budget use")
	var army: Dictionary = lists.filter(func(a): return a.id=="army_starter_legion_500")[0].duplicate(true)
	ArmyRoster.stamp(army)
	check(ArmyRoster.errors(army).is_empty(),"Fresh content stamps accepted")
	var item := ArmyRoster.entry("legion_trooper")
	item.count=10;item.upgrades={"legion_cannon":2}
	check(ArmyRoster.cost(item)==208,"Per-model costs plus two upgrades")
	var ids := ["one","two","three","four","five","six","seven","eight","nine","ten"]
	var groups := ArmyRoster.equipped(item,ids)
	check(groups.size()==3 and groups[0]._equipped_models.size()==8 and groups[2]._equipped_models.size()==2,"Replacements equip two actual models")
	check(not groups[0]._equipped_models.has(groups[2]._equipped_models[0]),"Rifle and cannon are mutually exclusive")
	army.units.append(item);army.points_limit=2000
	check(ArmyRoster.errors(army,false).is_empty(),"Legal mixed squad allowed")
	item.upgrades.legion_cannon=3
	check(not ArmyRoster.errors(army,false).is_empty(),"Equipment allowance rejects excess")
	item.upgrades.legion_cannon=2
	army.profiles.legion_trooper="0".repeat(64)
	check(not ArmyRoster.errors(army).is_empty(),"Changed content requires explicit acceptance")
	army.units[0].unit_id="missing_pack:unit"
	check("missing profile" in "\n".join(ArmyRoster.errors(army)),"Missing profiles preserved and reported")
	army=lists[0].duplicate(true);army.id=ArmyRoster.new_id();ArmyRoster.stamp(army)
	check(ArmyRoster.save(army).begins_with("Saved"),"Atomic army save")
	army.units.append(ArmyRoster.entry("legion_assault" if army.faction=="legion" else "horde_runners"))
	var old_stamp: String=army.profiles[army.units[0].unit_id]
	ArmyRoster.save(army)
	check(army.profiles.has(army.units[-1].unit_id) and army.profiles[army.units[0].unit_id]==old_stamp,"Saving newly added squads records their profile without accepting existing updates")
	var read:=ArmyRoster.import_file(ArmyRoster.ROOT+army.id+".json")
	check(read.has("data") and read.data.id!=army.id and NetworkSession.state_hash({"units":read.data.units})==NetworkSession.state_hash({"units":army.units}),"Import retains composition with a new identity")
	check(ArmyRoster.remove(army.id),"Local list deletion")
	var map: Dictionary = ScenarioLibrary.read("res://resources/scenarios/hollow_basilica.json").data
	for budget in [500,1000,2000]:
		var forces:=[]
		for faction in ["legion","swarm"]: forces.append(lists.filter(func(a):return a.faction==faction and a.points_limit==budget)[0])
		var built:=ArmyRoster.scenario(map,forces,90 if budget==2000 else 60,44)
		check(built.has("data"),"Build "+str(budget)+" point battle: "+str(built.get("error","")))
		if built.has("data"):check(ScenarioDefinition.validate(ContentRegistry.freeze(built.data)).is_empty(),"Frozen configured scenario validates")
	var bad: Dictionary=army.duplicate(true);bad.units[0].count=-5
	check(not ArmyRoster.schema_error(bad).is_empty(),"Unsafe numeric input rejected")
	bad=ArmyRoster.fresh("swarm",10000)
	for i in 16:
		var squad:=ArmyRoster.entry("swarm_crawler");squad.count=20;bad.units.append(squad)
	check("300 models" in "\n".join(ArmyRoster.errors(bad)),"Model budget bounds extreme custom forces")
	print("GRIMTABLE ARMIES ",checks," checks / ",failures," failures")
	quit(0 if failures==0 else 1)
