extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
func run() -> void:
	ContentRegistry.catalog()
	var army:=ArmyRoster.fresh("legion",2000)
	army.units=[ArmyRoster.entry("legion_commander"),ArmyRoster.entry("legion_trooper")]
	var original:=WorkshopStore.fresh();original.parts.head=2;original.base_style="Stone"
	var overlay:=Image.create(1024,1024,false,Image.FORMAT_RGBA8);overlay.fill(Color.TRANSPARENT);overlay.set_pixel(300,300,Color.RED)
	var saved:=WorkshopStore.save(original,overlay)
	army.units[1].cosmetic=saved.id
	var scheme:=WorkshopStore.scheme(WorkshopStore.fresh(),"QA Crimson");scheme.colors.primary="aa4433"
	var applied:=ArmyCosmetics.apply_scheme(army,scheme,1)
	check(applied.get("applied")==1,"Apply scheme to selected squad")
	var figure:=WorkshopStore.read_json(WorkshopStore.ROOT+"figures/"+army.units[1].cosmetic+".json")
	check(figure.parts.head==2 and figure.base_style=="Stone","Scheme preserves parts and scenic base")
	check(WorkshopStore.image(figure,"overlay").get_pixel(300,300)==Color.RED,"Scheme preserves unique freehand paint")
	check(figure.id!=saved.id and WorkshopStore.read_json(WorkshopStore.ROOT+"figures/"+saved.id+".json").colors.primary==original.colors.primary,"Source painted figure remains unchanged")
	check(not WorkshopStore.assigned(ArmyRoster.profile("legion_trooper"),figure.id).is_empty(),"Army cosmetic reference resolves directly")
	var cost:=ArmyRoster.total(army);var radius:=ContentRegistry.base_radius(ArmyRoster.profile("legion_trooper"))
	check(ArmyCosmetics.apply_scheme(army,scheme).get("applied")==2 and ArmyRoster.total(army)==cost,"Army scheme includes compatible leader without changing points")
	check(ContentRegistry.base_radius(ArmyRoster.profile("legion_trooper"))==radius,"Cosmetics never change base footprint")
	var loadout:={"kind":"grimtable_loadout","version":1,"unit_id":"legion_trooper","count":5,"upgrades":{"legion_cannon":1}}
	check(ArmyRoster.loadout_error(loadout,"legion_trooper").is_empty(),"Legal reusable loadout")
	loadout.upgrades.legion_cannon=2
	check(not ArmyRoster.loadout_error(loadout,"legion_trooper").is_empty(),"Invalid preset cannot bypass equipment allowances")
	var preset:={"kind":"grimtable_battle_preset","version":1,"name":"QA setup","army_a":army.id,"army_b":army.id,"scenario":"hollow_basilica","points":2000,"width":90,"depth":44,"opponent":0,"difficulty":1,"primary":1,"tactical":true,"seed":77}
	check(BattlePreset.save(preset).begins_with("Saved"),"Versioned battle preset saved")
	preset.width=1000
	check(not BattlePreset.error(preset).is_empty(),"Unsupported board sizes rejected")
	var lists:=ArmyRoster.records()
	var swarm:=ArmyRoster.fresh("swarm",2000)
	swarm.units.append(ArmyRoster.entry("swarm_synapse"))
	for i in 8:
		var item:=ArmyRoster.entry("swarm_crawler");item.count=20;swarm.units.append(item)
	for i in 3:swarm.units.append(ArmyRoster.entry("swarm_brood_beast"))
	var winged:=ArmyRoster.entry("swarm_winged_beast");winged.count=2;swarm.units.append(winged)
	check(ArmyRoster.errors(swarm).is_empty() and ArmyRoster.total(swarm)==1940,"Swarm-heavy force legal at 2,000 points")
	var map: Dictionary=ScenarioLibrary.read("res://resources/scenarios/hollow_basilica.json").data;map.board.environment_art=false
	var battle:=ArmyRoster.scenario(map,[lists.filter(func(a):return a.id=="army_starter_legion_2000")[0],swarm],90,44)
	check(battle.has("data"),"212-model scenario generated")
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate();game.scenario=battle.data;game.settings=AppSettings.new();game.settings.autosave=false
	game.ai_config={"teams":{"0":"Normal","1":"Normal"},"seed":77,"round_limit":1,"speed":"Fast"};root.add_child(game);game.ai.set_process(false)
	for i in 3:await process_frame
	var started:=Time.get_ticks_usec();game.ai.step()
	var elapsed:=(Time.get_ticks_usec()-started)/1000.0
	check(game.deployment.validation_error().is_empty(),"Dense 212-model army deployment remains legal: "+game.deployment.validation_error())
	print("LARGE DEPLOYMENT 212 models ",elapsed," ms")
	game.manager.deployment=true
	var unit: TableUnit=game.battlefield.units.get_child(0)
	var before:=unit.models[0].global_position
	var rotated:=ArmyDeployment.rotate(game,unit,15)
	check(rotated.begins_with("Formation rotated") and unit.models[0].global_position.is_equal_approx(before),"Single-model rotation preserves footprint")
	game.queue_free();await process_frame
	for id in [saved.id,figure.id,army.units[0].cosmetic,army.units[1].cosmetic]:WorkshopStore.delete(id)
	print("GRIMTABLE ARMY SYSTEM ",checks," checks / ",failures," failures")
	quit(0 if failures==0 else 1)
