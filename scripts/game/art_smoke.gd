class_name ArtSmoke
extends Node

var checks:=0
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error("ART SMOKE: "+label)
func settle() -> void:
	for i in 6: await get_tree().process_frame
	await get_tree().physics_frame
func capture(name: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://"+name+"_0120.png")
func inspect(game: Node3D,model: Miniature,name: String) -> void:
	var before:=WorldState.capture(game)
	var inspector:=MiniatureInspector.new()
	inspector.game=game; inspector.model=model
	game.add_child(inspector)
	await get_tree().create_timer(.5).timeout
	check(game.interaction.read_only and game.menu_open,"Inspection blocks game input")
	var key:=InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=true
	get_viewport().push_input(key)
	await capture(name)
	inspector.close(); await settle()
	check(WorldState.capture(game)==before and not game.menu_open,"Inspection preserves state and returns to table")
func run(app: Node) -> void:
	app.settings.autosave=false
	app.settings.cinematic_dice="Quick"
	app.settings.dice_volume=0
	await get_tree().create_timer(.3).timeout
	await capture("art_menu")
	check(app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/iron_reliquary.json")),"Art showcase opens")
	var game: Node3D=app.game
	game.camera_rig.distance=34
	game.camera_rig.destination=Vector3(-2,0,-1)
	game.camera_rig._update_camera(1)
	await get_tree().create_timer(.5).timeout
	game.guidance.hint_card.hide()
	await capture("art_tabletop")
	game.hud.hide()
	await capture("art_tabletop_clean")
	game.hud.show()
	for unit: TableUnit in game.battlefield.units.get_children():
		var model: Miniature=unit.models[0]
		check(model.visual_root.get_child(0).has_meta("authored_art"),"Blender artwork on "+str(unit.definition.id))
		check(is_equal_approx(model.base_radius,ContentRegistry.base_radius(unit.definition)),"Canonical base retained")
		check(model.has_node("ScenicBaseGround"),"Detailed base geometry")
		await inspect(game,model,"art_inspect_"+str(unit.definition.id))
	var before_camera: Array=[game.camera_rig.destination,game.camera_rig.distance,game.camera_rig.heading,game.camera_rig.pitch]
	game.camera_rig.destination=Vector3(-8,3,-7)
	game.camera_rig.distance=22
	game.camera_rig._update_camera(1)
	game.hud.hide()
	await capture("art_basilica_gameplay")
	game.hud.show()
	game.camera_rig.destination=before_camera[0]; game.camera_rig.distance=before_camera[1]
	game.camera_rig.heading=before_camera[2]; game.camera_rig.pitch=before_camera[3]
	game.camera_rig._update_camera(1)
	if "--art-capture-only" in OS.get_cmdline_user_args(): finish(); return
	game.ai.configure({"teams":{"0":"Easy","1":"Easy"},"human_team":0,"seed":77,"round_limit":1,"speed":"Fast"})
	game.ai.set_process(false)
	var ticks:=0
	while not game.ai.finished and ticks<200:
		await game.ai.runtime_step()
		ticks+=1
		await get_tree().physics_frame
	check(game.ai.finished and game.ai.invalid_actions==0,"One legal AI round with new art")
	var attacks: Array=game.battle_log.entries.filter(func(entry): return entry.kind=="attack")
	check(not attacks.is_empty(),"Combat exercised")
	game.dice_tray.cancel()
	game.dice_tray.enqueue("ART PASS / CANONICAL D6",[6,4,2,5,1],4)
	game.dice_tray.skip()
	for die in game.dice_tray.dice: check(CinematicDie.top_face(die.basis)==die.result,"Dice unaffected by art pass")
	game.dice_tray.cancel()
	var before_save:=WorldState.capture(game)
	check(SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://art_0120_save.json").begins_with("Saved"),"Packaged save")
	check(SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://art_0120_save.json").begins_with("Loaded") and WorldState.capture(game)==before_save,"Exact packaged load")
	var replay:=ReplayController.new()
	replay.game=game; game.add_child(replay)
	check(replay.open({"initial_scenario":game.initial_scenario,"events":game.battle_log.entries.duplicate(true)}).is_empty(),"Art battle replay opens")
	replay.seek(replay.events.size())
	check(WorldState.capture(game)==before_save,"Exact replay with cosmetic art")
	finish()

func finish() -> void:
	var report:={"checks":checks,"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"features":["new_meshes","scenic_bases","inspection","canonical_bases","AI_combat","save_load","replay"]}
	var file:=FileAccess.open("user://art_0120_smoke_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("GRIMTABLE ART PACKAGED: ",checks," checks / ",failures.size()," failures")
	get_tree().quit(1 if not failures.is_empty() else 0)
