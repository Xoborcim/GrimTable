class_name WorkshopSmoke
extends Node

var app: Node
var workshop: MiniatureWorkshop
var checks:=0
var failures: Array[String]=[]
var saved_id:=""

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error("WORKSHOP SMOKE: "+label)

func capture(name: String, clean: bool=false) -> void:
	for i in 8:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image:=workshop.viewport.get_texture().get_image() if clean else get_viewport().get_texture().get_image()
	image.save_png("user://"+name+".png")

func run(application: Node) -> void:
	app=application;get_window().size=Vector2i(1440,900)
	WorkshopStore.atomic_json(WorkshopStore.ROOT+"onboarding.json",{"seen":true})
	workshop=app.show_workshop()
	await get_tree().process_frame
	if "--workshop-reload" in OS.get_cmdline_user_args():
		var records:=WorkshopStore.records()
		check(not records.is_empty(),"Collection survives application restart")
		if not records.is_empty():
			workshop.load_document(records[0]);check(workshop.document.parts.head==1,"Restart restores selected helmet")
			check(not str(workshop.document.overlay).is_empty() and WorkshopStore.image(workshop.document,"overlay")!=null,"Restart restores editable paint")
			check(not WorkshopStore.assigned(ContentRegistry.unit({"unit_id":"legion_trooper"}),"restart").is_empty(),"Restart restores local assignment")
			workshop.category="Collection";workshop.refresh_controls();await capture("10_restart_collection")
		WorkshopStore.atomic_json("user://workshop_restart.json",{"checks":checks,"failures":failures})
		print("GRIMTABLE WORKSHOP RESTART: ",checks," checks / ",failures.size()," failures");get_tree().quit(1 if not failures.is_empty() else 0);return
	check(workshop.model!=null,"Workshop opens built-in Legion")
	check(workshop.brush.positions.size()>1000,"Prepared ray mesh populated")
	await capture("01_default_legion")
	var original:=workshop.document.duplicate(true)
	workshop.document.colors.primary="8c4035";workshop.document.colors.secondary="b7c4a1"
	workshop.document.effects.wash=.6;workshop.document.effects.highlight=.7;workshop.refresh_materials();workshop.checkpoint()
	check(workshop.dirty(),"Unsaved indication")
	await capture("02_oxide_legion")
	workshop.document.colors.primary="536c57";workshop.document.colors.secondary="dfcfac";workshop.refresh_materials();workshop.checkpoint()
	await capture("03_second_scheme")
	workshop.undo();check(workshop.document.colors.primary=="8c4035","Undo region/finish edit")
	workshop.redo();check(workshop.document.colors.primary=="536c57","Redo region/finish edit")
	workshop.document.parts.head=1;workshop.document.parts.backpack=2;workshop.document.parts.shoulders=2;workshop.document.parts.weapon=1;workshop.document.parts.accessory=1
	workshop.document.pose="Heroic Display";workshop.rebuild_model();workshop.checkpoint();workshop.category="Build";workshop.refresh_controls()
	check(workshop.model.find_child("head_1",true,false).visible,"Alternate helmet visible")
	check(not workshop.model.find_child("head_0",true,false).visible,"Original helmet removed")
	await capture("04_assembled_legion")
	workshop.category="Paint";workshop.mode="Brush";workshop.refresh_controls()
	# Search visible projected armor, then send exactly the same GUI events used
	# by a mouse stroke. No texture files are prepainted for this demonstration.
	var target:=Vector2.INF
	for y in range(int(workshop.view.size.y*.35),int(workshop.view.size.y*.65),8):
		for x in range(int(workshop.view.size.x*.35),int(workshop.view.size.x*.65),8):
			var p:=Vector2(x,y)
			var hit:=workshop.brush.hit(workshop.camera.project_ray_origin(p),workshop.camera.project_ray_normal(p))
			if not hit.is_empty() and hit.paintable:target=p;break
		if target!=Vector2.INF:break
	check(target!=Vector2.INF,"Visible brush target found")
	if target!=Vector2.INF:
		var blank:=workshop.brush.image.get_data()
		var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=target
		workshop.view.gui_input.emit(press)
		for i in 6:workshop.paint_at(target+Vector2(i*5,3*sin(i*.5)))
		var release:=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=target
		workshop.view.gui_input.emit(release)
		check(workshop.brush.image.get_data()!=blank,"Actual GUI brush stroke paints")
		var painted:=workshop.brush.image.get_data();workshop.undo();check(workshop.brush.image.get_data()==blank,"Whole stroke undo")
		workshop.redo();check(workshop.brush.image.get_data()==painted,"Whole stroke redo")
	await capture("05_freehand_brush")
	if target!=Vector2.INF:
		workshop.mode="Marking";workshop.marking_kind="Diamond";workshop.marking_size=.018;workshop.place_marking(target+Vector2(15,25))
		check(not workshop.document.decals.is_empty(),"Surface marking placement")
		await capture("05b_surface_marking")
	workshop.document.parts.decoration=1;workshop.document.rim="554334";workshop.document.nameplate="WATCH 07"
	workshop.category="Base"
	for style in ["Rubble","Industrial","Stone","Ash"]:
		workshop.document.base_style=style;workshop.rebuild_model();workshop.refresh_controls();await capture("06_base_"+style.to_lower())
	workshop.title.text="Verdant Surveyor 07"
	check(workshop.save_figure(),"Save named miniature and thumbnail")
	saved_id=workshop.document.id
	var stored:=WorkshopStore.read_json(WorkshopStore.ROOT+"figures/"+saved_id+".json")
	var paint:=workshop.brush.image.get_data();workshop.load_document(stored)
	check(workshop.brush.image.get_data()==paint,"Paint restored from disk")
	check(workshop.document.parts.head==1,"Parts persisted")
	check(workshop.document.pose=="Heroic Display","Pose persisted")
	check(WorkshopStore.assign("profile","legion_trooper",saved_id),"Saved variant assigned")
	check(WorkshopStore.assign("squad","qa_squad",saved_id),"Squad assignment")
	var old_overlay: String=workshop.document.overlay
	workshop.apply_scheme_scope("squad","qa_squad")
	var scheme_target:=WorkshopStore.read_json(WorkshopStore.ROOT+"figures/"+saved_id+".json")
	check(scheme_target.overlay==old_overlay and scheme_target.parts.head==1,"Shared scheme preserves individual paint and parts")
	workshop.title.text="Oxide Collection Variant";workshop.document.colors.primary="8c4035";workshop.refresh_materials()
	for i in 4:await get_tree().process_frame
	workshop.save_as()
	check(workshop.document.id!=saved_id,"Save As New creates independent variant")
	workshop.load_document(stored)
	workshop.category="Collection";workshop.refresh_controls();await capture("07_saved_collection")
	await capture("08_studio_photo",true)
	workshop.queue_free();await get_tree().process_frame
	check(app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/iron_reliquary.json")),"Actual scenario opens")
	var game: Node3D=app.game;var snapshot:=WorldState.capture(game)
	var customized: Miniature
	for unit: TableUnit in game.battlefield.units.get_children():
		if unit.definition.id=="legion_trooper":customized=unit.models[0];break
	check(customized!=null and not customized.workshop_cosmetic.is_empty(),"Customized miniature in battle")
	if customized!=null:
		check(customized.workshop_cosmetic.id==saved_id,"Correct cosmetic identity")
		check(is_equal_approx(customized.base_radius,ContentRegistry.base_radius(customized.profile)),"Canonical gameplay radius")
		check(customized.visual_root.find_child("head_1",true,false)!=null,"Battle attachment set loaded")
		game.camera_rig.destination=customized.global_position+Vector3.UP*.6;game.camera_rig.distance=5;game.camera_rig.pitch=.5;game.camera_rig.heading=PI+.3;game.camera_rig._update_camera(1)
	for i in 12:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://09_customized_battle.png")
	check(WorldState.capture(game)==snapshot,"Cosmetic inspection leaves canonical state unchanged")
	check(SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://workshop_battle.json").begins_with("Saved"),"Customized battle save")
	check(SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://workshop_battle.json").begins_with("Loaded"),"Customized battle reload")
	check(WorldState.capture(game)==snapshot,"Battle reload retains canonical state")
	# Remove only the isolated smoke's managed record, then prove the same battle
	# still loads with authored visuals; restore it immediately afterward.
	var cosmetic_path:=WorkshopStore.ROOT+"figures/"+saved_id+".json"
	check(DirAccess.rename_absolute(cosmetic_path,cosmetic_path+".unavailable")==OK,"Temporarily missing cosmetic fixture")
	WorkshopStore.variants_cache.clear()
	check(SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://workshop_battle.json").begins_with("Loaded"),"Missing cosmetic cannot prevent game loading")
	check(WorldState.capture(game)==snapshot,"Missing cosmetic preserves canonical state")
	DirAccess.rename_absolute(cosmetic_path+".unavailable",cosmetic_path);WorkshopStore.variants_cache.clear()
	var replay:=ReplayController.new();replay.game=game;game.add_child(replay)
	check(replay.open({"initial_scenario":game.initial_scenario.duplicate(true),"events":[]}).is_empty(),"Replay opens with optional local appearances")
	var result:={"checks":checks,"failures":failures,"version":ProjectSettings.get_setting("application/config/version"),"figure":saved_id,"texture_memory_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	WorkshopStore.atomic_json("user://workshop_result.json",result)
	print("GRIMTABLE WORKSHOP SMOKE: ",checks," checks / ",failures.size()," failures")
	get_tree().quit(1 if not failures.is_empty() else 0)
