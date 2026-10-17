class_name BattlefieldPresentation
extends RefCounted

const THEMES := {
	"industrial": [Color("303b43"), Color("647a85")],
	"desert": [Color("897057"), Color("b49b72")],
	"alien": [Color("413c59"), Color("779184")]
}

static func ground(theme: String) -> ShaderMaterial:
	var palette: Array = THEMES.get(theme, THEMES.industrial)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/grimtable/materials/battlefield.gdshader")
	material.set_shader_parameter("ground", palette[0])
	material.set_shader_parameter("seam", palette[1])
	material.set_shader_parameter("industrial", 1.0 if theme == "industrial" else 0.0)
	return material

static func lighting(parent: Node3D, settings: AppSettings) -> void:
	var environment := WorldEnvironment.new()
	environment.name = "TableEnvironment"
	var light := Environment.new()
	light.background_mode = Environment.BG_COLOR
	light.background_color = Color("0b111c")
	light.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	light.ambient_light_color = Color("afc8e0")
	light.ambient_light_energy = 0.26
	light.tonemap_mode = Environment.TONE_MAPPER_ACES
	var sky := Sky.new()
	var sky_paint := ProceduralSkyMaterial.new()
	sky_paint.sky_top_color = Color("263b50")
	sky_paint.sky_horizon_color = Color("a8b1ac")
	sky_paint.ground_bottom_color = Color("242628")
	sky_paint.ground_horizon_color = Color("7c827d")
	sky.sky_material = sky_paint
	light.sky = sky
	light.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	light.fog_enabled = settings.quality != "Low"
	light.fog_light_color = Color("293b45")
	light.fog_density = .0015
	environment.environment = light
	parent.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(-42, -28, 0)
	sun.light_color = Color("ffe3bd")
	sun.light_energy = 1.15
	sun.directional_shadow_max_distance = 100
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = .10
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-32, 135, 0)
	fill.light_color = Color("8bbbdc")
	fill.light_energy = 0.22
	parent.add_child(fill)
	for item in [[Vector3(-10,8,7),Color("c7dbe2"),1.15],[Vector3(8,7,-7),Color("e4ccb1"),.9]]:
		var pool := OmniLight3D.new()
		pool.position = item[0]
		pool.light_color = item[1]
		pool.light_energy = item[2]
		pool.omni_range = 19
		pool.omni_attenuation = 1.7
		parent.add_child(pool)
	apply_quality(parent, settings)

static func apply_quality(parent: Node3D, settings: AppSettings) -> void:
	var sun := parent.get_node_or_null("KeyLight") as DirectionalLight3D
	if sun != null: sun.shadow_enabled = settings.quality != "Low"
	var world := parent.get_node_or_null("TableEnvironment") as WorldEnvironment
	if world != null:
		var advanced := RenderingServer.get_current_rendering_method() == "forward_plus"
		world.environment.ssao_enabled = advanced and settings.quality == "High"
		world.environment.ssao_radius = .8
		world.environment.ssao_intensity = 1.0
		world.environment.glow_enabled = advanced and settings.quality == "High"
		world.environment.fog_enabled = settings.quality != "Low"
	parent.get_viewport().msaa_3d = Viewport.MSAA_DISABLED if settings.quality == "Low" else (Viewport.MSAA_4X if settings.quality == "High" else Viewport.MSAA_2X)

