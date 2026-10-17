class_name DioramaGeometry
extends RefCounted

# Small shared chamfer meshes. Flat face normals preserve mechanical edges;
# each bevel is actual geometry, independent of gameplay collision.
static var boxes: Dictionary = {}

static func box_mesh(size: Vector3) -> ArrayMesh:
	if boxes.has(size): return boxes[size]
	var half := size / 2
	var bevel := minf(.09, minf(size.x, minf(size.y, size.z)) * .16)
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for level in 4:
		var y: float = [-half.y, -half.y + bevel, half.y - bevel, half.y][level]
		var inset := bevel if level in [0, 3] else 0.0
		var x := half.x - inset
		var z := half.z - inset
		var cut := bevel * .35 if level in [0, 3] else bevel
		rings.append(PackedVector3Array([Vector3(-x+cut,y,-z),Vector3(x-cut,y,-z),Vector3(x,y,-z+cut),Vector3(x,y,z-cut),Vector3(x-cut,y,z),Vector3(-x+cut,y,z),Vector3(-x,y,z-cut),Vector3(-x,y,-z+cut)]))
	for level in 3:
		for i in 8:
			var next := (i + 1) % 8
			face(builder, [rings[level][i], rings[level+1][i], rings[level+1][next], rings[level][next]])
	for level in [0, 3]:
		for i in 8:
			var points := [Vector3(0, rings[level][0].y, 0), rings[level][i], rings[level][(i+1)%8]]
			if level == 0: points.reverse()
			face(builder, points)
	boxes[size] = builder.commit()
	return boxes[size]

static func face(builder: SurfaceTool, points: Array) -> void:
	# Godot front faces use clockwise winding. Outward normals are explicit.
	var normal: Vector3 = (points[2] - points[0]).cross(points[1] - points[0]).normalized()
	var center := Vector3.ZERO
	for point: Vector3 in points: center += point
	if normal.dot(center) < 0:
		points = points.duplicate()
		points.reverse()
		normal = -normal
	for i in range(1, points.size()-1):
		for point: Vector3 in [points[0], points[i], points[i+1]]:
			builder.set_normal(normal)
			builder.set_uv(Vector2(point.x, point.z))
			builder.add_vertex(point)

static func tapered_curve(points: Array[Vector3], radius: float, sides: int = 7) -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(points.size()-1):
		var direction := (points[j+1] - points[j]).normalized()
		var across := direction.cross(Vector3.UP).normalized()
		if across.length_squared() < .1: across = Vector3.RIGHT
		var other := across.cross(direction).normalized()
		for i in sides:
			var a := TAU * i / sides
			var b := TAU * (i+1) / sides
			var na := across * cos(a) + other * sin(a)
			var nb := across * cos(b) + other * sin(b)
			var r0 := radius * (1.0 - float(j) / points.size())
			var r1 := .006 if j == points.size()-2 else radius * (1.0 - float(j+1) / points.size())
			var vertices := [points[j]+na*r0, points[j+1]+na*r1, points[j+1]+nb*r1, points[j]+nb*r0]
			for k in [0, 2, 1, 0, 3, 2]:
				builder.set_normal(na if k in [0, 1] else nb)
				builder.set_uv(Vector2(float(i)/sides, float(j)/points.size()))
				builder.add_vertex(vertices[k])
	return builder.commit()
