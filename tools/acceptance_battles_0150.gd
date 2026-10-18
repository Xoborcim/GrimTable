extends SceneTree

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var budget:=500
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--points="):budget=int(arg.trim_prefix("--points="))
	var lists:=ArmyRoster.records();var armies: Array=[]
	for faction in ["legion","swarm"]:armies.append(lists.filter(func(a):return a.faction==faction and a.points_limit==budget)[0])
	var map: Dictionary=ScenarioLibrary.read("res://resources/scenarios/hollow_basilica.json").data
	map.board.environment_art=false
	var scenario:=ArmyRoster.scenario(map,armies,90 if budget==2000 else 60,44)
	if scenario.has("error"):print("ACCEPTANCE ERROR ",scenario.error);quit(1);return
	scenario.data.starting_state["missions"]=MissionRules.initial("control",true,15000+budget)
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
	game.scenario=scenario.data
	game.settings=AppSettings.new();game.settings.autosave=false;game.settings.auto_allocate_damage=true;game.settings.auto_remove_defeated=true;game.settings.cinematic_dice="Off";game.settings.reduce_motion=true
	game.ai_config={"teams":{"0":"Easy" if budget==500 else "Normal","1":"Easy" if budget==500 else "Normal"},"seed":15000+budget,"round_limit":6,"speed":"Fast"}
	root.add_child(game);game.ai.set_process(false);game.life.set_process(false)
	game.dice.rng.seed=15000+budget
	for i in 3:await process_frame
	var report:={"points":budget,"mode":"Automated AI vs AI, not human usability testing","seed":15000+budget,"models":game.get_tree().get_nodes_in_group("miniatures").size(),"steps":0,"result":"incomplete"}
	var started:=Time.get_ticks_usec()
	var outcome: String=game.ai.step()
	report.deployment_ms=(Time.get_ticks_usec()-started)/1000.0
	report.deployment_error=game.deployment.validation_error()
	print("ACCEPTANCE DEPLOY ",JSON.stringify(report)," outcome=",outcome)
	if not report.deployment_error.is_empty():
		report.result="deployment_failed"
	else:
		started=Time.get_ticks_usec()
		for step in 3000:
			report.steps=step+1
			outcome=game.ai.step()
			if game.ai.finished or game.manager.missions.get("finished",false):report.result="complete";break
			if (Time.get_ticks_usec()-started)>180000000:report.result="time_budget";break
			if step%30==0:await process_frame;await physics_frame
		report.battle_ms=(Time.get_ticks_usec()-started)/1000.0
	report.round=game.manager.round_number;report.phase=game.manager.phase;report.scores=game.manager.scores
	report.primary_secondary=game.manager.missions.teams
	report.events=game.battle_log.sequence;report.ai_decisions=game.ai.decisions
	var times: Array=game.ai.planning_ms.duplicate();times.sort()
	report.ai_mean_ms=game.ai.total_action_ms/maxi(1,game.ai.decisions)
	report.ai_p95_ms=times[mini(times.size()-1,int(times.size()*.95))] if not times.is_empty() else 0
	report.ai_max_ms=times.back() if not times.is_empty() else 0
	report.save=SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://acceptance_"+str(budget)+".json")
	report.replay_validation=ActionCodec.validate(game.battle_log.entries,game.initial_scenario)
	WorkshopStore.atomic_json("res://docs/armies_0150/acceptance_"+str(budget)+".json",report)
	print("ACCEPTANCE RESULT ",JSON.stringify(report))
	game.queue_free();await process_frame
	quit(0 if report.result=="complete" and report.replay_validation.is_empty() else 1)
