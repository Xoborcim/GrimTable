class_name BakedMaterials
extends RefCounted

const ROOT:="res://assets/materials/baked_0133/"
static var materials: Dictionary={}

static func base(style: String="Rubble") -> ShaderMaterial:
	var key:="base_"+style
	if materials.has(key):return materials[key]
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/grimtable/materials/baked_base.gdshader")
	mat.set_shader_parameter("base_style",{"Industrial":1,"Stone":2,"Scorched":3,"Ash":3}.get(style,0))
	mat.set_shader_parameter("relief",load(LocationComposition.MATERIALS+"fractured_normal.png"))
	mat.set_shader_parameter("cavity",load(LocationComposition.MATERIALS+"fractured_ao.png"))
	materials[key]=mat
	return mat

static func finish(original: Material,ground_contact: bool=false,bounds: AABB=AABB()) -> ShaderMaterial:
	if original==null or not original.resource_name.begins_with("GT_Baked0133_"):return null
	var id:=original.resource_name.trim_prefix("GT_Baked0133_")
	var key:=id+("_ground" if ground_contact else "")
	if materials.has(key):return materials[key]
	var folder:=ROOT+id+"/"
	if not ResourceLoader.exists(folder+"normal.png"):return null
	var mat:=ShaderMaterial.new();mat.shader=preload("res://assets/grimtable/materials/baked_finish.gdshader")
	mat.resource_name="BakedFinish_"+id
	for pair in [["pigment","pigment"],["orm","orm"],["normal_tex","normal"],["finish_mask","finish"]]:
		mat.set_shader_parameter(pair[0],load(folder+pair[1]+".png"))
	var paintable:=id in ["legion_infantry","heavy_walker"]
	mat.set_shader_parameter("paintable",paintable)
	if paintable:mat.set_shader_parameter("paint_regions",load(folder+"regions.png"))
	mat.set_shader_parameter("primary_paint",Color("315f86"))
	mat.set_shader_parameter("secondary_paint",Color("c5bda5"))
	mat.set_shader_parameter("trim_paint",Color("a08d5f"))
	mat.set_shader_parameter("material_family",1 if id=="swarm_creature" else 0 if paintable else 2 if id in ["sanctum","transept","breached_gate","shrine","crater"] else 3)
	mat.set_shader_parameter("normal_strength",.65 if paintable or id=="swarm_creature" else .80)
	mat.set_shader_parameter("ground_contact",ground_contact)
	if ground_contact:
		mat.set_shader_parameter("ground_bounds_min",bounds.position)
		mat.set_shader_parameter("ground_bounds_max",bounds.end)
	materials[key]=mat
	return mat

static func apply(root: Node3D) -> void:
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh.get_surface_count()!=1:continue
		var mat:=finish(mesh.get_active_material(0))
		if mat!=null:mesh.material_override=mat
