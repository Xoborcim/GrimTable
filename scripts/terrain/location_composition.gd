class_name LocationComposition
extends RefCounted

const MATERIALS:="res://assets/terrain/environment/0131/materials/"

static func decorate(board: Battlefield) -> void:
	var root:=Node3D.new();root.name="EnvironmentComposition";board.visuals.add_child(root)
	root.set_meta("cosmetic_only",true)
	# Every collapse fan is tied to an authored damage event, not a prop center.
	var layouts: Dictionary=ContentRegistry.read_json("res://resources/environment/layouts_0131.json")
	var layout: Dictionary=layouts.get(str(board.scenario.board.surface_layout),{})
	var rng:=RandomNumberGenerator.new();rng.seed=131
	var density: String=board.scenario.board.get("clutter","Composed")
	var count: int={"None":0,"Sparse":24,"Composed":60,"Dense":90}.get(density,60)
	for event: Dictionary in layout.get("damage",[]):
		var origin:=Vector2(float(event.at[0]),float(event.at[1]))
		var direction:=Vector2(float(event.direction[0]),float(event.direction[1])).normalized()
		for i in count:
			var t:=rng.randf();var distance: float=t*float(event.radius)*1.6
			var point:=origin+direction*distance+direction.orthogonal()*rng.randf_range(-1,1)*(.3+distance*.36)
			# Low fragments in playable ground never add a hidden obstacle.
			EnvironmentArt.shard(root,Vector3(point.x,.008,point.y),rng.randf_range(.12,.45)*(1-t*.4),rng.randf_range(.025,.065),rng.randf()*TAU,("transition_stone" if t>.45 else "stone") if board.scenario.board.surface_layout=="Sanctum" else "rust")
	# Surviving curbs are short, broken pieces that follow the building floor plan.
	for polygon: Array in layout.get("foundation_polygons",[]):
		for i in polygon.size():
			var start:=Vector2(float(polygon[i][0]),float(polygon[i][1]))
			var end:=Vector2(float(polygon[(i+1)%polygon.size()][0]),float(polygon[(i+1)%polygon.size()][1]))
			var direction: Vector2=(end-start).normalized()
			for step in int(start.distance_to(end)/1.6):
				if step%4==1:continue
				var point:=start+direction*(step*1.6+.5)
				var curb:=EnvironmentArt.box(root,Vector3(1.1,.045,.15),Vector3(point.x,.025,point.y),"stone")
				curb.rotation.y=-atan2(direction.y,direction.x)
	for objective: TableObjective in board.objectives.get_children():EnvironmentArt.marking(root,objective.position,1.4,"brass",24)
	if board.scenario.board.surface_layout=="Transport":
		# Embedded cargo rails follow the transport corridor. Missing lengths
		# and a broken cross-junction mark the bombardment, with no new collision.
		for x in [-12.0,-8.0]:
			for z in range(-19,20,2):
				if z in [-3,-1,9]:continue
				EnvironmentArt.box(root,Vector3(.065,.022,1.75),Vector3(x,.018,z),"iron")
		for x in range(10,24):
			if x%4==0:continue
			var stripe:=EnvironmentArt.box(root,Vector3(.25,.012,.55),Vector3(x,.026,-2.3),"hazard")
			stripe.rotation.y=.45
	var approaches: Dictionary=ContentRegistry.read_json("res://resources/environment/approaches_0132.json")
	for approach: Dictionary in approaches.get(str(board.scenario.board.surface_layout),[]):
		decorate_approach(root,board,approach,density)
	IndustrialDressing.merge(root)
	EnvironmentArt.atmosphere(board)

static func decorate_approach(root: Node3D,board: Battlefield,record: Dictionary,density: String) -> void:
	# Shallow surviving road margins, authored per location, never physics bodies.
	# A private stream keeps this dressing independent of gameplay and damage RNG.
	var rng:=RandomNumberGenerator.new();rng.seed=int(record.seed)
	var start:=Vector2(float(record.from[0]),float(record.from[1]))
	var end:=Vector2(float(record.to[0]),float(record.to[1]))
	var direction: Vector2=(end-start).normalized()
	var side:=direction.orthogonal()
	var width:=float(record.width)
	var distance:=.35
	while distance<start.distance_to(end)-.5:
		var length:=rng.randf_range(.65,1.55)
		for edge: int in record.get("edges",[-1,1]):
			if rng.randf()<.48:continue
			var at: Vector2=start+direction*distance+side*(edge*width*.38+rng.randf_range(-.15,.15))
			if absf(at.x)>board.width*.5-.8 or absf(at.y)>board.depth*.5-.8:continue
			var span:=rng.randf_range(.20,.40)*minf(width,1.2)
			approach_slab(root,at,direction,span,length,str(record.surface),rng)
			if density!="None" and rng.randf()>(.7 if density=="Sparse" else .3):
				var chip: Vector2=at+side*edge*(span*.5+.14)+direction*rng.randf_range(-.4,.4)
				EnvironmentArt.shard(root,Vector3(chip.x,.005,chip.y),rng.randf_range(.12,.23),.025,rng.randf()*TAU,str(record.surface))
		distance+=length+rng.randf_range(.18,.85)

static func approach_slab(root: Node3D,at: Vector2,direction: Vector2,width: float,length: float,surface: String,rng: RandomNumberGenerator) -> void:
	# Individually chipped convex silhouettes avoid intact square tile fields.
	var points: Array[Vector2]=[
		Vector2(-.5,-rng.randf_range(.22,.40)),Vector2(-rng.randf_range(.18,.35),-.5),
		Vector2(rng.randf_range(.25,.46),-.5),Vector2(.5,rng.randf_range(-.10,.25)),
		Vector2(rng.randf_range(.16,.40),.5),Vector2(-.5,rng.randf_range(.25,.44))]
	var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES);builder.set_smooth_group(-1)
	var side:=direction.orthogonal()
	var height:=rng.randf_range(.014,.032)
	for i in points.size():
		var a:=at+side*points[i].x*width+direction*points[i].y*length
		var b:=at+side*points[(i+1)%points.size()].x*width+direction*points[(i+1)%points.size()].y*length
		# Flat tops and shallow sides have consistent winding, with no new shadows.
		for vertex: Vector3 in [Vector3(at.x,height,at.y),Vector3(a.x,height,a.y),Vector3(b.x,height,b.y),Vector3(a.x,.003,a.y),Vector3(b.x,height,b.y),Vector3(a.x,height,a.y),Vector3(a.x,.003,a.y),Vector3(b.x,.003,b.y),Vector3(b.x,height,b.y)]:builder.add_vertex(vertex)
	builder.generate_normals();builder.index()
	var mesh:=MeshInstance3D.new();mesh.mesh=builder.commit()
	mesh.material_override=EnvironmentArt.material(surface)
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
