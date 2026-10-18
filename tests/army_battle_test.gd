extends SceneTree

var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)

func run() -> void:
	var app: Node=load("res://scenes/main/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var builder: ArmyBuilder=app.show_army_builder()
	await process_frame
	check(builder.collection.get_child_count()>12,"Army collection and starters are visible")
	builder.army=ArmyRoster.records()[0].duplicate(true);builder.selected=0;builder.refresh()
	check(builder.detail.get_child_count()>8,"Squad editing controls are implemented")
	builder.queue_free();app.show_army_battle()
	check(app.column.get_child_count()>15,"Full battle setup is reachable")
	var lists:=ArmyRoster.records()
	var legion: Dictionary=lists.filter(func(a):return a.id=="army_starter_legion_500")[0].duplicate(true)
	var swarm: Dictionary=lists.filter(func(a):return a.id=="army_starter_swarm_500")[0].duplicate(true)
	var rifle:=ArmyRoster.entry("legion_trooper");rifle.count=5;rifle.upgrades={"legion_cannon":1};legion.units=[ArmyRoster.entry("legion_commander"),rifle]
	var map: Dictionary=ScenarioLibrary.read("res://resources/scenarios/hollow_basilica.json").data
	map.terrain=[];map.board.environment_art=false
	var item:=ArmyRoster.scenario(map,[legion,swarm])
	check(item.has("data"),"Configured battle generated")
	app.launch_scenario(item)
	var game: Node3D=app.game
	game.ai.enabled=false;game.settings.autosave=false;game.settings.auto_allocate_damage=false
	for i in 3:await process_frame
	var attacker: TableUnit=game.battlefield.units.get_child(1)
	var target: TableUnit=game.battlefield.units.get_child(2)
	var other: TableUnit=game.battlefield.units.get_child(3)
	for i in attacker.models.size():attacker.models[i].global_position=Vector3(-3+i*1.5,0,3)
	for i in target.models.size():target.models[i].global_position=Vector3(i,0,-5)
	for i in other.models.size():other.models[i].global_position=Vector3(i,0,-7)
	game.manager.deployment=false;game.manager.phase=2;game.manager.active_team=0
	await physics_frame
	var world:=game.get_world_3d()
	check(AttackResolver.preview(attacker,target,world,attacker.weapon_profiles[0]).eligible==4,"Four rifle holders, not five")
	check(game.combat.resolve(attacker,target,world,0),"Manual rifle group attack")
	game.combat.discard_pending()
	check(not game.combat.resolve(attacker,other,world,0),"Same models cannot fire twice at another target")
	check(game.combat.resolve(attacker,other,world,2),"Different equipped group can split fire")
	game.combat.discard_pending()
	check(not game.combat.resolve(attacker,target,world,1),"Melee unavailable during shooting")
	while not game.history.undo_stack.is_empty():game.history.undo()
	check(AttackResolver.preview(attacker,target,world,attacker.weapon_profiles[0]).eligible==4,"Undo restores weapon eligibility")
	while not game.history.redo_stack.is_empty():game.history.redo()
	check(AttackResolver.preview(attacker,target,world,attacker.weapon_profiles[0]).eligible==0,"Redo restores weapon expenditure")
	var captured:=ScenarioFactory.capture(game)
	check(captured.armies[1].profile_snapshot.weapon_snapshots[2]._equipped_models.size()==1,"Scenario capture preserves mixed equipment")
	var document:={"format_version":2,"initial_scenario":game.initial_scenario,"events":game.battle_log.entries}
	var events_issue: String=ActionCodec.validate(document.events,document.initial_scenario)
	check(events_issue.is_empty(),"Configured attack events validate for replay: "+events_issue)
	check(WeaponUse.spent(attacker).size()==5,"Each equipped model expended once")
	app.queue_free();await process_frame
	print("GRIMTABLE ARMY BATTLE ",checks," checks / ",failures," failures")
	quit(0 if failures==0 else 1)
