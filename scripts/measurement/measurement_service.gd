class_name MeasurementService
extends RefCounted

const INCHES_PER_WORLD_UNIT := 1.0

static func horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

static func distance_between_bases(a: Miniature, b: Miniature) -> float:
	return maxf(0, horizontal_distance(a.global_position, b.global_position) - a.base_radius - b.base_radius)

static func tabletop_point(camera: Camera3D, screen: Vector2) -> Variant:
	return Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))

static func line_of_sight(world: World3D, a: Miniature, b: Miniature) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a.eye(), b.eye(), 4)
	var hit := world.direct_space_state.intersect_ray(query)
	return {"clear": hit.is_empty(), "obstacle": hit.get("collider"), "position": hit.get("position", b.eye())}
