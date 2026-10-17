class_name Battlefield
extends Node3D

const WIDTH := 60.0
const DEPTH := 44.0
var width := WIDTH
var depth := DEPTH
var units: Node3D
var terrain: Node3D
var objectives: Node3D
var visuals: Node3D
var scenario: Dictionary = {}
var spatial_revision := 0
var _control_cache := {}
var _physics_refresh_pending := false

func invalidate_spatial() -> void:
	spatial_revision += 1
	_control_cache.clear()
	if not _physics_refresh_pending and is_inside_tree():
		_physics_refresh_pending = true
		refresh_after_physics()

func refresh_after_physics() -> void:
	# Physics bodies and queued terrain removals settle after the action. A
	# second revision prevents an early UI query from caching the previous ray hit.
	await get_tree().physics_frame
	await get_tree().process_frame
	_physics_refresh_pending = false
	spatial_revision += 1
	_control_cache.clear()

func control_for(objective: TableObjective) -> Dictionary:
	if not _control_cache.has(objective.object_id):
		_control_cache[objective.object_id] = ObjectiveControl.evaluate(objective, units.get_children())
	return _control_cache[objective.object_id]


func _ready() -> void:
	for title in ["Board", "Terrain", "Objectives", "Units"]:
		var container := Node3D.new()
		container.name = title
		add_child(container)
	visuals = get_node("Board")
	terrain = get_node("Terrain")
	objectives = get_node("Objectives")
	units = get_node("Units")
	if scenario.is_empty(): scenario = ScenarioLibrary.read("res://resources/scenarios/demo.json").data
	build(scenario)

func build(data: Dictionary) -> void:
	scenario = data.duplicate(true)
	for container in [visuals, terrain, objectives, units]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	width = float(data.board.width)
	depth = float(data.board.depth)
	TableVisuals.box(visuals, Vector3(width + 1, 0.8, depth + 1), Vector3(0, -0.5, 0), Color("10191e"))
	var surface := TableVisuals.box(visuals, Vector3(width, 0.2, depth), Vector3(0, -0.1, 0), Color.WHITE)
	surface.name = "GroundSurface"
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.material_override = BattlefieldPresentation.ground(str(data.board.get("theme", "industrial")))
	for side in [-1, 1]:
		TableVisuals.box(visuals, Vector3(width + 0.8, 0.16, 0.22), Vector3(0, 0, side * (depth / 2 + 0.25)), Color("74818b"))
		TableVisuals.box(visuals, Vector3(0.22, 0.16, depth), Vector3(side * (width / 2 + 0.25), 0, 0), Color("74818b"))
		for x in range(-int(width / 2) + 6, int(width / 2), 12):
			TableVisuals.box(visuals, Vector3(0.045, 0.025, 0.35), Vector3(x, 0.025, side * (depth / 2 - 0.25)), Color("a1aba9"))
	ScenarioFactory.populate(self, data)
	BattlefieldPresentation.decorate(self)
	invalidate_spatial()

func contains_base(point: Vector3, radius: float) -> bool:
	return absf(point.x) + radius <= width / 2 and absf(point.z) + radius <= depth / 2
