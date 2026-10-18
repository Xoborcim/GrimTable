extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL "+label)
func run() -> void:
	for value in 6:
		check(CinematicDie.top_face(Basis(CinematicDie.final_rotation(value+1))) == value+1,"Face "+str(value+1))
	var tray := DiceTray.new()
	tray.settings = AppSettings.new()
	tray.settings.dice_volume = 0
	root.add_child(tray)
	for mode in ["Quick","Full"]:
		tray.settings.cinematic_dice = mode
		var original := [6,6,6,1,1,2,3,4,5]
		tray.enqueue("HOST / REPLAY",original,4)
		await create_timer(.25).timeout
		check(tray.dice[0].angular_velocity.length() > 0,"Physical tumble "+mode)
		tray.skip()
		for i in original.size(): check(CinematicDie.top_face(tray.dice[i].basis) == original[i],"Exact canonical repeated face")
		check(original == tray.current.values,"Input arrays preserved")
		tray.cancel()
	tray.settings.cinematic_dice = "Off"
	tray.enqueue("OFF",[1],4)
	check(tray.phase.is_empty(),"Off skips presentation")
	tray.settings.cinematic_dice = "Quick"
	var large: Array = []
	large.resize(100); large.fill(6)
	tray.enqueue("LARGE",large,4)
	check(tray.dice.size() == 12 and tray.current.values.size() == 100,"Capped physics retains complete pool")
	tray.cancel(); tray.queue_free()
	await process_frame
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
	game.scenario=ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json").data
	game.settings=AppSettings.new(); game.settings.autosave=false; game.settings.dice_volume=0
	root.add_child(game)
	await physics_frame
	game.manager.phase=2
	var attacker: TableUnit=game.battlefield.units.get_child(0)
	var defender: TableUnit=game.battlefield.units.get_child(3)
	game.dice.rng.seed=42
	check(game.combat.resolve(attacker,defender,game.get_world_3d(),0),"Canonical combat resolves")
	if game.combat.current != null:
		var rng_state: int=game.dice.rng.state
		var canonical: Dictionary=game.combat.current.result
		check(game.dice_tray.current.values==canonical.hit_rolls,"Combat hits automatically use canonical array")
		game.dice_tray.skip()
		check(game.dice.rng.state==rng_state,"Cosmetic physics consumes no gameplay RNG")
		var client: Node3D=load("res://scenes/main/main.tscn").instantiate()
		client.scenario=game.initial_scenario.duplicate(true)
		client.settings=AppSettings.new(); client.settings.autosave=false; client.settings.dice_volume=0
		root.add_child(client)
		var replay:=ReplayController.new()
		replay.game=client; client.add_child(replay)
		check(replay.open({"initial_scenario":game.initial_scenario,"events":game.battle_log.entries.duplicate(true)}).is_empty(),"Recorded combat opens in replay")
		replay.seek(replay.events.size())
		check(client.dice_tray.current.get("values",[])==canonical.hit_rolls,"Replay uses recorded hits")
		client.dice_tray.skip()
		for die in client.dice_tray.dice: check(CinematicDie.top_face(die.basis)==die.result,"Replayed face equals authoritative face")
		client.queue_free()
	game.queue_free(); await process_frame
	print("GRIMTABLE CINEMATIC: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
