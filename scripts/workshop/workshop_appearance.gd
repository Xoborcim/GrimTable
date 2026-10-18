class_name WorkshopAppearance
extends RefCounted

const COMPONENTS := "res://assets/workshop/legion_components.glb"
static var scene: PackedScene
static var material_cache: Dictionary={}
static var island_image: Image
static var id_images: Dictionary={}

static func ids_path(source: String) -> String:
	return "res://assets/workshop/"+str({"legion_trooper":"legion_infantry","legion_walker":"heavy_walker","swarm_hunter":"swarm_creature"}.get(source,"legion_infantry"))+"_region_ids.png"

static func region_at(source: String,uv: Vector2) -> String:
	if not id_images.has(source):
		var image: Image=(load(ids_path(source)) as Texture2D).get_image()
		if image.is_compressed():image.decompress()
		id_images[source]=image
	var image: Image=id_images[source]
	var sample:=image.get_pixel(clampi(int(uv.x*image.get_width()),0,image.get_width()-1),clampi(int(uv.y*image.get_height()),0,image.get_height()-1))
	return {0:"primary",1:"primary",2:"secondary",3:"weapon",5:"trim",6:"glow",7:"cloth",8:"body",9:"body",10:"body",14:"metal"}.get(roundi(sample.r*255)-1,"primary")

static func island_at(uv: Vector2) -> int:
	if island_image==null:
		island_image=(load("res://assets/workshop/legion_uv_islands.png") as Texture2D).get_image()
		if island_image.is_compressed():island_image.decompress()
	var color:=island_image.get_pixel(clampi(int(uv.x*1023),0,1023),clampi(int(uv.y*1023),0,1023))
	return roundi(color.r*255)+roundi(color.g*255)*256+roundi(color.b*255)*65536

static func capable(source: String) -> Dictionary:
	return {"regions":source in AuthoredArt.MODELS,"brush":source=="legion_trooper","assembly":source=="legion_trooper","pose":source=="legion_trooper"}

static func imported_record(source: String) -> Dictionary:
	for record in MiniatureLibrary.records():
		if record.id==source:return record
	return {}

static func profile(source: String) -> Dictionary:
	if AuthoredArt.MODELS.has(source):return ContentRegistry.unit({"unit_id":source})
	var record:=imported_record(source)
	return ContentRegistry.unit({"unit_id":str(record.get("profile","legion_trooper"))})

static func instantiate(data: Dictionary) -> Node3D:
	var visual: Node3D
	var source: String=data.source
	if source=="legion_trooper":
		if scene==null:scene=load(COMPONENTS)
		visual=scene.instantiate();BakedMaterials.apply(visual)
	elif AuthoredArt.MODELS.has(source):visual=AuthoredArt.miniature(profile(source))
	else:
		var record:=imported_record(source)
		if record.is_empty():return null
		visual=MiniatureLibrary.instantiate_record(record)
	if visual==null:return null
	visual.set_meta("workshop_source",source)
	visual.scale*=float(data.scale);visual.rotation.y+=deg_to_rad(float(data.rotation));visual.position.y+=float(data.offset)
	if source=="legion_trooper":
		apply_parts(visual,data)
		var weapon:=visual.find_child("weapon_"+str(data.parts.weapon),true,false) as Node3D
		if weapon!=null:
			var muzzle:=Marker3D.new();muzzle.name="ArtMuzzle"
			muzzle.position=Vector3(5,26.6,17.6).rotated(Vector3.UP,deg_to_rad(-6))/25.4-Vector3(0,19.0/25.4,0)
			weapon.add_child(muzzle)
	apply_materials(visual,data,null,null,not str(data.id).is_empty())
	return visual

static func apply_parts(root: Node3D, data: Dictionary) -> void:
	for slot in WorkshopStore.PARTS:
		for i in WorkshopStore.PARTS[slot]:
			var part:=root.find_child(slot+"_"+str(i),true,false) as Node3D
			if part==null:continue
			part.visible=i==int(data.parts.get(slot,0))
			if not part.visible:continue
			# Head and complete upper assembly rotate about authored, stable pivots.
			var head: float=float(data.head_yaw)
			var torso: float=float(data.torso_yaw)
			var pose: String=data.pose
			var presets: Dictionary={"Neutral":[0,0],"Ready":[-8,2],"Aiming":[-18,-4],"Advancing":[10,6],"Heroic Display":[22,-6]}
			head=clampf(head+float(presets[pose][0]),-25,25);torso=clampf(torso+float(presets[pose][1]),-8,8)
			part.rotation.z=0;part.rotation.y=deg_to_rad(head if slot=="head" else 0)
			if slot in ["head","shoulders","backpack","weapon"]:
				var pivot:=Vector3(0,19.0/25.4,0)
				if not part.has_meta("socket_home"):part.set_meta("socket_home",part.position)
				part.position=pivot+(Vector3(part.get_meta("socket_home"))-pivot).rotated(Vector3.UP,deg_to_rad(torso))
				part.rotation.y+=deg_to_rad(torso)
	var torso_mesh:=root.find_child("torso_0",true,false) as Node3D
	if torso_mesh!=null:
		var presets: Dictionary={"Neutral":0,"Ready":2,"Aiming":-4,"Advancing":6,"Heroic Display":-6}
		torso_mesh.rotation.y=deg_to_rad(clampf(float(data.torso_yaw)+float(presets[data.pose]),-8,8))

