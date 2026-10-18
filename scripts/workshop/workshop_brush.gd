class_name WorkshopBrush
extends RefCounted

# One BVH includes occluders as well as paintable triangles. Only the closest
# visible triangle is ever sampled. No UV-radius disk can cross another island.
var bvh := TriangleMesh.new()
var positions := PackedVector3Array()
var uvs := PackedVector2Array()
var paintable := PackedByteArray()
var material_indices := PackedInt32Array()
var color_regions: Array[String]=[]
var image: Image
var texture: ImageTexture
var before: Image
var coverage: Dictionary={}
var changed := false
var previous := Vector2.INF
var revision := 0

func _init() -> void:
	image=Image.create(1024,1024,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
	upload()

func build(root: Node3D, supported: bool) -> void:
	positions.clear();uvs.clear();paintable.clear();material_indices.clear();color_regions.clear()
	var material_index:=0
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh==null:continue
		for surface in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			if arrays.is_empty():continue
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			var active:=mesh.get_active_material(surface)
			var mat:=active as ShaderMaterial
			var color_region:=active.resource_name.trim_prefix("GTPart_") if active!=null and active.resource_name.begins_with("GTPart_") else ""
			var can_paint:=supported and uv.size()==vertices.size() and mat!=null and mat.shader==preload("res://assets/grimtable/materials/baked_finish.gdshader")
			var count:=indices.size() if not indices.is_empty() else vertices.size()
			for face in count/3:
				for j in 3:
					var i:=indices[face*3+j] if not indices.is_empty() else face*3+j
					positions.append(mesh.global_transform*vertices[i])
					uvs.append(uv[i] if uv.size()==vertices.size() else Vector2.ZERO)
				paintable.append(1 if can_paint else 0);material_indices.append(material_index);color_regions.append(color_region)
			material_index+=1
	if positions.size()>0:bvh.create_from_faces(positions)

func hit(origin: Vector3, direction: Vector3) -> Dictionary:
	if positions.is_empty():return {}
	var result:=bvh.intersect_ray(origin,direction)
	if result.is_empty():return {}
	var index:=int(result.face_index);var start:=index*3
	var bary:=Geometry3D.get_triangle_barycentric_coords(result.position,positions[start],positions[start+1],positions[start+2])
	result.uv=uvs[start]*bary.x+uvs[start+1]*bary.y+uvs[start+2]*bary.z
	result.paintable=paintable[index]==1
	result.material_index=material_indices[index]
	result.color_region=color_regions[index]
	return result

func begin() -> void:
	before=image.duplicate();coverage.clear();changed=false;previous=Vector2.INF

func dab(camera: Camera3D, screen: Vector2, color: Color, radius: float, opacity: float, erase: bool=false) -> bool:
	if before==null:begin()
	var steps:=1
	if previous!=Vector2.INF:steps=clampi(int(previous.distance_to(screen)/maxf(2,radius*.4)),1,24)
	var first:=screen if previous==Vector2.INF else previous
	for step in range(1,steps+1):
		var center:=first.lerp(screen,float(step)/steps)
		# Subpixel screen sampling is independent of atlas island size/direction.
		for y in range(-int(radius),int(radius)+1):
			for x in range(-int(radius),int(radius)+1):
				var falloff:=clampf((radius-Vector2(x,y).length())/2.0,0,1)
				if falloff<=0:continue
				var at:=center+Vector2(x,y)
				var point:=hit(camera.project_ray_origin(at),camera.project_ray_normal(at))
				if point.is_empty() or not point.paintable:continue
				var uv: Vector2=point.uv
				if uv.x<0 or uv.y<0 or uv.x>=1 or uv.y>=1:continue
				var pixel:=Vector2i(uv*1024);var key:=pixel.y*1024+pixel.x
				var alpha:=opacity*falloff
				if alpha<=float(coverage.get(key,0)):continue
				coverage[key]=alpha
				var old:=before.get_pixelv(pixel)
				var out: Color
				if erase:out=Color(old.r,old.g,old.b,old.a*(1-alpha))
				else:
					var a:=alpha+old.a*(1-alpha)
					var rgb:=(Vector3(color.r,color.g,color.b)*alpha+Vector3(old.r,old.g,old.b)*old.a*(1-alpha))/maxf(.0001,a)
					out=Color(rgb.x,rgb.y,rgb.z,a)
				if out!=image.get_pixelv(pixel):image.set_pixelv(pixel,out);changed=true
	previous=screen
	return changed

func end() -> bool:
	var result:=changed
	before=null;coverage.clear();previous=Vector2.INF
	if result:upload()
	return result

func upload() -> void:
	revision+=1
	var mip:=image.duplicate();mip.fix_alpha_edges();mip.generate_mipmaps()
	if texture==null:texture=ImageTexture.create_from_image(mip)
	else:texture.update(mip)

func restore(png: PackedByteArray) -> void:
	var restored:=Image.new()
	if restored.load_png_from_buffer(png)==OK and restored.get_size()==Vector2i(1024,1024):image=restored;image.convert(Image.FORMAT_RGBA8);upload()
