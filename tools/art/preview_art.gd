extends SceneTree

var stage: Node3D
var camera: Camera3D

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size=Vector2i(1000,1000)
	stage=Node3D.new(); root.add_child(stage)
	var settings:=AppSettings.new(); settings.quality="High"
	BattlefieldPresentation.lighting(stage,settings)
	var plane:=PlaneMesh.new(); plane.size=Vector2(20,20)
	var floor_mesh:=TableVisuals.mesh(stage,plane,Vector3(0,-.17,0),Color("41494e"))
	floor_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base:=CylinderMesh.new()
	base.top_radius=.60; base.bottom_radius=.63; base.height=.16
	TableVisuals.mesh(stage,base,Vector3(0,-.08,0),Color("242b2e"))
	camera=Camera3D.new(); stage.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2.8
	camera.position=Vector3(2.5,2.1,-3.7); camera.look_at(Vector3(0,.85,0))
	for version in ["before","after"]:
		var sculpt: Node3D
		if version=="before": sculpt=load("res://assets/grimtable/models/legion_trooper.tscn").instantiate()
		else:
			var doc:=GLTFDocument.new(); var state:=GLTFState.new()
			if doc.append_from_file("res://assets/miniatures/legion/legion_infantry.glb",state)!=OK: quit(1); return
			sculpt=doc.generate_scene(state)
		stage.add_child(sculpt)
		for i in 5: await process_frame
		for item in [["hero",Vector3(2.5,2.1,-3.7)],["front",Vector3(0,1,-4)],["tactical",Vector3(5,9,-8)]]:
			camera.position=item[1]; camera.look_at(Vector3(0,.85,0))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/art/comparisons/infantry_godot_"+version+"_"+item[0]+".png")
		stage.remove_child(sculpt); sculpt.free()
	stage.queue_free(); await process_frame
	print("GRIMTABLE ART REFERENCE CAPTURE PASS")
	quit()
