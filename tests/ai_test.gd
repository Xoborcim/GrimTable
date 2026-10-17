extends SceneTree

var checks := 0
var failures := 0
var game: Node3D
var report: Array = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)

func settle() -> void:
	for i in 3: await process_frame
	await physics_frame

func create_game(path: String = "res://resources/scenarios/ashfall_station.json") -> void:
	game = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new()
	game.settings.autosave = false
	game.settings.camera_assistance = false
	game.settings.reduce_motion = true
	game.scenario = ScenarioLibrary.read(path).data
	root.add_child(game)
	game.ai.enabled = false
	await settle()

func run() -> void:
	await create_game()
	check(AIController.valid_config({}),"Old saves without AI remain valid")
	check(not AIController.valid_config({"teams":{"2":"Hard"},"seed":1,"round_limit":3}),"Invalid AI team rejected")
	check(not AIController.valid_config({"teams":{"1":"Impossible"},"seed":1,"round_limit":3}),"Invalid difficulty rejected")
	check(not AIController.valid_config({"teams":{"1":"Easy"},"seed":-1,"round_limit":3}),"Invalid seed rejected")
	game.ai.configure({"teams":{"0":"Normal","1":"Normal"},"seed":77,"round_limit":2,"speed":"Fast"})
	var planner := AIPlanner.new(game,"Normal",77)
	var before := WorldState.capture(game)
	var first := planner.choose()
	var again := planner.choose()
	check(first == again,"Same state and seed chooses same action")
	check(before == WorldState.capture(game),"Planning leaves gameplay state unchanged")
	game.ai.set_process(false)
	game.ai.enabled = true
	var incremental: Dictionary = await planner.choose_incremental()
	check(incremental == first,"Frame-spread planning chooses the same seeded movement")
	check(before == WorldState.capture(game),"Frame-spread planning restores every temporary transform")
	call_deferred("pause_planning")
	var cancelled: Dictionary = await planner.choose_incremental()
	check(cancelled.kind == "cancelled" and before == WorldState.capture(game),"Opening menu cancels pending AI planning without action")
	game.menu_open = false
	call_deferred("replace_config")
	cancelled = await planner.choose_incremental()
	check(cancelled.kind == "cancelled" and before == WorldState.capture(game),"Load/configuration changes invalidate pending AI decisions")
	game.ai.enabled = false
	check(first.kind in ["move","end_phase"],"Movement phase plans movement only")
	if first.has("unit"): check(NetworkAuthority.unit(game,first.unit).team == game.manager.active_team,"AI owns chosen unit")
	check(AIPlanner.probability(7) == 0 and AIPlanner.probability(3) > .66,"Probability estimate handles impossible dice")
	game.life.set_tactical(true)
	check(game.life.overlay.visible and game.life.overlay.get_child_count()>0,"Tactical view builds mechanical information")
	game.life.set_tactical(false)
	check(not game.life.overlay.visible,"Tactical view releases immediately")
	check(before == WorldState.capture(game),"Tactical overlays do not modify rules")
	game.menu_open = true
	check(game.ai.step() == "paused" and before == WorldState.capture(game),"AI pauses with menu")
	game.menu_open = false
	check(SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://ai_test.json").begins_with("Saved"),"AI match saves")
	game.ai.configure({})
	check(SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://ai_test.json").begins_with("Loaded") and game.ai.controls(1) and game.ai.config.seed == 77,"AI configuration resumes on load")
	var dice_state: int = game.dice.rng.state
	SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://ai_rng.json")
	game.dice.rng.randi()
	SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://ai_rng.json")
	check(game.dice.rng.state == dice_state,"AI save restores exact dice RNG state")
	var arena := ScenarioLibrary.read("res://resources/scenarios/ai_test_arena.json")
	check(arena.has("data"),"Generic deterministic arena validates")
	game.apply_scenario(arena.data)
	await settle()
	game.ai.configure({"teams":{"0":"Hard","1":"Hard"},"seed":77,"round_limit":3,"speed":"Fast"})
	planner = AIPlanner.new(game,"Hard",77)
	var origin := FormationPlanner.center(game.battlefield.units.get_child(0).living_models())
	var move := planner.choose()
	check(move.kind == "move" and ScenarioFactory.vector(move.anchor).distance_to(Vector3.ZERO) < origin.length(),"AI generally moves toward nearby valuable objective")
	game.manager.phase = 2
	var squad: TableUnit = game.battlefield.units.get_child(0)
	var enemy: TableUnit = game.battlefield.units.get_child(2)
	var options := AttackOptions.groups(squad,enemy,game.get_world_3d(),2)
	check(not options.is_empty(),"Arena has legal shooting lane")
	if not options.is_empty():
		var value := planner.target_value(squad,enemy,options[0])
		for model in enemy.models: model.wounds = 1
		check(planner.target_value(squad,enemy,options[0]) >= value,"Finishing wounded targets receives additional utility")
		check(AIPlanner.expected_damage(squad,enemy,options[0]) > 0,"Expected damage uses public stats without rolling")
		var count: int = game.dice.history.size()
		planner.choose()
		check(game.dice.history.size() == count,"Planning never consumes gameplay dice")
	for unit: TableUnit in game.battlefield.units.get_children():
		if unit.team == 0:
			unit.weapon_profiles = unit.weapon_profiles.duplicate(true)
			for weapon in unit.weapon_profiles: weapon.range = 0
	check(planner.choose().kind == "end_phase","No range or LOS means no attack attempt")
	game.apply_scenario(ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json").data)
	await settle()
	for seed in [7,31,77]:
		game.apply_scenario(game.initial_scenario)
		game.ai.configure({"teams":{"0":"Normal","1":"Normal"},"seed":seed,"round_limit":2,"speed":"Fast"})
		game.dice.rng.seed = seed
		var ticks := 0
		var kinds := {}
		var legal := true
		var coherent := true
		var start := Time.get_ticks_usec()
		while not game.ai.finished and ticks < 500:
			var kind: String = game.ai.step()
			kinds[kind] = int(kinds.get(kind,0))+1
			legal = legal and kind not in ["invalid","watchdog"]
			for unit: TableUnit in game.battlefield.units.get_children():
				if not unit.living_models().is_empty(): coherent = coherent and CoherencyService.is_unit_coherent(unit)
			ticks += 1
			await physics_frame
		check(legal,"All canonical decisions accepted across seeded match")
		check(coherent,"Every living squad remains coherent after AI actions")
		check(game.ai.finished and ticks < 500,"AI vs AI terminates without stalls, seed "+str(seed))
		check(kinds.get("move",0)>0 and kinds.get("attack",0)>0,"AI moves and attacks")
		check(game.manager.round_number>1,"AI advances complete rounds")
		check(game.manager.scored_rounds.size()>0,"AI match scores objectives")
		check(ActionCodec.validate(game.battle_log.entries,game.initial_scenario).is_empty(),"AI actions use replay-valid canonical records")
		var result := WorldState.capture(game)
		var events: Array = game.battle_log.entries.duplicate(true)
		var replay := ReplayController.new()
		replay.game = game
		game.add_child(replay)
		check(replay.open({"initial_scenario":game.initial_scenario,"events":events}).is_empty(),"AI replay opens")
		replay.seek(events.size())
		check(result == WorldState.capture(game),"AI replay reconstructs exact combat, positions, scores")
		game.replay_mode = false
		replay.queue_free()
		report.append({"seed":seed,"steps":ticks,"actions":kinds,"elapsed_ms":(Time.get_ticks_usec()-start)/1000.0})
	var average := 0.0
	var worst := 0.0
	for value in game.ai.planning_ms: average+=value; worst=maxf(worst,value)
	report.append({"planning_samples":game.ai.planning_ms.size(),"average_ms":average/maxi(1,game.ai.planning_ms.size()),"worst_ms":worst})
	var file := FileAccess.open("user://ai_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("AI RESULTS ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	print("GRIMTABLE AI CHECKS: ",checks,"; failures: ",failures)
	quit(1 if failures else 0)

func pause_planning() -> void:
	game.menu_open = true

func replace_config() -> void:
	game.ai.configure(game.ai.config)
