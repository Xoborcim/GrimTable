class_name UnitAnimationController
extends RefCounted

enum State { IDLE, SELECTED, MOVING, AIMING, ATTACKING, HIT, DEFEATED }
var model: Miniature
var state := State.IDLE
var offset := Vector3.ZERO
var home := Vector3(0,.2,0)
var base_rotation := Vector3.ZERO
var phase := 0.0
var motion_left := 0.0
var motion_duration := .5
var reaction := 0.0
var reaction_kind := State.IDLE
var aim := Vector3.ZERO
var player: AnimationPlayer
var clip_state := -1

func _init(piece: Miniature) -> void:
	model = piece
	home = piece.visual_root.position
	base_rotation = piece.visual_root.rotation
	phase = float(piece.cosmetic_id.hash() & 65535) / 65535.0 * TAU
	for node in piece.visual_root.find_children("*","AnimationPlayer",true,false):
		player = node
		break

func move_from(origin: Vector3, speed: String, reduced: bool) -> void:
	if reduced: return
	offset = origin - model.global_position
	motion_duration = .18 if speed == "Fast" else .52 if speed == "Normal" else .95
	motion_left = motion_duration

func react(value: int) -> void:
	reaction_kind = value
	reaction = .24 if value == State.HIT else .32

func update(delta: float, clock: float, reduced: bool, hovered: bool, aiming: bool) -> void:
	if not is_instance_valid(model) or not is_instance_valid(model.visual_root): return
	var root := model.visual_root
	motion_left = maxf(0,motion_left-delta)
	reaction = maxf(0,reaction-delta)
	state = State.DEFEATED if model.wounds <= 0 else reaction_kind if reaction > 0 else State.MOVING if motion_left > 0 else State.AIMING if aiming else State.SELECTED if model.selected or hovered else State.IDLE
	if reduced:
		motion_left = 0
		reaction = 0
		root.position = home
		root.rotation = base_rotation
		return
	var t := clock*1.7 + phase
	var faction: String = model.profile.get("faction","")
	var breathing := .018 if faction == "swarm" else .008
	var bob := sin(t)*breathing
	var rotation := base_rotation
	var position := home + Vector3.UP*bob
	if state == State.MOVING:
		var progress := motion_left / motion_duration
		position += offset * progress * progress * (3 - 2*progress)
		position.y += absf(sin(clock*22+phase)) * (.015 if "tank" in str(model.profile.get("id","")) else .06)
		rotation.z += sin(clock*22+phase)*.018
	elif state == State.ATTACKING:
		rotation.x -= sin(reaction/.32*PI)*.11
	elif state == State.HIT:
		rotation.z += sin(reaction/.24*PI)*.12
	elif state == State.DEFEATED:
		rotation.z += .3
	elif state in [State.SELECTED,State.AIMING]:
		rotation.x -= .035
		if aim != Vector3.ZERO:
			var direction := aim-model.global_position
			rotation.y = atan2(-direction.x,-direction.z)
	else: rotation.y += sin(t*.4)*.018
	root.position = position
	root.rotation = rotation
	if player != null and clip_state != state:
		clip_state = state
		var hints: Array = ["idle","alert","walk","aim","attack","hit","death"]
		var found := false
		for clip in player.get_animation_list():
			if hints[state] in clip.to_lower(): player.play(clip,.12); found = true; break
		if not found: player.stop()
