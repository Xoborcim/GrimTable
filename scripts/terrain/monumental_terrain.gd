class_name MonumentalTerrain
extends RefCounted

const STYLES := ["", "gothic", "pillar", "factory", "generator", "refinery", "pipes", "gantry", "bunker", "barricade", "crater", "rubble", "wreckage", "toxic", "tower", "pool"]
const PALETTE := {
	"concrete":["69665b",.0,.94],"stone":["82796a",.0,.9],"steel":["48545a",.72,.62],
	"military":["555e4f",.45,.76],"floor":["414b4d",.65,.83],"scorched":["252b2d",.6,.92],
	"sandstone":["9d8665",.0,.94],"rust":["74503a",.64,.9],"hazard":["aa8845",.35,.85],
	"rubble":["666052",.0,.98],"ceramic":["26363b",.2,.45],"energy":["70bdb3",.45,.3]}
static var materials := {}

static func material(key: String) -> Material:
	if materials.has(key): return materials[key]
	var data: Array = PALETTE.get(key,PALETTE.stone)
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://assets/grimtable/materials/weathered.gdshader")
	mat.set_shader_parameter("paint",Color(data[0]))
	mat.set_shader_parameter("metal",data[1])
	mat.set_shader_parameter("roughness",data[2])
	mat.set_shader_parameter("energy",1.0 if key == "energy" else 0.0)
	mat.set_shader_parameter("hazard",1.0 if key == "hazard" else 0.0)
	materials[key]=mat
	return mat

static func block(root: Node3D, size: Vector3, pos: Vector3, surface: String) -> MeshInstance3D:
	var mesh := TableVisuals.box(root,size,pos,Color.WHITE)
	mesh.material_override=material(surface)
	return mesh

static func cylinder(root: Node3D, radius: float, height: float, pos: Vector3, surface: String, top: float = -1) -> MeshInstance3D:
	var shape:=CylinderMesh.new()
	shape.bottom_radius=radius
	shape.top_radius=radius if top < 0 else top
	shape.height=height
	shape.radial_segments=16
	var mesh:=TableVisuals.mesh(root,shape,pos,Color.WHITE)
	mesh.material_override=material(surface)
	return mesh

static func beam(root: Node3D, start: Vector3, end: Vector3, radius: float, surface: String) -> void:
	var piece:=cylinder(root,radius,start.distance_to(end),(start+end)/2,surface)
	piece.quaternion=Quaternion(Vector3.UP,(end-start).normalized())

static func arch(root: Node3D, center: Vector3, width: float, height: float, thickness: float, broken: bool = false) -> void:
	# Original pointed masonry arch, individual stone blocks with real open space.
	for side in [-1,1]:
		block(root,Vector3(thickness,height*.58,thickness*1.3),center+Vector3(side*width/2,height*.29,0),"stone")
		block(root,Vector3(thickness*1.8,.2,thickness*1.7),center+Vector3(side*width/2,.14,0),"concrete")
		for i in 8:
			if broken and side == 1 and i > 3: continue
			var t0:=float(i)/8
			var t1:=float(i+1)/8
			var a:=center+Vector3(side*width/2*(1-t0),height*.58+height*.42*sin(t0*PI/2),0)
			var b:=center+Vector3(side*width/2*(1-t1),height*.58+height*.42*sin(t1*PI/2),0)
			var stone:=block(root,Vector3(thickness,a.distance_to(b)+.035,thickness*1.3),(a+b)/2,"stone")
			stone.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
		beam(root,center+Vector3(side*width/2,0,.36),center+Vector3(side*width/2,height*.65,0),thickness*.3,"rust")

