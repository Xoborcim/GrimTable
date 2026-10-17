class_name TableObjective
extends StaticBody3D

@export var number := 1
@export var radius := 3.0
var control_ring: MeshInstance3D
var marker_label: Label3D
var radius_ring: MeshInstance3D
var object_id := ""
var display_name := "Objective"
var hologram: ShaderMaterial
var context_radius := false
var control_stamp: Array = []

func _ready() -> void:
	add_to_group("objectives")
	collision_layer = 8
	collision_mask = 0
	TableVisuals.cylinder(self,.74,.15,Vector3(0,.075,0),Color("1b2c33"))
	TableVisuals.cylinder(self,.59,.14,Vector3(0,.22,0),Color("657273"))
	TableVisuals.cylinder(self,.40,.12,Vector3(0,.34,0),Color("283c43"))
	for i in 3:
		var offset := Vector3(cos(i*TAU/3)*.49,0,sin(i*TAU/3)*.49)
		TableVisuals.box(self,Vector3(.16,.65,.16),offset+Vector3.UP*.43,Color("364a52"))
		TableVisuals.box(self,Vector3(.19,.07,.19),offset+Vector3.UP*.78,Color("a3aaa0"))
	control_ring = TableVisuals.ring(self, 1.05, Color("dedbca"), .08)
	hologram = ShaderMaterial.new()
	hologram.shader = preload("res://assets/grimtable/materials/hologram.gdshader")
	var beam := TableVisuals.cylinder(self,.30,1.1,Vector3(0,1.13,0),Color.WHITE)
	beam.material_override = hologram
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := TableVisuals.ring(self,.43,Color("e3ddc5"),1.7)
	halo.rotation.x = .22
	# Cosmetic variants preserve the same base, picking and control radius.
	if number % 3 == 1:
		for side in [-1,1]:
			TableVisuals.box(self,Vector3(.1,1.6,.35),Vector3(side*.42,.95,0),Color("586c76"))
			TableVisuals.box(self,Vector3(.14,.05,.4),Vector3(side*.42,1.76,0),Color("bdc5ba"))
	elif number % 3 == 2:
		for i in 6:
			var fin := TableVisuals.box(self,Vector3(.14,.5,.25),Vector3(cos(i*TAU/6)*.5,.65,sin(i*TAU/6)*.5),Color("737b6b"))
			fin.rotation.y = -i*TAU/6
	else:
		var artifact := PrismMesh.new()
		artifact.size = Vector3(.55,.85,.55)
		var item := TableVisuals.mesh(self,artifact,Vector3(0,1.35,0),Color.WHITE)
		item.material_override = hologram
	marker_label = TableVisuals.label(self, "Objective " + str(number) + "\nNeutral", Vector3(0, 3.2, 0), Color("ffe5a2"))
	marker_label.font_size = 36
	marker_label.pixel_size = .017
	radius_ring = TableVisuals.ring(self, radius, Color("e7cb81"))
	radius_ring.visible = false
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.85
	shape.height = 2.8
	collider.shape = shape
	collider.position.y = 1.4
	add_child(collider)

func present(control: Dictionary, player: int) -> void:
	var contested: bool = control.owner < 0 and control.counts["0"] > 0 and control.counts["1"] > 0
	marker_label.text = "◇ Objective %d\n%s" % [number, "Contested" if contested else "Neutral" if control.owner < 0 else "YOUR TEAM" if control.owner == player else "ENEMY"]
	var stamp := [control.owner,contested,player]
	if stamp == control_stamp: return
	if not control_stamp.is_empty():
		var battle := get_parent().get_parent().get_parent()
		var settings: AppSettings = battle.get("settings")
		celebrate(settings.reduce_motion if settings != null else false)
	control_stamp = stamp
	var color := GrimTheme.IVORY if control.owner < 0 else GrimTheme.PLAYER if control.owner == player else GrimTheme.ENEMY
	hologram.set_shader_parameter("tint",color)
	hologram.set_shader_parameter("contested",1.0 if contested else 0.0)
	control_ring.material_override = TableVisuals.material(color,true)

func celebrate(reduced: bool) -> void:
	if reduced: return
	create_tween().tween_method(func(value: float): hologram.set_shader_parameter("pulse",value),1.0,0.0,.55)