static func overlay_texture(data: Dictionary) -> Texture2D:
	var path: String=str(data.get("overlay",""))
	if path.is_empty():return null
	if WorkshopStore.texture_cache.has(path):return WorkshopStore.texture_cache[path]
	if WorkshopStore.texture_cache.size()>64:WorkshopStore.texture_cache.clear()
	var img:=WorkshopStore.image(data,"overlay")
	if img==null:return null
	img.fix_alpha_edges();img.generate_mipmaps()
	var texture:=ImageTexture.create_from_image(img);WorkshopStore.texture_cache[path]=texture
	return texture

static func markings(data: Dictionary) -> Image:
	var image:=Image.create(1024,1024,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
	for decal: Dictionary in data.decals:
		var size:=float(decal.size)*1024
		var center:=Vector2(float(decal.u),float(decal.v))*1024
		var angle:=deg_to_rad(float(decal.angle))
		var color:=Color(str(decal.color));color.a=.95
		# Original compact stencil glyphs; no font atlas dependency in exports.
		var text_image: Image
		if decal.kind in ["Text","Number"]:text_image=stencil(str(decal.text).to_upper().left(12))
		for y in range(maxi(0,int(center.y-size)),mini(1024,int(center.y+size+1))):
			for x in range(maxi(0,int(center.x-size)),mini(1024,int(center.x+size+1))):
				var p:=(Vector2(x,y)-center).rotated(-angle)/size
				var draw:=false
				match str(decal.kind):
					"Stripe":draw=absf(p.y)<.16 and absf(p.x)<.95
					"Diamond":draw=absf(p.x)+absf(p.y)<.85 and absf(p.x)+absf(p.y)>.45
					"Hazard":draw=absf(p.y)<.3 and absf(p.x)<.95 and fmod((p.x+p.y+3)*6,2)<1
					"Text","Number":
						var q:=(p+Vector2.ONE)*.5*Vector2(text_image.get_size())
						if q.x>=0 and q.y>=0 and q.x<text_image.get_width() and q.y<text_image.get_height():draw=text_image.get_pixelv(Vector2i(q)).a>.3
				if draw and island_at(Vector2(x,y)/1024.0)==int(decal.island):image.set_pixel(x,y,color)
	return image


static func stencil(text: String) -> Image:
	const GLYPHS := {
		"0":"01110/10011/10101/11001/10001/10001/01110","1":"00100/01100/00100/00100/00100/00100/01110","2":"01110/10001/00001/00110/01000/10000/11111","3":"11110/00001/00001/01110/00001/00001/11110","4":"00010/00110/01010/10010/11111/00010/00010","5":"11111/10000/10000/11110/00001/00001/11110","6":"01110/10000/10000/11110/10001/10001/01110","7":"11111/00001/00010/00100/01000/01000/01000","8":"01110/10001/10001/01110/10001/10001/01110","9":"01110/10001/10001/01111/00001/00001/01110",
		"A":"01110/10001/10001/11111/10001/10001/10001","B":"11110/10001/10001/11110/10001/10001/11110","C":"01111/10000/10000/10000/10000/10000/01111","D":"11110/10001/10001/10001/10001/10001/11110","E":"11111/10000/10000/11110/10000/10000/11111","F":"11111/10000/10000/11110/10000/10000/10000","G":"01111/10000/10000/10111/10001/10001/01111","H":"10001/10001/10001/11111/10001/10001/10001","I":"11111/00100/00100/00100/00100/00100/11111","J":"00111/00010/00010/00010/00010/10010/01100","K":"10001/10010/10100/11000/10100/10010/10001","L":"10000/10000/10000/10000/10000/10000/11111","M":"10001/11011/10101/10101/10001/10001/10001","N":"10001/11001/10101/10011/10001/10001/10001","O":"01110/10001/10001/10001/10001/10001/01110","P":"11110/10001/10001/11110/10000/10000/10000","Q":"01110/10001/10001/10001/10101/10010/01101","R":"11110/10001/10001/11110/10100/10010/10001","S":"01111/10000/10000/01110/00001/00001/11110","T":"11111/00100/00100/00100/00100/00100/00100","U":"10001/10001/10001/10001/10001/10001/01110","V":"10001/10001/10001/10001/10001/01010/00100","W":"10001/10001/10001/10101/10101/11011/10001","X":"10001/10001/01010/00100/01010/10001/10001","Y":"10001/10001/01010/00100/00100/00100/00100","Z":"11111/00001/00010/00100/01000/10000/11111","-":"00000/00000/00000/11111/00000/00000/00000"}
	var image:=Image.create(maxi(1,text.length()*6),7,false,Image.FORMAT_RGBA8);image.fill(Color.TRANSPARENT)
	for i in text.length():
		var rows: PackedStringArray=str(GLYPHS.get(text[i],"00000/00000/00000/00000/00000/00000/00000")).split("/")
		for y in 7:
			for x in 5:
				if rows[y][x]=="1":image.set_pixel(i*6+x,y,Color.WHITE)
	return image

static func apply_materials(root: Node3D, data: Dictionary, overlay: Texture2D=null, marking: Texture2D=null, cache: bool=false) -> void:
	if overlay==null:overlay=overlay_texture(data)
	var cache_key:=JSON.stringify(data).sha256_text()
	var cached: Dictionary=material_cache.get(cache_key,{}) if cache else {}
	if marking==null and not data.decals.is_empty():
		if cached.has("marking"):marking=cached.marking
		else:
			var img:=markings(data);img.generate_mipmaps();marking=ImageTexture.create_from_image(img);cached.marking=marking
	var index:=0
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material=mesh.get_meta("workshop_original_"+str(surface),mesh.get_active_material(surface))
			mesh.set_meta("workshop_original_"+str(surface),original)
			var key:=(str(original.get_instance_id()) if original!=null else str(index))+":"+str(data.materials.get(str(index),""))
			var mat: Material=cached.get(key)
			if mat==null:
				if original is ShaderMaterial and original.shader==preload("res://assets/grimtable/materials/baked_finish.gdshader"):
					var baked:=original.duplicate() as ShaderMaterial
					baked.set_shader_parameter("workshop_enabled",true)
					baked.set_shader_parameter("region_ids",load(ids_path(data.source)))
					for region in data.colors:baked.set_shader_parameter(region+"_paint",Color(data.colors[region]))
					for pair in [["wash","wash_amount"],["drybrush","drybrush_amount"],["highlight","highlight_amount"],["weathering","weathering_amount"],["metallic","metallic_adjust"],["roughness","roughness_adjust"],["glow","glow_amount"]]:baked.set_shader_parameter(pair[1],data.effects.get(pair[0],WorkshopStore.EFFECTS[pair[0]]))
					baked.set_shader_parameter("has_overlay",overlay!=null);baked.set_shader_parameter("overlay_tex",overlay)
					baked.set_shader_parameter("has_markings",marking!=null);baked.set_shader_parameter("marking_tex",marking)
					mat=baked
				elif original is StandardMaterial3D:
					var simple:=original.duplicate() as StandardMaterial3D
					var part_region:=original.resource_name.trim_prefix("GTPart_")
					if original.resource_name.begins_with("GTPart_"):simple.albedo_color=Color(data.colors.get(part_region,data.colors.primary))
					elif data.materials.has(str(index)):simple.albedo_color=Color(data.materials[str(index)])
					# Original texture/normal/ORM maps survive material tint adjustments.
					simple.roughness=clampf(simple.roughness+float(data.effects.roughness),.25,.98)
					simple.metallic=clampf(simple.metallic+float(data.effects.metallic),0,1)
					mat=simple
				else:mat=original
				cached[key]=mat
			if mesh.mesh.get_surface_count()==1:mesh.material_override=mat
			else:mesh.set_surface_override_material(surface,mat)
			index+=1
	if cache:
		if material_cache.size()>64:material_cache.clear()
		material_cache[cache_key]=cached

static func add_base(root: Node3D, data: Dictionary, radius: float) -> void:
	var base:=CylinderMesh.new();base.top_radius=radius*.91;base.bottom_radius=radius;base.height=.16;base.radial_segments=48
	TableVisuals.mesh(root,base,Vector3(0,.08,0),Color(str(data.rim))).name="WorkshopRim"
	var top:=TableVisuals.cylinder(root,radius*.88,.04,Vector3(0,.18,0),Color.WHITE)
	var mat:=BakedMaterials.base(data.base_style).duplicate() as ShaderMaterial
	mat.set_shader_parameter("ground_tint",Color(str(data.ground))*1.6)
	top.material_override=mat;top.name="WorkshopGround"
	if not str(data.nameplate).is_empty():
		var label:=Label3D.new();label.text=data.nameplate;label.font_size=32;label.pixel_size=.002;label.position=Vector3(0,.09,-radius*.98);label.rotation.y=PI;label.modulate=Color("d7c8a8");root.add_child(label)

static func assigned(profile_data: Dictionary, model: String, squad: String) -> Node3D:
	var data:=WorkshopStore.assigned(profile_data,model,squad)
	if data.is_empty():return null
	var result:=instantiate(data)
	if result!=null:
		result.set_meta("workshop_data",data)
		# The battle keeps only selected components. The editor retains alternatives.
		if data.source=="legion_trooper":
			for slot in WorkshopStore.PARTS:
				for i in WorkshopStore.PARTS[slot]:
					var part:=result.find_child(slot+"_"+str(i),true,false)
					if part!=null and i!=int(data.parts.get(slot,0)):part.get_parent().remove_child(part);part.free()
	return result