static func ruin_wall(root: Node3D, extent: Vector3, center: Vector3, seed_value: int) -> void:
	var origin:=center-Vector3.UP*extent.y/2
	var count:=maxi(1,int(extent.x/2.8))
	block(root,Vector3(extent.x,extent.y*.27,extent.z),origin+Vector3.UP*extent.y*.135,"concrete")
	for i in count:
		var x: float=(i-(count-1)*.5)*extent.x/count
		# Surviving thick piers and fractured wall masses carry the window tracery.
		var wall_height: float=extent.y*(.74 if (i+seed_value)%3==0 else .48)
		block(root,Vector3(extent.x/count*.28,wall_height,extent.z*.95),origin+Vector3(x-extent.x/count*.4,wall_height/2,0),"stone")
		if (i+seed_value)%3!=0:
			var lintel:=block(root,Vector3(extent.x/count*.75,.65,extent.z),origin+Vector3(x,extent.y*.82,0),"stone")
			lintel.rotation.z=.08*(i%3-1)
		arch(root,origin+Vector3(x,.6,0),extent.x/count*.73,extent.y-.6,.27,((seed_value+i)%3)==0)
		var pier:=origin+Vector3(x-extent.x/count*.46,0,0)
		block(root,Vector3(.36,extent.y*.76,extent.z*1.7),pier+Vector3.UP*extent.y*.38,"concrete")
		var brace:=block(root,Vector3(.38,extent.y*.5,.42),pier+Vector3(0,extent.y*.23,.55),"stone")
		brace.rotation.x=-.23
		cylinder(root,.23,.9,pier+Vector3(0,extent.y*.81,0),"stone",.02)
		for side in [-1,1]:
			block(root,Vector3(.07,extent.y*.48,.10),origin+Vector3(x,extent.y*.35,side*.25),"rust")
	# Uneven surviving slabs, exposed braces and scorched fragments.
	for i in 7:
		var x: float=-extent.x*.45+i*extent.x*.13
		var height: float=.25+float((seed_value+i*17)%5)*.13
		var chip:=block(root,Vector3(.48,height,.5),origin+Vector3(x,.7+height*.5,0),"scorched" if i%3==0 else "rubble")
		chip.rotation.z=float(i%3-1)*.22

