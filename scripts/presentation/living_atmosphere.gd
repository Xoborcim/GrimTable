class_name LivingAtmosphere
extends RefCounted

static func add(board: Battlefield) -> void:
	if board.scenario.id not in ["ashfall_station","ashen_basilica","ashfall_manufactorum","toxic_forge"]: return
	var root := Node3D.new()
	root.name = "LivingAtmosphere"
	board.visuals.add_child(root)
	# Machinery and gantry at the edge of the mat, clear of the fighting lanes.
	for side in [-1,1]:
		var at := Vector3(side*27,0,-15)
		TableVisuals.box(root,Vector3(1.9,1.0,2.4),at+Vector3.UP*.5,Color("46545a"))
		for j in 3:
			TableVisuals.cylinder(root,.22,1.5,at+Vector3((j-1)*.5,.8,0),Color("797767"))
			TableVisuals.box(root,Vector3(.3,.07,1.6),at+Vector3((j-1)*.5,1.6,0),Color("b69454"))
		var lamp := TableVisuals.box(root,Vector3(.13,.13,.13),at+Vector3(0,1.8,.6),Color("df9a61"))
		lamp.material_override = TableVisuals.material(Color("b28253"),true)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var steam := CPUParticles3D.new()
		steam.name = "Steam"
		steam.position = at+Vector3(0,1.6,0)
		steam.amount = maxi(1,int(10*float(board.scenario.board.get("atmosphere",.5))))
		steam.lifetime = 2.6
		steam.preprocess = 1
		steam.direction = Vector3.UP
		steam.spread = 20
		steam.gravity = Vector3(.08,.16,.02)
		steam.initial_velocity_min = .18
		steam.initial_velocity_max = .35
		steam.scale_amount_min = .2
		steam.scale_amount_max = .5
		var puff := SphereMesh.new()
		puff.radius = .23
		puff.height = .46
		puff.radial_segments = 8
		puff.rings = 4
		steam.mesh = puff
		var mat := TableVisuals.material(Color(.46,.53,.56,.10),true)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		steam.material_override = mat
		steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(steam)
		steam.add_to_group("ambient_steam")
		var light := OmniLight3D.new()
		light.position = at+Vector3(0,1.8,.6)
		light.light_color = Color("d7ae7c")
		light.light_energy = .45
		light.omni_range = 4
		light.shadow_enabled = false
		root.add_child(light)
	for x in [-1,1]:
		TableVisuals.box(root,Vector3(.32,4,.32),Vector3(22+x*2,2,18),Color("374b52"))
	TableVisuals.box(root,Vector3(4.5,.3,1.0),Vector3(22,4.1,18),Color("607278"))
	for i in 6:
		var rubble := TableVisuals.box(root,Vector3(.3+i*.03,.12,.4),Vector3(-25+i*.32,.06,17+sin(i)*.4),Color("65635b"))
		rubble.rotation.y = i*1.7
		rubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
