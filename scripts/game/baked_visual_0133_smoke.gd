class_name BakedVisual133Smoke
extends Node

var app: Node
var phase:="after"
var checks:=0
var failures: Array[String]=[]

func release_game() -> void:
	# App.clear_game cancels an interaction and removes its board immediately.
	# Let that cancellation's queued spatial refresh settle while still mounted.
	if is_instance_valid(app.game):
		app.game.interaction.cancel()
		for i in 3:
			await get_tree().physics_frame
			await get_tree().process_frame
		# Keep this smoke's second cancellation from starting another refresh.
		app.game.battlefield._physics_refresh_pending=true

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error("BAKED VISUAL: "+label)

func capture(name: String) -> void:
	for i in 12:await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://"+name+"_"+phase+".png")

func run(application: Node) -> void:
	app=application
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baked-phase="):phase=arg.trim_prefix("--baked-phase=")
	get_window().size=Vector2i(1440,900)
	app.settings.autosave=false;app.settings.cinematic_dice="Off";app.settings.dice_volume=0
	app.settings.quality="Medium";app.settings.camera_assistance=false;app.settings.combat_camera=false
	app.settings.assistance="Tabletop";app.settings.reduce_motion=true
	for id in ["hollow_basilica","ashfall_station"]:
		await release_game()
		check(app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/"+id+".json")),"Map opens "+id)
		var game: Node3D=app.game
		game.interaction.pointer=Vector2(-2000,-2000)
		game.camera_rig.distance=53;game.camera_rig.pitch=.92;game.camera_rig.heading=.08
		game.camera_rig.destination=Vector3(0,.5,-2);game.camera_rig._update_camera(1)
		if phase=="after":
			var baked_count:=0
			for mesh: MeshInstance3D in game.battlefield.terrain.find_children("*","MeshInstance3D",true,false):
				var material:=mesh.material_override as ShaderMaterial
				if material!=null and material.shader==preload("res://assets/grimtable/materials/baked_finish.gdshader"):baked_count+=1
			check(baked_count>=8,"Packaged environment bakes loaded "+id)
		await capture(id+"_gameplay")
		if id=="hollow_basilica":
			game.hud.hide()
			game.camera_rig.distance=17;game.camera_rig.pitch=.78
			game.camera_rig.destination=Vector3(-14,.4,5);game.camera_rig._update_camera(1)
			await capture("basilica_transition")
			game.camera_rig.distance=23;game.camera_rig.pitch=.55
			game.camera_rig.destination=Vector3(-14,4,-8);game.camera_rig._update_camera(1)
			await capture("basilica_architecture")
	await release_game()
	check(app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/iron_reliquary.json")),"Miniature showcase opens")
	var game: Node3D=app.game
	for unit: TableUnit in game.battlefield.units.get_children():
		var id: String=unit.definition.id
		if not id in ["legion_trooper","legion_walker","swarm_hunter"]:continue
		var state:=WorldState.capture(game)
		var inspector:=MiniatureInspector.new();inspector.game=game;inspector.model=unit.models[0]
		game.add_child(inspector)
		inspector.yaw=PI+.5;inspector.pitch=.20;inspector.distance*=.72;inspector.update_camera(1)
		await capture(id+"_inspection")
		if phase=="after":
			var studio:=inspector.camera.get_parent()
			var sun:=studio.get_node("KeyLight") as DirectionalLight3D
			var environment: Environment=studio.get_node("TableEnvironment").environment
			sun.light_energy=1.65;environment.ambient_light_energy=.42
			await capture(id+"_bright")
			sun.light_energy=.55;environment.ambient_light_energy=.16
			await capture(id+"_dark")
			sun.light_energy=1.15;environment.ambient_light_energy=.26
			inspector.yaw=0;inspector.update_camera(1)
			await capture(id+"_rear_seams")
			inspector.yaw=PI+.5;inspector.update_camera(1)
			if id=="legion_trooper":
				for mesh: MeshInstance3D in studio.find_children("*","MeshInstance3D",true,false):
					var original:=mesh.material_override as ShaderMaterial
					if original==null or original.shader!=preload("res://assets/grimtable/materials/baked_finish.gdshader"):continue
					var recolor:=original.duplicate() as ShaderMaterial
					recolor.set_shader_parameter("primary_paint",Color("8c4035"));recolor.set_shader_parameter("secondary_paint",Color("b7c4a1"))
					mesh.material_override=recolor
					for parameter in ["normal_tex","orm","finish_mask","paint_regions"]:
						check(recolor.get_shader_parameter(parameter)==original.get_shader_parameter(parameter),"Recolor preserves "+parameter)
				await capture("legion_recolor")
		inspector.close();await get_tree().process_frame
		check(WorldState.capture(game)==state,"Inspection preserves state "+id)
	var result:={"version":ProjectSettings.get_setting("application/config/version"),"phase":phase,"checks":checks,"failures":failures}
	result["texture_memory_bytes"]=Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	result["video_memory_bytes"]=Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	var file:=FileAccess.open("user://baked_0133_result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("GRIMTABLE BAKED VISUAL: ",checks," checks / ",failures.size()," failures / ",phase)
	get_tree().quit(1 if not failures.is_empty() else 0)
