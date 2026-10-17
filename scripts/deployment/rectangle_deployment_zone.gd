class_name RectangleDeploymentZone
extends DeploymentZone

@export var center := Vector2.ZERO
@export var size := Vector2(60, 9)

func contains_base(point: Vector3, radius: float) -> bool:
	return absf(point.x - center.x) + radius <= size.x / 2 + 0.001 and absf(point.z - center.y) + radius <= size.y / 2 + 0.001

func outline() -> PackedVector3Array:
	var points := PackedVector3Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		var point: Vector2 = center + corner * size / 2
		points.append(Vector3(point.x, 0.07, point.y))
	return points
