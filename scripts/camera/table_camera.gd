class_name TableCamera
extends Node3D

var camera: Camera3D
var destination := Vector3.ZERO
var heading := 0.0
var pitch := 0.76
var distance := 63.0
var assisted_focus := false
var dragging_pan := false
var dragging_orbit := false
var sensitivity := 1.0
var reduce_motion := false
var pan_velocity := Vector3.ZERO
var bounds := Vector2(30, 22)

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 50
	camera.near = 0.1
	camera.far = 300
	camera.current = true
	add_child(camera)
	_update_camera(1.0)

func _process(delta: float) -> void:
	var input := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.z -= 1
	if Input.is_physical_key_pressed(KEY_S): input.z += 1
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input.x += 1
	if get_viewport().gui_get_focus_owner() is LineEdit: input = Vector3.ZERO
	if assisted_focus and (not input.is_zero_approx() or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_E)): interrupt_focus()
	pan_velocity = pan_velocity.lerp(input.rotated(Vector3.UP, heading) * distance * 0.42 * sensitivity, 1.0 - exp(-delta * 9))
	destination += pan_velocity * delta
	if Input.is_physical_key_pressed(KEY_Q): heading += delta
	if Input.is_physical_key_pressed(KEY_E): heading -= delta
	destination.x = clampf(destination.x, -bounds.x, bounds.x)
	destination.z = clampf(destination.z, -bounds.y, bounds.y)
	_update_camera(1.0 - exp(-delta * 12))
	if position.distance_to(destination) < .03: assisted_focus = false

func _update_camera(weight: float) -> void:
	if reduce_motion: weight = 1.0
	position = position.lerp(destination, weight)
	var offset := Vector3(0, sin(pitch), cos(pitch)).rotated(Vector3.UP, heading) * distance
	camera.position = camera.position.lerp(offset, weight)
	camera.look_at(global_position)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE: dragging_pan = event.pressed
		if event.button_index == MOUSE_BUTTON_RIGHT: dragging_orbit = event.pressed
	if event is InputEventMouseMotion:
		if dragging_pan:
			interrupt_focus()
			destination += Vector3(-event.relative.x, 0, -event.relative.y).rotated(Vector3.UP, heading) * distance * 0.0013 * sensitivity
		if dragging_orbit:
			interrupt_focus()
			heading -= event.relative.x * 0.006 * sensitivity
			pitch = clampf(pitch + event.relative.y * 0.005 * sensitivity, 0.3, 1.48)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		destination = Vector3.ZERO
		heading = 0
		pitch = 0.85
		distance = 69
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: interrupt_focus()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(12, distance * 0.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(100, distance * 1.1)

func focus(point: Vector3) -> void:
	assisted_focus = true
	pan_velocity = Vector3.ZERO
	destination = point
	distance = minf(distance, 30)

func interrupt_focus() -> void:
	if not assisted_focus: return
	destination = position
	pan_velocity = Vector3.ZERO
	assisted_focus = false