static func decorate(board: Battlefield) -> void:
	table_surround(board)
	if board.scenario.id != "ashfall_station": return
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/grimtable/materials/decorative_props.json"))
	var folder: String = art.source_directory
	var placements := [
		["container-tall", Vector3(-20, 0, -13), 2.4],
		["container-wide", Vector3(-17, 0, -13), 2.4],
		["container-flat", Vector3(19, 0, 13), 2.6],
		["container", Vector3(22, 0, 13), 2.6],
		["pipe", Vector3(-23, 0, -1), 3.0],
		["pipe-bend", Vector3(-23, 0, 3), 3.0],
		["rocks", Vector3(22, 0, -14), 2.5],
		["rocks", Vector3(-21, 0, 13), 2.0]]
	placements.append_array([
		["computer-wide",Vector3(-26,0,12),2.2],
		["structure-barrier-high",Vector3(26,0,8),2.1],
		["pipe-ring-colored",Vector3(26,0,-7),2.5],
		["container-flat-open",Vector3(-26,0,8),2.0],
		["stairs-handrail",Vector3(26,0,17),2.0]])
	for item in placements:
		var path: String = folder + item[0] + ".glb"
		if not ResourceLoader.exists(path): continue
		var resource := load(path) as PackedScene
		if resource == null: continue
		var prop := resource.instantiate() as Node3D
		prop.name = "Decorative_" + item[0]
		prop.position = item[1]
		prop.scale = Vector3.ONE * item[2]
		board.visuals.add_child(prop)
		cosmetic_only(prop)
	LivingAtmosphere.add(board)
	# Low landing lamps and painted hazard strips frame the objective lanes.
	for side in [-1, 1]:
		for x in [-24, -18, 18, 24]:
			TableVisuals.box(board.visuals, Vector3(.6, .12, .25), Vector3(x, .06, side * 18), Color("25343e"))
			var lamp := TableVisuals.box(board.visuals, Vector3(.38, .025, .14), Vector3(x, .13, side * 18), Color("80b5be"))
			lamp.material_override = TableVisuals.material(Color("80b5be"), true)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func cosmetic_only(node: Node) -> void:
	if node is CollisionObject3D: node.collision_layer = 0; node.collision_mask = 0
	if node is GeometryInstance3D: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is MeshInstance3D:
		var paint := TableVisuals.material(Color("3e535b"))
		paint.metallic = .25
		node.material_override = paint
	for child in node.get_children(): cosmetic_only(child)


static func table_surround(board: Battlefield) -> void:
	var width := board.width
	var depth := board.depth
	# Physical exhibition table, separate from every gameplay collider.
	TableVisuals.box(board.visuals,Vector3(width+5,1.1,depth+5),Vector3(0,-1.1,0),Color("17252e"))
	TableVisuals.box(board.visuals,Vector3(width+4.7,.12,depth+4.7),Vector3(0,-.48,0),Color("35434a"))
	TableVisuals.box(board.visuals,Vector3(width+3.9,.10,depth+3.9),Vector3(0,-.39,0),Color("1e2c31"))
	var floor := TableVisuals.box(board.visuals,Vector3(240,.2,240),Vector3(0,-3.5,0),Color("111c23"))
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1,1]:
		TableVisuals.box(board.visuals,Vector3(width+1,.18,.35),Vector3(0,.03,side*(depth/2+.35)),Color("3c494c"))
		for x in [-width/2,width/2]:
			var screw := TableVisuals.cylinder(board.visuals,.08,.025,Vector3(x,-.3,side*(depth/2+1.5)),Color("8f9691"))
			screw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sparse seeded-looking dressing uses fixed arithmetic, never gameplay RNG.
	if board.scenario.id != "ashfall_station": return
	for i in 14:
		var x := -25 + (i*17 % 50)
		var z := -17 + (i*13 % 34)
		var point := Vector3(x,0,z)
		var clear := true
		for piece: TerrainPiece in board.terrain.get_children():
			if piece.overlaps_base(point,2.2): clear = false; break
		for unit: TableUnit in board.units.get_children():
			for model in unit.models:
				if model.position.distance_to(point) < 3: clear = false
		if not clear: continue
		var crate := TableVisuals.box(board.visuals,Vector3(.7,.6,.7),point+Vector3(0,.3,0),Color("514c3e"))
		crate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		TableVisuals.box(board.visuals,Vector3(.74,.07,.74),point+Vector3(0,.57,0),Color("293a40"))
