class_name DeploymentZone
extends Resource

@export var team := 0
@export var zone_id := ""
@export var display_name := "Deployment"

func contains_base(_point: Vector3, _radius: float) -> bool:
	return false

func outline() -> PackedVector3Array:
	return PackedVector3Array()

static func from_data(data: Dictionary) -> DeploymentZone:
	# Extend this factory with other shape Resources; callers only use contains_base.
	if data.get("shape") != "rectangle": return null
	var zone := RectangleDeploymentZone.new()
	zone.team = int(data.get("team", 0))
	zone.zone_id = data.get("id", "")
	zone.display_name = data.get("name", "Deployment")
	zone.center = Vector2(float(data.center[0]), float(data.center[1]))
	zone.size = Vector2(float(data.size[0]), float(data.size[1]))
	return zone
