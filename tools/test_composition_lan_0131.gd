extends SceneTree
var checks:=0
var failures:=0
var session: NetworkSession
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("COMPOSITION LAN "+label)
func until(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+20000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await create_timer(.05).timeout
	return predicate.call()
func run() -> void:
	var host_role: bool="--host" in OS.get_cmdline_user_args()
	var game: Node3D=load("res://scenes/main/main.tscn").instantiate()
	game.settings=AppSettings.new();game.settings.autosave=false;game.settings.cinematic_dice="Off"
	game.scenario=ScenarioLibrary.read(ScenarioLibrary.FLAGSHIP if host_role else "res://resources/scenarios/demo.json").data
	root.add_child(game)
	var transport:=ENetTransport.new();root.add_child(transport)
	check(transport.open(host_role,"127.0.0.1",17831)==OK,"Local ENet opens")
	session=NetworkSession.new();session.name="CompositionSession";root.add_child(session);session.open(transport,game)
	check(await until(func():return session.session_ready and (host_role or session.started)),"Matching build handshake and map snapshot")
	if failures==0:
		if host_role:
			await create_timer(.5).timeout
			game.dice.rng.seed=131;game.dice.roll(5)
		else:check(await until(func():return game.dice.history.size()==1),"Canonical dice event arrives")
		await create_timer(.7).timeout
		check(game.scenario.id=="hollow_basilica","Flagship synchronized")
		var nave: TerrainPiece=game.battlefield.terrain.get_node("nave")
		check(nave.footprint_parts.size()==9,"Compound footprint serialized over ENet")
		check(not nave.path_touches(nave.to_global(Vector3(-10,0,0)),nave.to_global(Vector3(-6.7,0,0)),.55),"Canonical breach stays passable")
		check(nave.path_touches(nave.to_global(Vector3(-7,0,-8)),nave.to_global(Vector3(-7,0,-4)),.55),"Canonical wall stays blocking")
	var result:={"role":"host" if host_role else "guest","checks":checks,"failures":failures,"version":NetworkCompatibility.GAME_VERSION,"hash":NetworkSession.state_hash(WorldState.capture(game)),"dice":game.dice.history,"parts":ScenarioFactory.capture(game).terrain[0].get("footprint_parts",[])}
	var file:=FileAccess.open("user://composition_lan_0131.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("GRIMTABLE COMPOSITION LAN ",result.role,": ",checks," checks / ",failures," failures")
	# Let both peers finish their assertions before closing the connection.
	await create_timer(.8).timeout
	quit(1 if failures else 0)
