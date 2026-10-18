class_name AuthoredArt
extends RefCounted

# Cosmetic defaults. Profiles, hashes, colliders and LOS never depend on this map.
const MODELS := {
	"legion_trooper":"res://assets/miniatures/legion/legion_infantry.glb",
	"legion_walker":"res://assets/miniatures/legion/heavy_walker.glb",
	"swarm_hunter":"res://assets/miniatures/swarm/swarm_creature.glb"}
const BASILICA := "res://assets/terrain/gothic/ruined_basilica.glb"
const GROUND := "res://assets/miniatures/bases/scenic_ground.glb"
static var scenes: Dictionary = {}

static func instantiate(path: String) -> Node3D:
	if not ResourceLoader.exists(path): return null
	if not scenes.has(path): scenes[path]=load(path) as PackedScene
	if scenes[path]==null: return null
	var visual:=scenes[path].instantiate() as Node3D
	if visual!=null:
		visual.set_meta("authored_art","0.12.0")
		BakedMaterials.apply(visual)
	return visual

static func miniature(profile: Dictionary) -> Node3D:
	var id: String=profile.get("id","")
	if not MODELS.has(id) or profile.has("preferred_model") or profile.has("preferred_scene"): return null
	if profile.get("model_scene","")!="res://assets/grimtable/models/"+id+".tscn": return null
	var visual:=instantiate(MODELS[id])
	if visual!=null and id in ["legion_trooper","legion_walker"]:
		var meshes:=visual.find_children("*","MeshInstance3D",true,false)
		if not meshes.is_empty():
			var muzzle:=Marker3D.new()
			muzzle.name="ArtMuzzle"
			# Sculpt coordinates converted to local Y-up, before the export yaw.
			muzzle.position=(Vector3(5,26.6,17.6).rotated(Vector3.UP,deg_to_rad(-6)) if id=="legion_trooper" else Vector3(35,57,45.5))/25.4
			meshes[0].add_child(muzzle)
	return visual

static func terrain(kind: String, style: String, size: Vector3) -> Node3D:
	if kind!="ruin" or style!="gothic" or not size.is_equal_approx(Vector3(13,10,7)): return null
	var visual:=instantiate(BASILICA)
	if visual!=null: visual.name="MonumentalArchitecture"
	return visual
