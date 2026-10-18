extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("FAIL "+label)
func run() -> void:
	var games: Array[Node3D]=[]
	var sessions: Array[NetworkSession]=[]
	var transports: Array[ENetTransport]=[]
	for i in 2:
		var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
		game.scenario=ScenarioLibrary.read("res://resources/scenarios/ashen_basilica.json").data
		game.settings=AppSettings.new(); game.settings.autosave=false; game.settings.dice_volume=0
		root.add_child(game); games.append(game)
		var transport:=ENetTransport.new()
		root.add_child(transport); transports.append(transport)
		check(transport.open(i==0,"127.0.0.1",17911)==OK,"Open local ENet peer")
		var session:=NetworkSession.new()
		root.add_child(session); sessions.append(session)
		session.open(transport,game)
	var deadline:=Time.get_ticks_msec()+5000
	while (not sessions[1].started or not sessions[0].session_ready) and Time.get_ticks_msec()<deadline: await create_timer(.01).timeout
	check(sessions[0].session_ready and sessions[1].started,"0.11.0 peers accept compatibility and snapshot")
	games[0].dice.rng.seed=42
	games[1].dice.roll(8)
	deadline=Time.get_ticks_msec()+4000
	while games[1].dice.history.is_empty() and Time.get_ticks_msec()<deadline: await create_timer(.01).timeout
	check(not games[0].dice.history.is_empty() and not games[1].dice.history.is_empty(),"Guest public request reaches host")
	if not games[1].dice.history.is_empty():
		var canonical: Array=games[0].dice.history[0].values.map(func(value): return int(value))
		check(canonical==games[1].dice.history[0].values.map(func(value): return int(value)),"Host and client receive identical canonical rolls")
		for game in games:
			game.dice_tray.skip()
			check(game.dice_tray.current.get("values",[]).map(func(value): return int(value))==canonical,"Local animation uses exact host pool")
			for die in game.dice_tray.dice: check(CinematicDie.top_face(die.basis)==die.result,"Peer final face matches host")
		check(games[1].dice_tray.queue.is_empty(),"Canonical event and snapshot animate exactly once")
		var serial: int=games[1].dice_tray.roll_serial
		sessions[1]._restore_dice(games[1].dice.history.duplicate(true))
		check(serial==games[1].dice_tray.roll_serial and games[1].dice_tray.queue.is_empty(),"UI refresh does not replay stale dice")
	for session in sessions: session.detach(); session.queue_free()
	for transport in transports: transport.queue_free()
	for game in games: game.queue_free()
	await process_frame
	print("GRIMTABLE DICE PEERS: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
