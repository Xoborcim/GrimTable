class_name MenuDiorama
extends SubViewportContainer

var settings: AppSettings
var manager: GameManager
var camera: Camera3D
var viewport: SubViewport
var time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	stretch_shrink = 1
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	BattlefieldPresentation.lighting(world,settings)
	var board := Battlefield.new()
	board.scenario = ScenarioLibrary.read(ScenarioLibrary.FLAGSHIP).data
	world.add_child(board)
	BattlefieldPresentation.apply_theme(world,board.scenario.board)
	# A photograph-like display, never a second active game or picking surface.
	for node in board.find_children("*","",true,false):
		for group in ["miniatures","units","terrain","objectives"]: node.remove_from_group(group)
		if node is CollisionObject3D: node.collision_layer = 0; node.collision_mask = 0
		if node is Label3D: node.hide()
	camera = Camera3D.new()
	camera.fov = 39
	viewport.add_child(camera)
	_update_camera()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or camera == null: return
	if not settings.reduce_motion: time += delta
	_update_camera()

func _update_camera() -> void:
	camera.position = Vector3(18+sin(time*.035)*3,30,43+cos(time*.035)*2)
	camera.look_at(Vector3(0,1,-3))