static func add(piece: TerrainPiece) -> void:
	var root:=Node3D.new()
	root.name="MonumentalArchitecture"
	piece.add_child(root)
	var s:=piece.size
	var seed_value:=piece.object_id.hash() & 0x7fffffff
	var style:=piece.art_style
	if style == "gothic":
		for part in piece.footprint():
			var wall:=Node3D.new()
			root.add_child(wall)
			var extent: Vector3=part.size
			var center: Vector3=part.center
			if extent.z > extent.x:
				wall.position=center
				wall.rotation.y=PI/2
				ruin_wall(wall,Vector3(extent.z,extent.y,extent.x),Vector3.ZERO,seed_value+1)
			else: ruin_wall(wall,extent,center,seed_value)
	elif style in ["pillar","tower"]:
		var r:=minf(s.x,s.z)*.42
		cylinder(root,r,s.y*.12,Vector3(0,s.y*.06,0),"concrete")
		cylinder(root,r*.6,s.y*.72,Vector3(0,s.y*.46,0),"stone",r*.42)
		for i in 6:
			var a:=i*TAU/6
			block(root,Vector3(.15,s.y*.72,.15),Vector3(cos(a)*r*.63,s.y*.46,sin(a)*r*.63),"rust")
		cylinder(root,r*.8,.25,Vector3(0,s.y*.84,0),"steel")
		if style=="tower":
			for i in 3: beam(root,Vector3(0,s.y*.8,0),Vector3((i-1)*r,s.y,0),.05,"steel")
		else: cylinder(root,r*.45,s.y*.15,Vector3(0,s.y*.93,0),"rubble",r*.3)
	elif style in ["generator","refinery","toxic"]:
		block(root,Vector3(s.x,.3,s.z),Vector3.UP*.15,"floor")
		var r:=minf(s.x,s.z)*.32
		cylinder(root,r,s.y*.70,Vector3(0,s.y*.4,0),"rust" if style != "generator" else "ceramic")
		cylinder(root,r*1.05,.24,Vector3(0,s.y*.75,0),"steel")
		cylinder(root,r,s.y*.23,Vector3(0,s.y*.9,0),"steel",r*.5)
		for i in 8:
			var a:=TAU*i/8
			var at:=Vector3(cos(a)*r,s.y*.42,sin(a)*r)
			cylinder(root,.11,s.y*.65,at,"energy" if style=="generator" else "rust")
		for side in [-1,1]:
			var at:=Vector3(side*s.x*.38,s.y*.35,0)
			cylinder(root,r*.22,s.y*.65,at,"steel")
			beam(root,at,Vector3(side*s.x*.38,.35,s.z*.42),.15,"rust")
	elif style == "pipes":
		for i in 3:
			var z: float=(i-1)*s.z*.28
			beam(root,Vector3(-s.x*.48,s.y*.55,z),Vector3(s.x*.48,s.y*.55,z),s.y*.28,"rust")
			for side in [-1,1]: cylinder(root,s.y*.3,.12,Vector3(side*s.x*.35,s.y*.55,z),"steel").rotation.z=PI/2
		for side in [-1,1]: block(root,Vector3(.35,s.y*.5,s.z),Vector3(side*s.x*.3,s.y*.25,0),"concrete")
	elif style == "crater":
		cylinder(root,minf(s.x,s.z)*.45,.05,Vector3.UP*.04,"scorched")
		for i in 16:
			var a:=TAU*i/16
			var chunk:=block(root,Vector3(.65,.13,.4),Vector3(cos(a)*s.x*.4,.065,sin(a)*s.z*.4),"rubble")
			chunk.rotation.y=-a
	elif style == "pool":
		var pool:=cylinder(root,minf(s.x,s.z)*.45,.03,Vector3.UP*.035,"ceramic")
		pool.scale.x=s.x/s.z
		var liquid:=StandardMaterial3D.new()
		liquid.albedo_color=Color("4e6734")
		liquid.roughness=.24; liquid.metallic=.4
		liquid.emission_enabled=true; liquid.emission=Color("263c11"); liquid.emission_energy_multiplier=.4
		pool.material_override=liquid
		for i in 14:
			var a:=TAU*i/14
			var stone:=block(root,Vector3(.5,.1,.3),Vector3(cos(a)*s.x*.44,.05,sin(a)*s.z*.44),"rust")
			stone.rotation.y=-a
	elif style in ["rubble","wreckage"]:
		for i in 22:
			var a:=float(i)*2.399
			var radius:=sqrt(float(i)/22)*.45
			var at:=Vector3(cos(a)*s.x*radius,.12+float(i%4)*.06,sin(a)*s.z*radius)
			var stone:=block(root,Vector3(.35+float(i%3)*.23,.2+float(i%4)*.15,.4+float(i%5)*.16),at,"rubble" if style=="rubble" else "scorched")
			stone.rotation=Vector3(i*.37,i*1.9,i*.11)
		if style=="wreckage":
			var hull:=block(root,s*Vector3(.7,.5,.6),Vector3.UP*s.y*.4,"military")
			hull.rotation.z=.24
			beam(root,Vector3(0,s.y*.7,0),Vector3(s.x*.45,s.y*.8,0),.13,"scorched")
	elif style in ["barricade","bunker"]:
		block(root,s*Vector3(1,.7,1),Vector3.UP*s.y*.35,"concrete")
		block(root,s*Vector3(1.02,.15,1.03),Vector3.UP*s.y*.77,"scorched")
		for side in [-1,1]:
			block(root,Vector3(s.x*.7,s.y*.12,.03),Vector3(0,s.y*.6,side*s.z*.51),"ceramic")
			block(root,Vector3(s.x*.6,.12,.05),Vector3(0,.25,side*s.z*.51),"hazard")
	else:
		# Manufactories and raised machinery decks stay within the known footprint.
		block(root,s*Vector3(1,.56,1),Vector3.UP*s.y*.28,"scorched")
		block(root,Vector3(s.x+.12,.22,s.z+.12),Vector3.UP*s.y*.58,"floor")
		for side in [-1,1]:
			for i in 4:
				var at:=Vector3((i-1.5)*s.x*.24,0,side*s.z*.42)
				block(root,Vector3(.22,s.y*.6,.4),at+Vector3.UP*s.y*.3,"steel")
				block(root,Vector3(s.x*.17,.16,.12),at+Vector3.UP*s.y*.45,"hazard")
		if style=="gantry":
			for side in [-1,1]: beam(root,Vector3(-s.x/2,s.y*.8,side*s.z*.4),Vector3(s.x/2,s.y*.8,side*s.z*.4),.055,"rust")
		else:
			for i in 3:
				var at:=Vector3((i-1)*s.x*.25,s.y*.78,0)
				cylinder(root,s.x*.08,s.y*.42,at,"rust")
				cylinder(root,s.x*.105,.15,at+Vector3.UP*s.y*.22,"steel")
	# Seeded dressing, clustered at the footprint perimeter, no added collision.
	for i in 12:
		var at:=Vector3((float((seed_value+i*19)%101)/100-.5)*s.x,.08,-s.z*.42)
		var rubble:=block(root,Vector3(.18+float(i%3)*.12,.14,.25),at,"rubble")
		rubble.rotation.y=i*1.7
	IndustrialDressing.merge(root)
