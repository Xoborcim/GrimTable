extends Node3D

# Original GrimTable sculpt library. Only decorative geometry; gameplay is external.
@export var kind := "infantry"
@export var faction := "legion"
@export var variation := 0
@export var height := 1.7
@export var tint := Color("304c72")
@export var accent := Color("93a8ba")
static var _batches: Dictionary = {}
static var _materials: Dictionary = {}
static var _palettes: Dictionary = {}
var h := 1.7
var armor: Color
var trim: Color
var joint := Color("172025")
var bone := Color("b5a387")
var energy := Color("65bfb7")

static func palettes() -> Dictionary:
	if _palettes.is_empty(): _palettes = JSON.parse_string(FileAccess.get_file_as_string("res://assets/grimtable/materials/faction_palettes.json"))
	return _palettes

func material(color: Color) -> ShaderMaterial:
	var key := faction + color.to_html()
	if not _materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/grimtable/materials/miniature.gdshader")
		mat.set_shader_parameter("paint", color)
		mat.set_shader_parameter("metal", .45 if color == trim and faction != "swarm" else palettes().get(faction,{}).get("metallic",.16))
		mat.set_shader_parameter("rough", palettes().get(faction,{}).get("roughness",.6))
		mat.set_shader_parameter("energy", .8 if color == energy else .0)
		_materials[key] = mat
	return _materials[key]

