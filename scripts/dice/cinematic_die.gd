class_name CinematicDie
extends RigidBody3D

# Opposite faces sum to seven. These normals are also the result contract.
const NORMALS := [Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.DOWN]
var result := 1
var shell: MeshInstance3D

static func final_rotation(value: int) -> Quaternion:
	return Quaternion(NORMALS[clampi(value, 1, 6)-1], Vector3.UP)

static func top_face(basis_value: Basis) -> int:
	var best := -2.0
	var value := 0
	for i in 6:
		var height: float = (basis_value * NORMALS[i]).y
		if height > best: best = height; value = i+1
	return value

func _init(value: int = 1, style: String = "Ivory") -> void:
	result = clampi(value, 1, 6)
	mass = .8
	continuous_cd = true
	linear_damp = .45
	angular_damp = .6
	var physics := PhysicsMaterial.new()
	physics.bounce = .32
	physics.friction = .7
	physics_material_override = physics
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = Vector3.ONE * .82
	shape.shape = cube
	add_child(shape)
	var color := Color("d4c6a7") if style == "Ivory" else Color("344b58")
	shell = TableVisuals.mesh(self, DioramaGeometry.box_mesh(Vector3.ONE * .84), Vector3.ZERO, color)
	(shell.material_override as StandardMaterial3D).metallic = .15 if style == "Ivory" else .75
	(shell.material_override as StandardMaterial3D).roughness = .32
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = .047
	pip_mesh.height = .022
	pip_mesh.radial_segments = 10
	pip_mesh.rings = 4
	for i in 6:
		var normal: Vector3 = NORMALS[i]
		var turn := Quaternion(Vector3.UP, normal)
		var points: Array[Vector2] = []
		var n := i+1
		if n % 2 == 1: points.append(Vector2.ZERO)
		if n >= 2: points.append_array([Vector2(-.19,-.19),Vector2(.19,.19)])
		if n >= 4: points.append_array([Vector2(-.19,.19),Vector2(.19,-.19)])
		if n == 6: points.append_array([Vector2(-.19,0),Vector2(.19,0)])
		for point in points:
			var pip := TableVisuals.mesh(self,pip_mesh, turn * Vector3(point.x,.424,point.y),Color("17242c") if style == "Ivory" else Color("99e2df"))
			pip.quaternion = turn

func highlight(success: bool) -> void:
	var material := shell.material_override as StandardMaterial3D
	material.emission_enabled = success
	material.emission = Color("477d73")
	material.emission_energy_multiplier = .35
