@tool
extends Node3D

# Artist wrapper, separate from the immutable third-party source. Orientation,
# scale and floor offset are explicit import decisions, never gameplay geometry.
@export_file("*.glb", "*.gltf") var source := ""
@export var artist_scale := Vector3.ONE
@export var artist_offset := Vector3.ZERO
@export var artist_rotation := Vector3.ZERO

func _ready() -> void:
	if not ResourceLoader.exists(source):
		push_warning("Missing imported visual: " + source)
		return
	var resource := load(source) as PackedScene
	if resource == null: return
	var visual := resource.instantiate() as Node3D
	if visual == null: return
	visual.scale = artist_scale
	visual.position = artist_offset
	visual.rotation_degrees = artist_rotation
	add_child(visual)
	strip_gameplay(visual)

func strip_gameplay(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children(): strip_gameplay(child)