func part(shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = shape
	item.position = at * h
	item.material_override = material(color)
	add_child(item)
	return item

func box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	return part(DioramaGeometry.box_mesh(size * h), at, color)

func ball(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = .5
	shape.height = 1
	shape.radial_segments = 12
	shape.rings = 6
	var item := part(shape, at, color)
	item.scale = size * h
	return item

func rod(start: Vector3, end: Vector3, radius: float, color: Color, tip: float = -1) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius * h
	shape.top_radius = (radius if tip < 0 else tip) * h
	shape.height = start.distance_to(end) * h
	shape.radial_segments = 10
	var item := part(shape, (start + end) / 2, color)
	item.quaternion = Quaternion(Vector3.UP, (end-start).normalized())
	return item

func curve(points: Array[Vector3], radius: float, color: Color) -> void:
	var scaled: Array[Vector3] = []
	for point in points: scaled.append(point * h)
	part(DioramaGeometry.tapered_curve(scaled, radius * h), Vector3.ZERO, color)

func _ready() -> void:
	h = height
	var palette: Dictionary = palettes().get(faction,{"armor":tint.to_html(),"trim":accent.to_html(),"energy":"#65bfb7"})
	armor = Color(palette.armor).lightened((variation % 3) * .025)
	trim = Color(palette.trim)
	energy = Color(palette.energy)
	var key := "%s/%s/%s/%s/%s/%d" % [kind, faction, height, tint.to_html(), accent.to_html(), variation % 3]
	if _batches.has(key): show_batches(_batches[key]); return
	if kind == "tank": tank()
	elif kind in ["crawler", "winged"]: creature()
	elif kind == "walker": walker()
	else: humanoid()
	var groups := {}
	for child in get_children():
		if not child is MeshInstance3D: continue
		var key_mat: int = child.material_override.get_instance_id()
		if not groups.has(key_mat): groups[key_mat] = {"builder": SurfaceTool.new(), "material": child.material_override}
		for surface in child.mesh.get_surface_count(): groups[key_mat].builder.append_from(child.mesh, surface, child.transform)
		remove_child(child)
		child.free()
	var batches := []
	for group: Dictionary in groups.values():
		group.builder.set_material(group.material)
		batches.append({"mesh": group.builder.commit(), "material": group.material})
	_batches[key] = batches
	show_batches(batches)

func show_batches(batches: Array) -> void:
	for batch: Dictionary in batches:
		var item := MeshInstance3D.new()
		item.mesh = batch.mesh
		item.material_override = batch.material
		add_child(item)

func humanoid() -> void:
	var synth := faction == "synthetics"
	var wide := .26 if synth else .33
	for side in [-1, 1]:
		var hip := Vector3(side * .115, .48, 0)
		var knee := Vector3(side * .15, .27, side * .025)
		ball(Vector3(.14,.13,.13), knee, joint)
		rod(hip, knee, .067 if not synth else .041, joint)
		box(Vector3(.14,.20,.14), Vector3(side*.135,.385,0), armor)
		box(Vector3(.15,.21,.16), Vector3(side*.16,.17,side*.025), armor)
		box(Vector3(.18,.095,.27), Vector3(side*.16,.05,-.045+side*.025), joint)
		box(Vector3(.16,.075,.16), Vector3(side*.16,.09,-.09+side*.025), trim)
		ball(Vector3(.14,.14,.14), Vector3(side*wide,.66,0), joint)
		rod(Vector3(side*wide,.66,0), Vector3(side*.27,.49,-.08), .05, joint)
		var pad := box(Vector3(.2,.15,.25), Vector3(side*wide,.71,0), armor if side > 0 else trim)
		pad.rotation.z = side * -.18
		box(Vector3(.13,.18,.14), Vector3(side*.28,.52,-.08), armor)
	box(Vector3(.25,.14,.22), Vector3(0,.45,0), joint)
	box(Vector3(.42 if not synth else .30,.30,.29), Vector3(0,.64,0), armor)
	box(Vector3(.34,.16,.065), Vector3(0,.70,-.165), trim)
	box(Vector3(.32,.23,.17), Vector3(0,.65,.205), armor.lightened(.09))
	box(Vector3(.20,.035,.02), Vector3(0,.74,.30), bone)
	for side in [-1,1]:
		rod(Vector3(side*.10,.55,.23),Vector3(side*.10,.81,.23),.045,trim)
	rod(Vector3(.10,.78,.23),Vector3(.10,1.06,.23),.012,trim)
	if synth:
		rod(Vector3(0,.78,0),Vector3(0,.88,0),.035,joint)
		box(Vector3(.26,.13,.2),Vector3(0,.94,-.015),trim)
		ball(Vector3(.11,.1,.07),Vector3(0,.94,-.13),energy)
		ball(Vector3(.10,.12,.04),Vector3(0,.66,-.205),energy)
	else:
		ball(Vector3(.25,.26,.25),Vector3(0,.9,-.01),armor)
		box(Vector3(.24,.095,.10),Vector3(0,.92,-.12),joint)
		box(Vector3(.19,.028,.025),Vector3(0,.93,-.178),energy)
		box(Vector3(.20,.07,.075),Vector3(0,.82,-.12),trim)
	# A shoulder-stock, magazine, hand guard and distinct barrel read as a weapon.
	box(Vector3(.11,.14,.41),Vector3(.27,.51,-.3),joint)
	box(Vector3(.14,.10,.19),Vector3(.27,.54,-.34),armor)
	rod(Vector3(.27,.53,-.50),Vector3(.27,.53,-.73),.038,trim)
	box(Vector3(.075,.16,.09),Vector3(.27,.42,-.28),trim)
	if h >= 2 and faction == "legion":
		box(Vector3(.19,.20,.43),Vector3(.27,.53,-.4),armor)
		rod(Vector3(.27,.53,-.5),Vector3(.27,.53,-.82),.055,joint)
		box(Vector3(.16,.15,.22),Vector3(.34,.46,-.2),trim)
	rod(Vector3(-.28,.51,-.08),Vector3(.20,.49,-.35),.045,joint)
	ball(Vector3(.11,.095,.11),Vector3(.23,.50,-.38),trim)
	if faction == "horde":
		var plate := box(Vector3(.23,.27,.075),Vector3(-.24,.65,-.18),trim)
		plate.rotation.z = -.30
		rod(Vector3(-.32,.75,.02),Vector3(-.35,1.05,.03),.06,bone,0)
		rod(Vector3(.34,.54,-.2),Vector3(.35,.54,-.78),.075,joint)
		box(Vector3(.12,.09,.18),Vector3(.35,.53,-.67),trim)
	if variation % 3 == 1: box(Vector3(.06,.13,.12),Vector3(-.25,.46,.01),trim)
	if variation % 3 == 2: box(Vector3(.12,.09,.08),Vector3(.09,.78,.20),armor)

func walker() -> void:
	var synth := faction == "synthetics"
	for side in [-1,1]:
		rod(Vector3(side*.22,.61,0),Vector3(side*.29,.35,.08),.07,joint)
		ball(Vector3(.20,.20,.20),Vector3(side*.29,.34,.08),trim)
		box(Vector3(.18,.20,.16),Vector3(side*.26,.48,.04),armor.lightened(.1))
		rod(Vector3(side*.29,.34,.08),Vector3(side*.3,.12,-.07),.065,joint)
		box(Vector3(.16,.23,.17),Vector3(side*.30,.22,-.04),armor)
		box(Vector3(.13,.14,.035),Vector3(side*.30,.23,.06),trim)
		box(Vector3(.28,.11,.37),Vector3(side*.30,.065,-.10),joint)
		box(Vector3(.24,.065,.18),Vector3(side*.30,.12,-.19),trim)
		ball(Vector3(.22,.22,.22),Vector3(side*.40,.67,0),joint)
		box(Vector3(.22,.16,.29),Vector3(side*.42,.75,0),armor)
		box(Vector3(.19,.18,.24),Vector3(side*.43,.55,-.1),trim)
		for j in (2 if side > 0 else 1): rod(Vector3(side*.43+(j-.5)*.07,.56,-.22),Vector3(side*.43+(j-.5)*.07,.56,-.55),.035,joint)
	box(Vector3(.63 if not synth else .46,.37,.39),Vector3(0,.68,0),armor)
	box(Vector3(.48,.15,.10),Vector3(0,.78,-.22),joint)
	box(Vector3(.35,.045,.035),Vector3(0,.79,-.28),energy)
	box(Vector3(.42,.11,.31),Vector3(0,.91,.01),trim)
	rod(Vector3(.16,.94,.1),Vector3(.16,1.13,.1),.014,trim)
	if synth: ball(Vector3(.19,.19,.04),Vector3(0,.61,-.235),energy)
	if faction == "horde":
		var plate := box(Vector3(.28,.28,.14),Vector3(-.43,.59,-.18),trim)
		plate.rotation.z = -.25
		rod(Vector3(-.31,.85,0),Vector3(-.35,1.14,0),.06,bone,0)
		rod(Vector3(.25,.69,.23),Vector3(.25,1.05,.23),.06,joint)
	for j in 4: box(Vector3(.04,.14,.07),Vector3((j-1.5)*.09,.67,.23),joint)

func tank() -> void:
	box(Vector3(.85,.25,1.15),Vector3(0,.27,0),armor)
	box(Vector3(.73,.16,.95),Vector3(0,.43,-.02),armor.lightened(.08))
	for side in [-1,1]:
		box(Vector3(.22,.28,1.18),Vector3(side*.49,.19,0),joint)
		for j in 5:
			var wheel := rod(Vector3(side*.47,.18,(j-2)*.22),Vector3(side*.62,.18,(j-2)*.22),.105,trim)
		box(Vector3(.25,.09,1.12),Vector3(side*.49,.37,0),armor)
		for j in 3: box(Vector3(.025,.13,.27),Vector3(side*.63,.29,(j-1)*.34),armor)
	rod(Vector3(0,.46,0),Vector3(0,.51,0),.25,joint)
	box(Vector3(.55,.23,.52),Vector3(0,.59,-.06),armor)
	box(Vector3(.40,.06,.36),Vector3(0,.73,-.04),trim)
	rod(Vector3(0,.61,-.28),Vector3(0,.61,-1.02),.055,trim)
	box(Vector3(.15,.14,.18),Vector3(0,.61,-1.02),joint)
	rod(Vector3(.20,.73,.10),Vector3(.2,1.0,.1),.009,trim)
	for side in [-1,1]: box(Vector3(.09,.05,.04),Vector3(side*.29,.43,-.51),energy)

func creature() -> void:
	var flesh := Color("684a56")
	ball(Vector3(.48,.40,.75),Vector3(0,.40,.07),flesh)
	ball(Vector3(.37,.30,.35),Vector3(0,.43,-.40),armor)
	for j in 4:
		var plate := ball(Vector3(.51-j*.055,.20,.28),Vector3(0,.59-j*.025,-.18+j*.19),armor.lightened(.04*j))
		plate.rotation.x = -.25
		curve([Vector3(0,.63,-.18+j*.19),Vector3(.025,.76,-.05+j*.19),Vector3(.04,.80,.05+j*.19)],.055,trim)
	for side in [-1,1]:
		for j in 3:
			var z := (j-1)*.27
			ball(Vector3(.15,.14,.14),Vector3(side*.22,.4,z),flesh)
			curve([Vector3(side*.2,.42,z),Vector3(side*.46,.48,z+.10),Vector3(side*.61,.25,z+.15),Vector3(side*.55,.04,z-.03)],.065,armor)
		curve([Vector3(side*.17,.40,-.44),Vector3(side*.32,.31,-.64),Vector3(side*.27,.3,-.83),Vector3(side*.13,.38,-.86)],.065,bone)
		ball(Vector3(.075,.055,.04),Vector3(side*.13,.52,-.55),energy)
		if kind == "winged":
			rod(Vector3(side*.12,.5,.05),Vector3(side*.84,.90,.16),.035,trim)
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 4:
				var points := [Vector3(side*.18,.55,.12),Vector3(side*(.83-i*.13),.90-i*.10,.16+i*.12),Vector3(side*(.70-i*.13),.80-i*.10,.28+i*.12)]
				for reverse in [false,true]:
					var triangle := points.duplicate()
					if reverse: triangle.reverse()
					var normal: Vector3 = (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).normalized()
					for point: Vector3 in triangle:
						builder.set_normal(normal)
						builder.add_vertex(point*h)
			var membrane := part(builder.commit(),Vector3.ZERO,flesh)
			var mat := material(flesh).duplicate() as ShaderMaterial
			# The wing is a thin sculpted membrane; an opposed copy makes both sides visible.
			membrane.material_override = mat
	curve([Vector3(0,.32,.35),Vector3(.09,.30,.62),Vector3(.24,.25,.83),Vector3(.36,.35,1.02),Vector3(.34,.48,1.08)],.105,armor)
