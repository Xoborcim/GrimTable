class_name ScenarioEditor
extends Node3D

signal changed
signal message(text: String)
enum Tool { SELECT, TERRAIN, OBJECTIVE, UNIT, ZONE, DELETE }
const BASE_TERRAIN := [
	{"name": "Wall", "kind": "box", "size": [7, 3, 0.8]},
	{"name": "Ruin", "kind": "ruin", "size": [6, 4, 6]},
	{"name": "Crates", "kind": "box", "size": [2.2, 1.8, 2.2]},
	{"name": "Barricade", "kind": "box", "size": [5, 0.8, 0.7]},
	{"name": "Block", "kind": "box", "size": [3, 3, 4]},
	{"name":"Gothic / Basilica Manufactorum","kind":"ruin","art_style":"gothic","size":[13,10,7],"blocks_movement":true,"blocks_los":true},
	{"name":"Decorative / Chemical Runoff","kind":"box","art_style":"pool","size":[6,.12,4],"blocks_movement":false,"blocks_los":false},
	{"name": "Gothic Ruins / Ruined Basilica", "kind": "ruin", "art_style": "gothic", "size": [9, 7, 6], "blocks_movement": true, "blocks_los": true},
	{"name": "Gothic Ruins / Broken Wall", "kind": "box", "art_style": "gothic", "size": [7, 5, 0.8], "blocks_movement": true, "blocks_los": true},
	{"name": "Gothic Ruins / Pillar", "kind": "box", "art_style": "pillar", "size": [2, 7, 2], "blocks_movement": true, "blocks_los": true},
	{"name": "Industrial / Factory", "kind": "box", "art_style": "factory", "size": [7, 6, 5], "blocks_movement": true, "blocks_los": true},
	{"name": "Industrial / Generator", "kind": "box", "art_style": "generator", "size": [4, 4, 4], "blocks_movement": true, "blocks_los": true},
	{"name": "Industrial / Refinery", "kind": "box", "art_style": "refinery", "size": [6, 6, 5], "blocks_movement": true, "blocks_los": true},
	{"name": "Industrial / Pipes", "kind": "box", "art_style": "pipes", "size": [6, 1.8, 2], "blocks_movement": true, "blocks_los": false},
	{"name": "Industrial / Gantry (decorative height)", "kind": "box", "art_style": "gantry", "size": [7, 3, 3], "blocks_movement": true, "blocks_los": true},
	{"name": "Industrial / Communications", "kind": "box", "art_style": "tower", "size": [3, 8, 3], "blocks_movement": true, "blocks_los": true},
	{"name": "Battlefield / Bunker", "kind": "box", "art_style": "bunker", "size": [6, 2.5, 4], "blocks_movement": true, "blocks_los": true},
	{"name": "Battlefield / Barricade", "kind": "box", "art_style": "barricade", "size": [5, 1, 0.8], "blocks_movement": true, "blocks_los": false},
	{"name": "Battlefield / Crater", "kind": "box", "art_style": "crater", "size": [4, 0.12, 4], "blocks_movement": false, "blocks_los": false},
	{"name": "Decorative / Rubble", "kind": "box", "art_style": "rubble", "size": [3, 0.4, 2], "blocks_movement": false, "blocks_los": false},
	{"name": "Battlefield / Wreckage", "kind": "box", "art_style": "wreckage", "size": [4, 1.4, 3], "blocks_movement": true, "blocks_los": false},
	{"name":"Centerpieces / Broken Gatehouse","kind":"box","size":[8,12.4,3],"visual_scene":"res://assets/terrain/environment/gatehouse.glb"},
	{"name":"Centerpieces / Refinery Core","kind":"box","size":[7,11,6],"visual_scene":"res://assets/terrain/environment/refinery_core.glb"},
	{"name":"Gothic / Cloister Wall","kind":"box","size":[8,6,1.4],"visual_scene":"res://assets/terrain/environment/cloister.glb"},
	{"name":"Industrial / Cooling Bank","kind":"box","size":[6,6,4],"visual_scene":"res://assets/terrain/environment/cooling_bank.glb"},
	{"name":"Battlefield / Blasted Casemate","kind":"box","size":[7,3,4],"visual_scene":"res://assets/terrain/environment/breach_bunker.glb"},
	{"name":"Objectives / Split-circle Reliquary","kind":"box","size":[3,3.3,3],"visual_scene":"res://assets/terrain/environment/reliquary.glb"},
	{"name":"Industrial / Freight Hoist (solid footprint)","kind":"box","size":[7,8,4],"visual_scene":"res://assets/terrain/environment/hoist.glb"},
	{"name":"Battlefield / Revetment Trench","kind":"box","size":[8,.7,3],"visual_scene":"res://assets/terrain/environment/trench.glb","blocks_movement":false,"blocks_los":false,"cover_bonus":1,"movement_penalty":2}]
