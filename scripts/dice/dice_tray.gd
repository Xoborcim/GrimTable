class_name DiceTray
extends CanvasLayer

signal finished
var settings: AppSettings
var panel: PanelContainer
var caption: Label
var outcome: Label
var viewport: SubViewport
var world: Node3D
var dice: Array[CinematicDie] = []
var queue: Array[Dictionary] = []
var current: Dictionary = {}
var elapsed := 0.0
var phase := ""
var settle_from: Array[Transform3D] = []
var roll_serial := 0
var sound: AudioStreamPlayer
var last_sound := 0

func _ready() -> void:
	layer = 8
	panel = PanelContainer.new()
	panel.theme = AppUI.theme()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -350; panel.offset_right = 350
	panel.offset_top = -445; panel.offset_bottom = -20
	var column := VBoxContainer.new()
	panel.add_child(column)
	caption = AppUI.label(column,"",18)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(670,255)
	container.stretch = true
	column.add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(670,255)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c151d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bbd0da")
	env.ambient_light_energy = .55
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-65,-25,0)
	light.light_energy = 1.4
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,14,8)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.2
	for item in [[Vector3(15,.3,6),Vector3(0,-.2,0)], [Vector3(15,2,.25),Vector3(0,.7,-3)], [Vector3(15,2,.25),Vector3(0,.7,3)], [Vector3(.25,2,6),Vector3(-7.5,.7,0)], [Vector3(.25,2,6),Vector3(7.5,.7,0)]]:
		var body := StaticBody3D.new()
		world.add_child(body)
		TableVisuals.box(body,item[0],item[1],Color("293138") if item[0].y > 1 else Color("172c2c"))
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = item[0]
		collider.shape = shape
		collider.position = item[1]
		body.add_child(collider)
	for x in [-6,6]: TableVisuals.line(world,PackedVector3Array([Vector3(x,.0,-2.5),Vector3(x,.0,2.5)]),Color("9e8351"))
	var result_scroll := ScrollContainer.new()
	result_scroll.custom_minimum_size = Vector2(670,48)
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(result_scroll)
	outcome = AppUI.label(result_scroll,"",14)
	outcome.custom_minimum_size.x = 640
	outcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := AppUI.row(column)
	AppUI.button(row,"Skip animation",skip)
	AppUI.button(row,"Dismiss all",cancel)
	sound = AudioStreamPlayer.new()
	add_child(sound)
	panel.hide()

func enqueue(title: String, values: Array, target: int = 7) -> void:
	if settings == null or settings.cinematic_dice == "Off": return
	if values.is_empty(): return
	# Every value remains in the exact summary; at most twelve physics bodies.
	queue.append({"title":title,"values":values.duplicate(),"target":target})
	if phase.is_empty(): next_roll()

func next_roll() -> void:
	for die in dice: die.queue_free()
	dice.clear()
	if queue.is_empty():
		phase = ""; panel.hide()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		finished.emit()
		return
	current = queue.pop_front()
	roll_serial += 1
	caption.text = "%s  /  %d D6" % [current.title,current.values.size()]
	outcome.text = "Rolling…" if current.values.size() <= 12 else "12 representative dice; complete pool shown below after settling."
	panel.show()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if current.has("summary"):
		outcome.text=current.summary
		elapsed=0; phase="result"
		return
	var cosmetic := RandomNumberGenerator.new()
	cosmetic.seed = roll_serial * 7919
	for i in mini(12,current.values.size()):
		var die := CinematicDie.new(int(current.values[i]),settings.dice_style)
		world.add_child(die)
		die.contact_monitor = true
		die.max_contacts_reported = 4
		die.body_entered.connect(func(_body: Node): tick_sound())
		die.position = Vector3((i%6-2.5)*1.8,2.2+float(i/6)*.7,(float(i/6)-.5)*1.8)
		die.rotation = Vector3(cosmetic.randf()*TAU,cosmetic.randf()*TAU,cosmetic.randf()*TAU)
		die.linear_velocity = Vector3(cosmetic.randf_range(-1,1),-2,cosmetic.randf_range(-1,1))
		die.angular_velocity = Vector3(cosmetic.randf_range(7,13),cosmetic.randf_range(5,11),cosmetic.randf_range(7,14))
		dice.append(die)
	elapsed = 0; phase = "physics"
	if settings.reduce_motion: skip()

func _process(delta: float) -> void:
	if phase.is_empty(): return
	elapsed += delta
	if phase == "physics":
		if elapsed > .3 and elapsed < .3+delta: tick_sound()
		if elapsed >= (1.7 if settings.cinematic_dice == "Full" else .6): begin_settle()
	elif phase == "settle":
		var t := smoothstep(0.0,1.0,elapsed/.4)
		for i in dice.size():
			var die := dice[i]
			die.position = settle_from[i].origin.lerp(Vector3((i%6-2.5)*1.8,.425,(float(i/6)-.5)*1.7),t)
			die.quaternion = settle_from[i].basis.get_rotation_quaternion().slerp(CinematicDie.final_rotation(die.result),t)
		if elapsed >= .4: reveal()
	elif phase == "result" and elapsed >= (1.2 if settings.cinematic_dice == "Full" else .6): next_roll()

func begin_settle() -> void:
	settle_from.clear()
	for die in dice:
		die.freeze = true
		settle_from.append(die.transform.orthonormalized())
	elapsed = 0; phase = "settle"

func reveal() -> void:
	if current.has("summary"): return
	for i in dice.size():
		var die := dice[i]
		die.freeze = true
		die.position = Vector3((i%6-2.5)*1.8,.425,(float(i/6)-.5)*1.7)
		die.quaternion = CinematicDie.final_rotation(die.result)
		die.highlight(die.result >= int(current.target))
	var exact: Array[String] = []
	for value in current.values: exact.append(("✓" if int(value) >= int(current.target) else "·")+str(value))
	outcome.text = "%d successes  /  %s" % [DiceManager.count_successes(current.values,int(current.target)),"  ".join(exact)]
	outcome.tooltip_text = str(current.values)
	elapsed = 0; phase = "result"
	tick_sound()

func skip() -> void:
	if not phase.is_empty(): reveal()

func cancel() -> void:
	queue.clear()
	for die in dice: die.queue_free()
	dice.clear()
	phase = ""; panel.hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func damage_summary(damage: int, failed: int) -> void:
	queue.append({"title":"DAMAGE","values":[],"summary":"%d failed armor saves · %d damage dealt" % [failed,damage]})
	if phase.is_empty(): next_roll()

func tick_sound() -> void:
	if settings.dice_volume <= 0: return
	var now := Time.get_ticks_msec()
	if now-last_sound < 70: return
	last_sound = now
	# Original short synthesized wood/metal impact, no external audio assets.
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var samples := PackedByteArray()
	for i in 1800:
		var sample := int(sin(i*.83)*sin(i*.17)*exp(-float(i)/240)*9000)
		samples.append_array(PackedByteArray([sample & 255,(sample >> 8) & 255]))
	wave.data = samples
	sound.stream = wave
	sound.volume_db = linear_to_db(settings.dice_volume)
	sound.play()
