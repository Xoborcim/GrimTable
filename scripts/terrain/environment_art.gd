class_name EnvironmentArt
extends RefCounted

const ROOT:="res://assets/terrain/environment/"
const ASSETS:={"gatehouse":[8,12.4,3],"cloister":[8,6,1.4],"refinery_core":[7,11,6],"cooling_bank":[6,6,4],"breach_bunker":[7,3,4],"reliquary":[3,3.3,3],"hoist":[7,8,4],"trench":[8,.7,3]}
static var materials: Dictionary={}
static var weather_materials: Dictionary={}

static func weather_visual(root: Node3D,variant: int) -> void:
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name).ends_with("_GroundContact"):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.mesh.get_surface_count()==1:
			var baked:=BakedMaterials.finish(mesh.get_active_material(0),str(mesh.name).ends_with("_GroundContact"),mesh.mesh.get_aabb())
			if baked!=null:
				mesh.material_override=baked
				continue
		for surface in mesh.mesh.get_surface_count():
			var original:=mesh.get_active_material(surface) as StandardMaterial3D
			if original==null:continue
			var key:=str(original.get_instance_id())+":"+str(variant)
			if not weather_materials.has(key):
				var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/grimtable/materials/environment.gdshader")
				mat.set_shader_parameter("use_atlas",true);mat.set_shader_parameter("pigment",original.albedo_texture);mat.set_shader_parameter("orm",original.roughness_texture)
				mat.set_shader_parameter("paint",Color(1,1,1) if variant==0 else Color(.94,.92,.87) if variant==1 else Color(.85,.87,.85))
				mat.set_shader_parameter("damage",.25+variant*.28);weather_materials[key]=mat
			mesh.set_surface_override_material(surface,weather_materials[key])

static func material(key: String) -> ShaderMaterial:
	if materials.has(key): return materials[key]
	var colors:={"stone":"77766b","transition_stone":"626b60","tile":"666c69","roadstone":"454b46","ash":"474a43","brass":"8a7447","iron":"38454a","rust":"71513b","ivory":"9e9b83","soot":"292c29","hazard":"a58b4b","mud":"534838","sludge":"52603a"}
	var mat:=ShaderMaterial.new(); mat.shader=preload("res://assets/grimtable/materials/environment.gdshader")
	mat.set_shader_parameter("paint",Color(colors.get(key,"77766b")))
	mat.set_shader_parameter("metal",.65 if key in ["iron","rust","brass"] else 0)
	mat.set_shader_parameter("roughness",.73 if key in ["iron","brass"] else .94)
	materials[key]=mat
	return mat

static func box(root: Node3D,size: Vector3,at: Vector3,surface: String) -> MeshInstance3D:
	var obj:=TableVisuals.box(root,size,at,Color.WHITE); obj.material_override=material(surface)
	obj.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return obj

static func shard(root: Node3D,at: Vector3,width: float,height: float,angle: float,surface: String) -> void:
	# A chipped pentagonal slab instead of rectangular scatter blocks.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline:=[Vector2(-.5,-.42),Vector2(.3,-.5),Vector2(.53,-.18),Vector2(.4,.44),Vector2(-.43,.5)]
	for i in 5:
		var a: Vector2=outline[i]*width;var b: Vector2=outline[(i+1)%5]*width
		for point: Vector3 in [Vector3(0,height,0),Vector3(b.x,height,b.y),Vector3(a.x,height,a.y),Vector3(a.x,0,a.y),Vector3(a.x,height,a.y),Vector3(b.x,height,b.y),Vector3(a.x,0,a.y),Vector3(b.x,height,b.y),Vector3(b.x,0,b.y)]:st.add_vertex(point)
	st.generate_normals();st.index()
	var obj:=MeshInstance3D.new();obj.mesh=st.commit();obj.position=at;obj.rotation.y=angle;obj.material_override=material(surface)
	obj.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(obj)