static var PROFILES: Array[String] = profile_palette()
static var TERRAIN: Array = terrain_palette()

static func terrain_palette() -> Array:
	var items: Array=BASE_TERRAIN.duplicate(true)
	var path:="res://resources/environment/clusters_0131.json"
	if FileAccess.file_exists(path):
		var catalogue: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if catalogue is Dictionary:items.append_array(catalogue.get("clusters",[]))
	return items

static func profile_palette() -> Array[String]:
	var result: Array[String] = ["res://resources/units/trooper.json", "res://resources/units/heavy.json", "res://resources/units/vehicle.json"]
	for path: String in ContentRegistry.catalog().get("units", {}).values(): result.append(path)
	return result

var game: Node3D
var enabled := true
var document: Dictionary
var path := ""
var dirty := false
var tool := Tool.SELECT
var terrain_index := 0
var profile_index := 0
var unit_count := 5
var team := 0
var angle := 0.0
var grid_snap := false
var selected_id := ""
var selected_kind := ""
var preview: Node3D
var cursor := Vector3.ZERO
var drag_start: Variant = null
var drag_before: Dictionary = {}
var drag_origins: Dictionary = {}

func _ready() -> void:
	PROFILES = profile_palette()
	document = ScenarioFactory.capture(game)
	game.editing = true
	game.hud.hide()
	game.interaction.cancel()
	game.interaction.editor = self
	game.manager.deployment = true
	game.deployment.visible = true
	show_objective_radii()

func show_objective_radii() -> void:
	for objective: TableObjective in game.battlefield.objectives.get_children(): objective.radius_ring.visible = true
	var ground:=game.battlefield.visuals.get_node_or_null("GroundSurface") as MeshInstance3D
	if ground!=null:(ground.material_override as ShaderMaterial).set_shader_parameter("grid_visibility",1.0)

func set_tool(value: int) -> void:
	cancel_drag()
	tool = value as Tool
	_build_preview()
	changed.emit()

func _build_preview() -> void:
	if is_instance_valid(preview):
		remove_child(preview)
		preview.queue_free()
	preview = Node3D.new()
	add_child(preview)
	if tool == Tool.TERRAIN:
		var size := ScenarioFactory.vector(TERRAIN[terrain_index].size)
		if not TERRAIN[terrain_index].get("footprint_parts",[]).is_empty():
			for part: Dictionary in TERRAIN[terrain_index].footprint_parts:TableVisuals.box(preview,ScenarioFactory.vector(part.size),ScenarioFactory.vector(part.center),Color("a0d8ce"))
		elif TERRAIN[terrain_index].kind == "ruin":
			TableVisuals.box(preview, Vector3(size.x, size.y, 0.8), Vector3(0, size.y / 2, -size.z / 2 + 0.4), Color("a0d8ce"))
			TableVisuals.box(preview, Vector3(0.8, size.y, size.z), Vector3(-size.x / 2 + 0.4, size.y / 2, 0), Color("a0d8ce"))
		else: TableVisuals.box(preview, size, Vector3(0, size.y / 2, 0), Color("a0d8ce"))
	elif tool == Tool.OBJECTIVE: TableVisuals.ring(preview, 3, Color("efd583"))
	elif tool == Tool.ZONE:
		TableVisuals.box(preview, Vector3(10, 0.1, 8), Vector3.ZERO, Color("79cbbb"))
	elif tool == Tool.UNIT:
		var stats: Dictionary = ContentRegistry.read_json(PROFILES[profile_index])
		for i in unit_count:
			TableVisuals.cylinder(preview, ContentRegistry.base_radius(stats), 1.4, Vector3((i - float(unit_count - 1) / 2) * (ContentRegistry.base_radius(stats) * 2 + 0.8), 0.7, 0), Color("79cbbb"))
	for child in preview.get_children():
		if child is MeshInstance3D and child.material_override is StandardMaterial3D:
			var mat := child.material_override as StandardMaterial3D
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.35

