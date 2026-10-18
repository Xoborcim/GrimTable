extends SceneTree

var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
func run() -> void:
	var seed_one:=MissionRules.initial("control",true,7654)
	check(seed_one==MissionRules.initial("control",true,7654),"Seeded deck order is deterministic")
	check(seed_one!=MissionRules.initial("control",true,7655),"Another seed changes draw order")
	check(MissionRules.error(seed_one).is_empty(),"Initial mission schema")
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
	var lists:=ArmyRoster.records()
	var armies: Array=[]
	for faction in ["legion","swarm"]:armies.append(lists.filter(func(a):return a.faction==faction and a.points_limit==500)[0])
	var map: Dictionary=ScenarioLibrary.read("res://resources/scenarios/hollow_basilica.json").data
	map.terrain=[];map.board.environment_art=false
	game.scenario=ArmyRoster.scenario(map,armies).data
	game.scenario.starting_state.missions=seed_one
	game.settings=AppSettings.new();game.settings.autosave=false;game.settings.reduce_motion=true
	root.add_child(game);game.ai.enabled=false
	for i in 3:await process_frame
	game.manager.deployment=false
	MissionRules.update(game)
	check(game.manager.missions.teams["0"].active.size()==2 and game.manager.missions.teams["1"].active.size()==2,"Two cards drawn per team")
	var first: Array=game.manager.missions.teams["0"].active.duplicate()
	MissionRules.update(game)
	check(game.manager.missions.teams["0"].active==first,"Repeated processing never draws twice")
	var owners:={}
	for objective: TableObjective in game.battlefield.objectives.get_children():owners[objective.object_id]=0
	game.manager.objective_owners=owners
	game.manager.missions.teams["0"].active=["hold_breach","secure_relay"]
	for i in 11:game.manager.next_phase()
	check(game.manager.missions.teams["0"].primary_score==6,"Primary scoring capped at six")
	check(game.manager.missions.teams["0"].secondary_score==7,"Two completed tactical missions award exact points")
	var score: Dictionary=game.manager.scores.duplicate()
	MissionRules.update(game);game.manager.previous_phase();game.manager.next_phase()
	check(game.manager.scores==score,"Duplicate events and phase revisits do not award again")
	check(MissionRules.error(game.manager.missions).is_empty(),"Scored mission state validates")
	check(WorldState.validate(WorldState.capture(game),game.initial_scenario).is_empty(),"World snapshot includes valid missions")
	var saved:=SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://mission_test.json")
	check(saved.begins_with("Saved"),"Mission battle saved")
	var before: Dictionary=game.manager.snapshot()
	game.manager.next_phase()
	check(game.manager.missions.round==2 and game.manager.missions.teams["0"].active!=first,"New round draws new cards")
	var loaded:=SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://mission_test.json")
	check(loaded.begins_with("Loaded") and game.manager.snapshot()==before,"Load restores piles, scores and completed history exactly: "+loaded)
	if game.manager.snapshot()!=before:print("MISSION BEFORE ",JSON.stringify(before),"\nAFTER ",JSON.stringify(game.manager.snapshot()))
	var malformed:=before.duplicate(true);malformed.missions.ledger.append(malformed.missions.ledger[0])
	check(not WorldState.turn_error(malformed).is_empty(),"Duplicate scoring IDs rejected")
	malformed=before.duplicate(true);malformed.missions.teams["0"].active=["unimplemented_script"]
	check(not WorldState.turn_error(malformed).is_empty(),"Unsupported missions rejected")
	var planner:=AIPlanner.new(game)
	var unit: TableUnit=game.battlefield.units.get_child(0)
	game.manager.missions.teams["0"].active=["recover_artifact"]
	check(MissionRules.position_bonus(game,unit,Vector3.ZERO)>MissionRules.position_bonus(game,unit,Vector3(25,0,20)),"AI mission utility values progress")
	check(ActionCodec.validate(game.battle_log.entries,game.initial_scenario).is_empty(),"Mission turn records validate for replay")
	var replay:=ReplayController.new();replay.game=game;game.add_child(replay)
	var records: Array=game.battle_log.entries.duplicate(true)
	check(replay.open({"initial_scenario":game.initial_scenario,"events":records}).is_empty(),"Mission replay opens")
	replay.seek(records.size())
	check(NetworkSession.state_hash(game.manager.snapshot())==NetworkSession.state_hash(before),"Replay reproduces recorded deck, scores and mission completion without RNG")
	game.queue_free();await process_frame
	print("GRIMTABLE MISSIONS ",checks," checks / ",failures," failures")
	quit(0 if failures==0 else 1)