static func marking(root: Node3D,at: Vector3,radius: float,surface: String,segments: int=40) -> void:
	for i in segments:
		if i%9==0:continue
		var a:=TAU*i/segments
		var part:=box(root,Vector3(radius*TAU/segments*.83,.008,.065),at+Vector3(sin(a)*radius,.018,cos(a)*radius),surface)
		part.rotation.y=a

static func stain(root: Node3D,at: Vector3,size: Vector2,color: Color) -> void:
	var shape:=PlaneMesh.new();shape.size=size
	var mesh:=MeshInstance3D.new();mesh.mesh=shape;mesh.position=at+Vector3.UP*.004
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/grimtable/materials/ground_wear.gdshader");mat.set_shader_parameter("stain",color)
	mesh.material_override=mat;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(mesh)

static func decorate(board: Battlefield) -> void:
	if board.scenario.board.get("surface_layout","Legacy")!="Legacy":
		LocationComposition.decorate(board);return
	var root:=Node3D.new();root.name="EnvironmentComposition";board.visuals.add_child(root)
	var theme: String=board.scenario.board.get("theme","cathedral")
	var density: String=board.scenario.board.get("clutter","Composed")
	var gothic:=theme=="cathedral"
	# A worn processional avenue or industrial spine, always flush to legal ground.
	for z in range(-int(board.depth/2)+2,int(board.depth/2)-1,3):
		for side in [-1,1]:
			shard(root,Vector3(side*1.55,.006,z),2.65,.018,.025*sin(z),"tile" if gothic else "iron")
			box(root,Vector3(.12,.018,2.7),Vector3(side*3.05,.015,z),"brass" if gothic else "rust")
	for side in [-1,1]:
		for x in range(-int(board.width/2)+2,int(board.width/2)-1,3):
			box(root,Vector3(2.6,.012,.09),Vector3(x,.015,side*7),"ivory" if gothic else "hazard")
	if gothic:
		# Surviving transverse paving is broken into displaced silhouette slabs.
		for x in range(-21,22,3):
			for z in [-3,0,3]:
				if (x+z)%5==0:continue
				shard(root,Vector3(x,.009,z),2.65,.023,.03*sin(x+z),"tile")
		# Low original ceramic inlays carry the former ceremonial use of the nave.
		for side in [-1,1]:
			for z in [-11,-9,-7,-5,-3]:
				shard(root,Vector3(-8+side*3.5,.012,z),1.5,.018,.08*sin(z),"ivory")
	# The center's broken floor rose gives the map a place-name and focal route.
	marking(root,Vector3.ZERO,6.0,"brass" if gothic else "rust",64)
	marking(root,Vector3.ZERO,6.3,"stone",64)
	for i in 12:
		var a:=i*TAU/12
		var ray:=box(root,Vector3(.12,.01,1.1),Vector3(sin(a)*5.2,.015,cos(a)*5.2),"ivory" if gothic else "hazard")
		ray.rotation.y=a
	# Damage pools are clustered at actual terrain bases, never random lane clutter.
	var rng:=RandomNumberGenerator.new();rng.seed=130
	for piece: TerrainPiece in board.terrain.get_children():
		var count:=12 if density=="Sparse" else 26 if density=="Composed" else 40
		if density=="None":count=0
		for i in count:
			var local:=Vector3(rng.randf_range(-piece.size.x*.55,piece.size.x*.55),.009,rng.randf_range(-piece.size.z*.55,piece.size.z*.55))
			var at:=piece.to_global(local)
			if absf(at.x)>board.width/2-.5 or absf(at.z)>board.depth/2-.5:continue
			# Outside blocked footprints debris stays below 0.1 inches.
			var blocked:=piece.blocks_movement and piece.overlaps_base(at,0)
			shard(root,at,rng.randf_range(.16,.6),rng.randf_range(.10,.32) if blocked else .055,rng.randf()*TAU,"stone" if gothic else "rust")
		# Ground-level storytelling: broken supply tiles and stains, no hidden bodies.
		if piece.blocks_los:
			marking(root,piece.position,minf(piece.size.x,piece.size.z)*.6,"soot",18)
	for objective: TableObjective in board.objectives.get_children():
		marking(root,objective.position,1.55,"brass" if gothic else "hazard",28)
		for side in [-1,1]:
			box(root,Vector3(.18,.025,.6),objective.position+Vector3(side*1.85,.025,0),"ivory")
	# Maintenance channels and embedded rails define routes rather than tall clutter.
	if not gothic:
		for side in [-1,1]:
			for z in range(-int(board.depth/2)+1,int(board.depth/2),2):
				box(root,Vector3(.8,.012,1.8),Vector3(side*10,.012,z),"soot")
				for j in 5:box(root,Vector3(.7,.018,.07),Vector3(side*10,.024,z+j*.32-.64),"iron")
	IndustrialDressing.merge(root)
	root.set_meta("cosmetic_only",true)
	# Transparent ground wear stays separate from the opaque batched mesh.
	var wear:=Node3D.new();wear.name="GroundWear";board.visuals.add_child(wear)
	for at in [Vector3(-14,0,-3),Vector3(4,0,2),Vector3(17,0,5),Vector3(-20,0,10),Vector3(16,0,-9)]:
		stain(wear,at,Vector2(8,6),Color(.08,.09,.09,.48) if gothic else Color(.16,.19,.075,.62) if theme=="toxic" else Color(.075,.075,.065,.65))
	atmosphere(board)

