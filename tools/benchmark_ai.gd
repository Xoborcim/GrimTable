extends SceneTree

var reports: Array = []
func _initialize() -> void: call_deferred("run")

func setup(count: int) -> Dictionary:
	var data: Dictionary = ScenarioLibrary.read("res://resources/scenarios/ai_test_arena.json").data.duplicate(true)
	data.board = {"width":100,"depth":80,"theme":"industrial"}
	data.armies = []
	for team in [0,1]:
		for index in ceili(count/10.0):
			var unit := {"id":"bench_%d_%d" % [team,index],"name":"Benchmark Squad","team":team,"unit_id":"legion_trooper" if index%2==0 else "swarm_hunter","models":[]}
			for j in 5: unit.models.append({"id":"bm_%d_%d_%d" % [team,index,j],"position":[-34+(index%8)*9+(j%3)*1.7,0,(8+floori(index/8.0)*7+(j/3)*1.7)*(1 if team==0 else -1)],"rotation":0})
			data.armies.append(unit)
	return data

func run() -> void:
	var incremental := "--incremental" in OS.get_cmdline_user_args()
	for size in [10,40,100]:
		var game: Node3D = load("res://scenes/main/main.tscn").instantiate()
		game.settings = AppSettings.new()
		game.settings.autosave = false
		game.settings.camera_assistance = false
		game.settings.reduce_motion = true
		game.scenario = setup(size)
		root.add_child(game)
		game.ai.enabled = incremental
		game.ai.set_process(false)
		game.ai.configure({"teams":{"0":"Normal","1":"Normal"},"seed":121,"round_limit":2,"speed":"Fast"})
		game.dice.rng.seed = 121
		await physics_frame
		var start := Time.get_ticks_usec()
		var steps := 0
		var candidate_worst := 0.0
		while game.manager.active_team == 0 and not game.ai.finished and steps<512:
			if incremental: await game.ai.runtime_step()
			else: game.ai.step()
			if game.ai.planner != null:
				for value in game.ai.planner.candidate_ms: candidate_worst = maxf(candidate_worst,value)
			steps += 1
			await physics_frame
		var elapsed := (Time.get_ticks_usec()-start)/1000.0
		var sum := 0.0
		var worst := 0.0
		for value in game.ai.planning_ms: sum+=value;worst=maxf(worst,value)
		var report := {"models":size,"decisions":game.ai.planning_ms.size(),"steps":steps,"average_decision_ms":sum/maxi(1,game.ai.planning_ms.size()),"worst_decision_ms":worst,"worst_candidate_ms":candidate_worst,"full_turn_no_presentation_ms":elapsed,"finished":game.ai.finished}
		reports.append(report)
		print("AI BENCHMARK ",JSON.stringify(report))
		game.queue_free()
		for i in 4: await process_frame
	var output := {"cpu":OS.get_processor_name(),"godot":Engine.get_version_info().string,"mode":"headless, Normal, frame-spread runtime planning" if incremental else "headless, Normal, synchronous reference; includes physics waits","results":reports}
	var file := FileAccess.open("res://docs/benchmarks/ai_runtime_0100.json" if incremental else "res://docs/benchmarks/ai_0100.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	quit()