func update_pointer(screen: Vector2) -> void:
	var point: Variant = MeasurementService.tabletop_point(game.camera_rig.camera, screen)
	if point == null: return
	cursor = game.interaction._clamp_to_board(point)
	if grid_snap: cursor=cursor.snapped(Vector3(1,1,1))
	if is_instance_valid(preview):
		preview.position = cursor
		preview.rotation.y = deg_to_rad(angle)
		preview.visible = tool in [Tool.TERRAIN, Tool.OBJECTIVE, Tool.UNIT, Tool.ZONE] and get_viewport().gui_get_hovered_control() == null
	if drag_start != null:
		var delta: Vector3 = cursor - drag_start
		if selected_kind == "deployment_zones":
			var zone: Dictionary = find_record(drag_before, selected_kind, selected_id).duplicate(true)
			zone.center = [float(zone.center[0]) + delta.x, float(zone.center[1]) + delta.z]
			var state := drag_before.duplicate(true)
			replace_record(state, selected_kind, zone)
			game.deployment.load_zones(state)
			game.deployment.visible = true
		else:
			for object: Node3D in drag_origins: object.global_position = drag_origins[object] + delta

func handle_release(event: InputEvent) -> void:
	if drag_start == null or not (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	update_pointer(event.position)
	var result := ScenarioFactory.capture(game)
	var error := placement_error(result)
	if not error.is_empty():
		game.apply_scenario(drag_before)
		game.deployment.visible = true
		message.emit("Placement rejected: " + error)
	else:
		document = result
		dirty = true
	drag_start = null
	drag_origins.clear()
	changed.emit()

func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancel_drag()
			set_tool(Tool.SELECT)
		if event.keycode == KEY_R: rotate_selection(15)
		if event.keycode == KEY_DELETE: delete_selected()
	if event is InputEventMouseButton and event.pressed and event.shift_pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		rotate_selection(15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -15)
		get_viewport().set_input_as_handled()
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	get_viewport().gui_release_focus()
	update_pointer(event.position)
	if tool in [Tool.TERRAIN, Tool.OBJECTIVE, Tool.UNIT, Tool.ZONE]:
		place(cursor)
		return
	var object: Node3D = game.interaction.pick(event.position, 58)
	selected_id = ""
	selected_kind = ""
	if object is TerrainPiece:
		selected_id = object.object_id
		selected_kind = "terrain"
	elif object is TableObjective:
		selected_id = object.object_id
		selected_kind = "objectives"
		object.radius_ring.visible = true
	elif object is Miniature:
		selected_kind = "model" if event.alt_pressed else "armies"
		selected_id = object.model_id if event.alt_pressed else str(object.get_parent().name)
	elif object != null and object.has_meta("zone_id"):
		selected_id = object.get_meta("zone_id")
		selected_kind = "deployment_zones"
	if tool == Tool.DELETE:
		delete_selected()
		return
	changed.emit()
	if selected_id.is_empty(): return
	drag_before = ScenarioFactory.capture(game)
	drag_start = cursor
	drag_origins.clear()
	if selected_kind == "armies":
		for model: Miniature in object.get_parent().models: drag_origins[model] = model.global_position
	elif selected_kind != "deployment_zones": drag_origins[object] = object.global_position

func place(point: Vector3) -> bool:
	var data := ScenarioFactory.capture(game)
	if tool == Tool.TERRAIN:
		var palette: Dictionary = TERRAIN[terrain_index]
		data.terrain.append({"id": ScenarioLibrary.new_id("terrain"), "title": palette.name, "kind": palette.kind, "art_style": palette.get("art_style", ""), "size": palette.size.duplicate(), "position": ScenarioFactory.array(point), "rotation": angle, "tint": "#7a817c", "blocks_movement": palette.get("blocks_movement",true), "blocks_los": palette.get("blocks_los",true)})
		for key in ["visual_scene","cover_bonus","movement_penalty","footprint_parts"]:
			if palette.has(key):data.terrain[-1][key]=palette[key]
	elif tool == Tool.OBJECTIVE:
		data.objectives.append({"id": ScenarioLibrary.new_id("objective"), "name": "Objective " + str(data.objectives.size() + 1), "number": data.objectives.size() + 1, "radius": 3, "position": ScenarioFactory.array(point)})
	elif tool == Tool.ZONE:
		data.deployment_zones.append({"id": ScenarioLibrary.new_id("zone"), "name": "Team " + ("A" if team == 0 else "B") + " zone", "team": team, "shape": "rectangle", "center": [point.x, point.z], "size": [10, 8]})
	elif tool == Tool.UNIT:
		var id := ScenarioLibrary.new_id("unit")
		var stats: Dictionary = ContentRegistry.read_json(PROFILES[profile_index])
		var models: Array[Dictionary] = []
		for i in unit_count:
			var offset := Vector3((i - float(unit_count - 1) / 2) * (ContentRegistry.base_radius(stats) * 2 + 0.8), 0, 0).rotated(Vector3.UP, deg_to_rad(angle))
			models.append({"id": id + "_" + str(i + 1), "position": ScenarioFactory.array(point + offset), "rotation": angle})
		var army := {"id": id, "name": stats.name + " Squad", "team": team, "profile": PROFILES[profile_index], "models": models}
		if stats.has("id"): army["unit_id"] = stats.id
		data.armies.append(army)
	else: return false
	return commit(data)

func commit(data: Dictionary) -> bool:
	var error := ScenarioDefinition.validate(data)
	if not error.is_empty():
		message.emit(error)
		return false
	var before := ScenarioFactory.capture(game)
	game.apply_scenario(data)
	error = placement_error(data)
	if not error.is_empty():
		game.apply_scenario(before)
		message.emit(error)
		return false
	document = data.duplicate(true)
	game.deployment.visible = true
	show_objective_radii()
	dirty = true
	changed.emit()
	return true

func placement_error(data: Dictionary) -> String:
	var error := ScenarioDefinition.validate(data)
	if not error.is_empty(): return error
	for unit: TableUnit in game.battlefield.units.get_children():
		for model in unit.models:
			error = MovementService.placement_error(game.battlefield, model, model.global_position)
			if not error.is_empty(): return model.model_id + ": " + error
	return ""

func cancel_drag() -> void:
	if drag_start != null:
		game.apply_scenario(drag_before)
		game.deployment.visible = true
	drag_start = null
	drag_origins.clear()

func duplicate_selected() -> void:
	if selected_kind not in ["terrain","objectives"]: message.emit("Select terrain or an objective to duplicate."); return
	var data := ScenarioFactory.capture(game)
	var record := find_record(data,selected_kind,selected_id).duplicate(true)
	if record.is_empty(): return
	record.id=ScenarioLibrary.new_id("terrain" if selected_kind=="terrain" else "objective")
	record.position[0]=float(record.position[0])+2
	record.position[2]=float(record.position[2])+2
	data[selected_kind].append(record)
	if commit(data): selected_id=record.id; changed.emit()

func rotate_selection(degrees: float) -> void:
	cancel_drag()
	if tool != Tool.SELECT:
		angle = fmod(angle + degrees, 360)
		changed.emit()
		return
	var data := ScenarioFactory.capture(game)
	var record := find_record(data, selected_kind, selected_id)
	if record.is_empty(): return
	if selected_kind == "terrain": record.rotation = float(record.get("rotation", 0)) + degrees
	elif selected_kind == "armies":
		var center := Vector3.ZERO
		for model: Dictionary in record.models: center += ScenarioFactory.vector(model.position)
		center /= maxf(1, record.models.size())
		for model: Dictionary in record.models:
			model.position = ScenarioFactory.array(center + (ScenarioFactory.vector(model.position) - center).rotated(Vector3.UP, deg_to_rad(degrees)))
			model.rotation = float(model.get("rotation", 0)) + degrees
	commit(data)

func delete_selected() -> void:
	cancel_drag()
	var data := ScenarioFactory.capture(game)
	if selected_kind == "model":
		for unit: Dictionary in data.armies:
			for i in range(unit.models.size() - 1, -1, -1):
				if unit.models[i].id == selected_id: unit.models.remove_at(i)
	elif data.has(selected_kind):
		for i in range(data[selected_kind].size() - 1, -1, -1):
			if data[selected_kind][i].id == selected_id: data[selected_kind].remove_at(i)
	else: return
	selected_id = ""
	selected_kind = ""
	commit(data)

static func find_record(data: Dictionary, collection: String, id: String) -> Dictionary:
	if collection == "model":
		for unit: Dictionary in data.armies:
			for model: Dictionary in unit.models:
				if model.id == id: return model
	for item: Dictionary in data.get(collection, []):
		if item.id == id: return item
	return {}

static func replace_record(data: Dictionary, collection: String, record: Dictionary) -> void:
	for i in data[collection].size():
		if data[collection][i].id == record.id: data[collection][i] = record

func save_scenario(as_name: String = "") -> String:
	document = ScenarioFactory.capture(game)
	if not as_name.is_empty():
		document.id = ScenarioLibrary.new_id()
		document.name = as_name.strip_edges()
		path = ScenarioLibrary.DIRECTORY + document.id + ".json"
	if path.is_empty() or path.begins_with("res://"): return "Use Save Scenario As to create a custom copy"
	var result := ScenarioLibrary.save(document, path)
	if result.begins_with("Saved"):
		game.scenario = document.duplicate(true)
		dirty = false
	message.emit(result)
	changed.emit()
	return result