static func atmosphere(board: Battlefield) -> void:
	var amount: float=board.scenario.board.get("atmosphere",.5)
	if amount<=0 or board.scenario.board.get("weather","Theme")=="Clear":return
	var root:=Node3D.new();root.name="EnvironmentalVapor";board.visuals.add_child(root)
	var weather: String=board.scenario.board.get("weather","Theme")
	if weather=="Dust" or (weather=="Theme" and board.scenario.board.theme in ["cathedral","desert"]):
		var ash:=CPUParticles3D.new();ash.name="DriftingAsh";ash.amount=maxi(1,int(28*amount));ash.lifetime=9;ash.preprocess=3
		ash.position=Vector3(0,6,0);ash.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX;ash.emission_box_extents=Vector3(board.width*.46,2,board.depth*.46)
		ash.direction=Vector3(.2,-1,0);ash.spread=12;ash.gravity=Vector3(.03,-.02,0);ash.initial_velocity_min=.15;ash.initial_velocity_max=.35
		var flake:=QuadMesh.new();flake.size=Vector2(.055,.055);ash.mesh=flake
		var ash_mat:=StandardMaterial3D.new();ash_mat.albedo_color=Color(.6,.58,.51,.4);ash_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ash_mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;ash_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		ash.material_override=ash_mat;ash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(ash);ash.add_to_group("ambient_steam")
		return
	var vents:=0
	for piece: TerrainPiece in board.terrain.get_children():
		if vents>=3:break
		if not ("refinery" in piece.visual_scene or "cooling" in piece.visual_scene or "gatehouse" in piece.visual_scene):continue
		var particles:=CPUParticles3D.new();particles.name="SparseVapor"
		particles.position=piece.position+Vector3(0,piece.size.y*.7,0)
		particles.amount=maxi(1,int(12*amount));particles.lifetime=5;particles.preprocess=2
		particles.direction=Vector3.UP;particles.spread=18;particles.gravity=Vector3(.10,.04,0)
		particles.initial_velocity_min=.2;particles.initial_velocity_max=.4
		particles.scale_amount_min=.8;particles.scale_amount_max=1.8
		var quad:=QuadMesh.new();quad.size=Vector2(1.2,1.2);particles.mesh=quad
		var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/grimtable/materials/vapor.gdshader")
		mat.set_shader_parameter("tint",Color(.46,.52,.30,.10) if board.scenario.board.theme=="toxic" else Color(.5,.5,.47,.10))
		particles.material_override=mat;particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(particles);particles.add_to_group("ambient_steam");vents+=1
