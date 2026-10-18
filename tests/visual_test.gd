extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: "+message)

func normals_match(mesh: Mesh) -> bool:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size(): indices.append(i)
	if indices.size()%3!=0: return false
	for i in range(0,indices.size(),3):
		var a:=indices[i]; var b:=indices[i+1]; var c:=indices[i+2]
		if a<0 or b<0 or c<0 or maxi(a,maxi(b,c))>=vertices.size(): return false
		var face := (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a]).normalized()
		if face.length_squared() < .5: return false
		if face.dot(normals[a]) < .4: return false
	return true

func run() -> void:
	var box := DioramaGeometry.box_mesh(Vector3(1,2,3))
	check(normals_match(box),"Chamfer normals match outward face winding")
	check(box == DioramaGeometry.box_mesh(Vector3(1,2,3)),"Identical bevel geometry is shared")
	var curve := DioramaGeometry.tapered_curve([Vector3.ZERO,Vector3(.3,.5,0),Vector3(.6,.6,.2)],.12)
	check(normals_match(curve),"Organic taper winding agrees with smooth normals")
	check(GrimTheme.theme().default_font != null,"Redistributable UI font loads")
	check(GrimTheme.theme().get_stylebox("panel","TooltipPanel") != null,"Tooltips share design system")
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/third_party/assets.json"))
	var font: Dictionary = registry.assets.filter(func(item): return item.id=="barlow_ui")[0]
	check(font.license=="OFL-1.1" and FileAccess.file_exists("res://"+font.license_file),"Font license ships with source")
	for file in font.files:
		check(FileAccess.get_sha256("res://"+file.path)==file.sha256,"Font registry checksum: "+file.path)
	var game: Node3D = load("res://scenes/main/main.tscn").instantiate()
	game.scenario = ScenarioLibrary.read(ScenarioLibrary.BUILTINS[4]).data
	game.settings = AppSettings.new()
	game.settings.autosave = false
	game.settings.camera_assistance = false
	root.add_child(game)
	for i in 4: await process_frame
	await physics_frame
	var guide: GuidedExperience = game.guidance
	guide.label_layout.layout_labels()
	var rectangles := guide.label_layout.last_rects
	var separate := true
	for i in rectangles.size():
		for j in range(i+1,rectangles.size()):
			if rectangles[i].intersects(rectangles[j]): separate = false
	check(separate and rectangles.size()>3,"Squad/objective plates are readable and separated")
	var unit: TableUnit = game.battlefield.units.get_child(0)
	game.selection.select_unit(unit)
	for i in 4: await process_frame
	check(guide.unit_card.visible and guide.unit_card.heading.text == unit.display_name,"Game card shows selected identity")
	check(guide.unit_card.values[1].text=="2","Card health remains profile driven")
	check(is_equal_approx(unit.models[0].get_node("Collision").shape.radius,ContentRegistry.base_radius(unit.definition)),"Art leaves base footprint unchanged")
	check(is_equal_approx(unit.models[0].get_node("LOSOrigin").position.y,float(unit.definition.los_height)),"Art leaves gameplay LOS point unchanged")
	var before := WorldState.capture(game)
	guide.label_layout.layout_labels()
	check(WorldState.capture(game)==before,"Label layout changes no gameplay state")
	# Congested cosmetic anchors must suppress lower priority plates, never stack text.
	var temporary: Array[Node3D] = []
	for i in 20:
		var node := Node3D.new()
		node.name="ExtraBadge"+str(i)
		game.add_child(node)
		temporary.append(node)
		guide.label_layout.badge(node,unit.models[0].global_position+Vector3.UP*2,"Crowded label "+str(i),1,8)
	guide.label_layout.layout_labels()
	rectangles = guide.label_layout.last_rects
	separate = true
	for i in rectangles.size():
		for j in range(i+1,rectangles.size()):
			if rectangles[i].intersects(rectangles[j]): separate = false
	check(separate,"Crowded labels are offset/suppressed without overlap")
	check(guide.labels[unit].is_visible_in_tree(),"Selected squad retains label priority")
	for node in temporary: node.queue_free()
	game.queue_free()
	await process_frame
	print("GRIMTABLE VISUAL: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
