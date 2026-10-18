extends SceneTree

var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("BAKED MATERIAL: "+label)

func run() -> void:
	for id in AuthoredArt.MODELS:
		var visual:=AuthoredArt.miniature(ContentRegistry.unit({"unit_id":id}))
		check(visual!=null,"Existing authored profile loads")
		if visual==null:continue
		var meshes:=visual.find_children("*","MeshInstance3D",true,false)
		check(not meshes.is_empty(),"Finished mesh present")
		var mat: ShaderMaterial=meshes[0].material_override
		check(mat!=null and mat.shader==preload("res://assets/grimtable/materials/baked_finish.gdshader"),"Shipping shader selected")
		for parameter in ["pigment","normal_tex","orm","finish_mask"]:
			var texture:=mat.get_shader_parameter(parameter) as Texture2D
			check(texture!=null and texture.get_width() in [1024,2048],"Texture dimensions / "+parameter)
			if texture!=null:check(texture.get_image().has_mipmaps(),"Mip chain / "+parameter)
		if id=="legion_trooper":
			var recolor:=mat.duplicate() as ShaderMaterial
			recolor.set_shader_parameter("primary_paint",Color("8c4035"))
			recolor.set_shader_parameter("secondary_paint",Color("b7c4a1"))
			for parameter in ["normal_tex","orm","finish_mask","paint_regions"]:
				check(recolor.get_shader_parameter(parameter)==mat.get_shader_parameter(parameter),"Recolor retains detail resource / "+parameter)
			check(recolor.get_shader_parameter("primary_paint")!=mat.get_shader_parameter("primary_paint"),"Paint can change independently")
			check(mat==meshes[0].material_override,"Recolor preview leaves shared material intact")
		visual.free()
	var foreign:=StandardMaterial3D.new();foreign.resource_name="User GLB Material"
	check(BakedMaterials.finish(foreign)==null,"User materials do not require paint masks")
	for style in ["Rubble","Industrial","Stone","Scorched"]:
		var mat:=BakedMaterials.base(style)
		check(mat!=null and mat.get_shader_parameter("relief") is Texture2D,"Base style reuses local normal bake")
	# Check both the baked material association and separate thin contact draws.
	for id: String in ["sanctum","station_hall"]:
		var path:="res://assets/terrain/environment/0131/"+id+".glb"
		var visual:=load(path).instantiate() as Node3D
		EnvironmentArt.weather_visual(visual,0)
		for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
			check(mesh.material_override is ShaderMaterial,"Environment uses baked finish")
			check((mesh.material_override as ShaderMaterial).get_shader_parameter("normal_tex") is Texture2D,"Environment normal association")
			if str(mesh.name).ends_with("_GroundContact"):
				check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Thin slabs remain shadow-free")
				check((mesh.material_override as ShaderMaterial).get_shader_parameter("ground_contact"),"Foundation dust enabled only for contact geometry")
		visual.free()
	print("GRIMTABLE BAKED MATERIAL: ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
