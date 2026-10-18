class_name TerrainPalettePreview
extends SubViewportContainer

var viewport: SubViewport
var stage: Node3D
var art: Node3D
var camera: Camera3D

func _ready() -> void:
	custom_minimum_size=Vector2(280,156);stretch=true;mouse_filter=Control.MOUSE_FILTER_IGNORE
	viewport=SubViewport.new();viewport.size=Vector2i(420,230);viewport.own_world_3d=true
	viewport.handle_input_locally=false;viewport.render_target_update_mode=SubViewport.UPDATE_ONCE;add_child(viewport)
	stage=Node3D.new();viewport.add_child(stage)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-45,-35,0);key.light_energy=1.5;stage.add_child(key)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("253039");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("b7c6cc");env.environment.ambient_light_energy=.6;stage.add_child(env)
	camera=Camera3D.new();camera.fov=42;stage.add_child(camera)

func show_piece(palette: Dictionary) -> void:
	if viewport==null:return
	if is_instance_valid(art):stage.remove_child(art);art.queue_free()
	art=Node3D.new();stage.add_child(art)
	var size:=ScenarioFactory.vector(palette.size)
	if palette.has("visual_scene"):
		var scene:=load(palette.visual_scene) as PackedScene
		if scene!=null:art.add_child(scene.instantiate());EnvironmentArt.weather_visual(art,0)
	elif palette.get("art_style","")!="":
		var probe:=TerrainPiece.new();probe.size=size;probe.kind=palette.kind;probe.art_style=palette.art_style;probe.object_id="palette"
		var sculpt:=AuthoredArt.terrain(probe.kind,probe.art_style,size)
		if sculpt!=null:art.add_child(sculpt)
		else:
			MonumentalTerrain.add(probe)
			for child in probe.get_children():probe.remove_child(child);art.add_child(child)
		probe.free()
	else:TableVisuals.box(art,size,Vector3.UP*size.y/2,Color("777f78"))
	var distance:=maxf(size.x,maxf(size.y,size.z))*1.8+2
	camera.position=Vector3(distance*.55,size.y*.45+distance*.48,distance*.75)
	camera.look_at(Vector3(0,size.y*.45,0))
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
