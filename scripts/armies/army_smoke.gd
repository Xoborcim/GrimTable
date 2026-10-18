class_name ArmySmoke
extends Node

var app: Node
var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error("ARMY SMOKE: "+label)
func capture(name: String) -> void:
	for i in 10:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://"+name+".png")

func run_hud(application: Node) -> void:
	app=application;get_window().size=Vector2i(1440,900);app.settings.autosave=false;app.settings.reduce_motion=true
	check(app.load_slot("user://army_smoke_battle.json"),"Restore packaged fixture for focused HUD check")
	var game: Node3D=app.game;game.ai.enabled=false
	check(game.battle_desk.bar.get_parent() is HBoxContainer,"Mission controls share the existing header row")
	game.battle_desk.toggle("Missions");await capture("06_mission_cards")
	game.battle_desk.toggle("Roster");await capture("07_army_roster")
	check(game.battle_desk.bar.global_position.y<75,"Header controls do not overlap timeline or tutorial")
	WorkshopStore.atomic_json("user://army_hud_correction_result.json",{"checks":checks,"failures":failures})
	print("GRIMTABLE ARMY HUD ",checks," checks / ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func run(application: Node) -> void:
	app=application;get_window().size=Vector2i(1440,900);app.settings.autosave=false;app.settings.reduce_motion=true
	var builder: ArmyBuilder=app.show_army_builder()
	var lists:=ArmyRoster.records()
	var army: Dictionary=lists.filter(func(a):return a.id=="army_starter_legion_2000")[0].duplicate(true)
	army.name="Azure Expedition — custom 2,000";army.units[1].upgrades={"legion_cannon":1}
	builder.army=army;builder.selected=1;builder.dirty=true;builder.refresh()
	check(ArmyRoster.total(army)==2000,"Configured 2,000-point army has exact running total")
	check(ArmyRoster.errors(army).is_empty(),"Editor army is legal")
	builder.save_army();check(not builder.dirty,"Army saved from editor")
	await capture("01_army_builder")
	var found:=false
	for record in ArmyRoster.records(false):
		if record.id==army.id:found=true
	check(found,"Saved army appears in persistent collection")
	check(WorkshopStore.atomic_json("user://qa_army_export.json",army),"Safe JSON army export")
	check(ArmyRoster.import_file("user://qa_army_export.json").has("data"),"Army import round trip")
	builder.queue_free();await get_tree().process_frame
	var editor_ui: HomebrewEditor=app.show_homebrew()
	editor_ui.document.factions[0].name="The Meridian Survey";editor_ui.document.manifest.name="Meridian Survey"
	editor_ui.document.units[1].name="Survey Wardens"
	editor_ui.category="Unit";editor_ui.selected=1;editor_ui.refresh();await capture("02_custom_unit")
	editor_ui.document.weapons.append(HomebrewPack.weapon(editor_ui.document));editor_ui.document.weapons[0].name="Survey Lance";editor_ui.document.weapons[0].tags=["anti_heavy"]
	editor_ui.category="Weapon";editor_ui.selected=0;editor_ui.refresh();await capture("03_custom_weapon")
	check(HomebrewPack.validate(editor_ui.document).is_empty(),"Editor-created homebrew profiles validate")
	check(HomebrewPack.install(editor_ui.document).begins_with("Installed"),"Player-created faction installs as content pack")
	editor_ui.queue_free();await get_tree().process_frame
	app.show_army_battle();await capture("04_battle_setup")
	var enemy: Dictionary=lists.filter(func(a):return a.id=="army_starter_swarm_2000")[0]
	var map: Dictionary=ScenarioLibrary.read("res://resources/scenarios/hollow_basilica.json").data
	var battle:=ArmyRoster.scenario(map,[army,enemy],90,44)
	battle.data.starting_state["missions"]=MissionRules.initial("control",true,15015)
	app.pending_ai={"teams":{"1":"Normal"},"human_team":0,"seed":15015,"round_limit":6,"speed":"Fast"}
	check(app.launch_scenario(battle),"Saved custom armies launch in the packaged game")
	var game: Node3D=app.game;game.ai.enabled=false
	var issue:=AssistanceService.execute(game,"auto_deploy",{},0)
	check(issue.is_empty() and game.deployment.validation_error().is_empty(),"Auto Deploy places complete 2,000-point armies legally")
	game.camera_rig.distance=68;game.camera_rig._update_camera(1)
	await capture("05_full_army_deployment")
	check(game.start_game(),"Deployment ready starts the battle")
	game.battle_desk.toggle("Missions")
	await capture("06_mission_cards")
	game.battle_desk.toggle("Roster");await capture("07_army_roster")
	check(game.manager.missions.teams["0"].active.size()==2,"Actual mission cards drawn")
	check(SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://army_smoke_battle.json").begins_with("Saved"),"Configured battle save")
	var state:=WorldState.capture(game)
	check(SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://army_smoke_battle.json").begins_with("Loaded"),"Configured battle reload")
	check(NetworkSession.state_hash(state)==NetworkSession.state_hash(WorldState.capture(game)),"Reload preserves canonical army and mission state")
	var replay:=ReplayController.new();replay.game=game;game.add_child(replay)
	var events: Array=game.battle_log.entries.duplicate(true)
	check(replay.open({"initial_scenario":game.initial_scenario,"events":events}).is_empty(),"Replay accepts configured deployment and missions")
	replay.seek(events.size())
	check(NetworkSession.state_hash(state)==NetworkSession.state_hash(WorldState.capture(game)),"Replay reproduces the packaged battle state")
	WorkshopStore.atomic_json("user://army_smoke_result.json",{"version":ProjectSettings.get_setting("application/config/version"),"checks":checks,"failures":failures,"army_id":army.id,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	print("GRIMTABLE ARMY SMOKE ",checks," checks / ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
