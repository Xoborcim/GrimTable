class_name CombatPresentation
extends CanvasLayer

# Cosmetic playback of canonical results. This class never rolls gameplay dice.
var game: Node3D
var card: PanelContainer
var text: RichTextLabel
var sequence: Tween
var last_attack := -1
var effect: Node3D
var reveal_button: Button
var dice_button: Button
var shown_result: Dictionary = {}
var reveal_stage := 0
var ribbon: DiceRibbon
var health_seen := {}

func _ready() -> void:
	layer = 5
	card = PanelContainer.new()
	card.theme = AppUI.theme()
	add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	card.offset_left = 16
	card.offset_right = 410
	card.offset_top = 164
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	text = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = false
	text.scroll_following = true
	text.custom_minimum_size = Vector2(330, 190)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(text)
	ribbon = DiceRibbon.new()
	column.add_child(ribbon)
	ribbon.hide()
	dice_button = AppUI.button(column, "Show Dice", show_dice)
	reveal_button = AppUI.button(column, "Show Hits", reveal_next)
	AppUI.button(column, "Dismiss", dismiss)
	card.hide()
	game.combat.changed.connect(on_combat)
	game.manager.changed.connect(dismiss)
	game.history.changed.connect(hit_feedback)

func dismiss() -> void:
	if sequence != null: sequence.kill()
	card.hide()

static func dice_line(rolls: Array, threshold: int) -> String:
	var line := ""
	for roll in rolls:
		line += "[color=%s]%s%d[/color]  " % ["#a2ddcf" if int(roll) >= threshold else "#a4acb6", "+" if int(roll) >= threshold else "·", int(roll)]
	return line

func stage(title: String, rolls: Array, threshold: int, successes: int) -> void:
	text.text += "\n[b]%s[/b] · %d successes / %d dice · %d+\n" % [title,successes,rolls.size(),threshold]
	ribbon.show()
	ribbon.add_group(title,rolls,threshold)
	if game.settings.combat_resolution == "Manual": game.dice_tray.enqueue(title, rolls, threshold)

func on_combat() -> void:
	if game.combat.current == null:
		last_attack = -1
		dismiss()
		return
	var current: AttackResolution = game.combat.current
	if current.attack_id == last_attack: return
	last_attack = current.attack_id
	var result := current.result.duplicate(true)
	shown_result = result
	ribbon.groups.clear()
	ribbon.hide()
	dice_button.hide()
	reveal_button.hide()
	dismiss()
	if game.settings.particles: impact(result)
	if (game.settings.combat_camera or game.settings.camera_assistance) and not game.settings.reduce_motion:
		var a := game.battlefield.units.get_node_or_null(str(result.attacker_id)) as TableUnit
		var b := current.target
		if a != null and b != null and not a.living_models().is_empty() and not b.living_models().is_empty():
			game.camera_rig.focus((a.living_models()[0].global_position + b.living_models()[0].global_position) / 2)
	if game.settings.cinematic_dice != "Off" and game.settings.combat_resolution != "Manual":
		game.dice_tray.enqueue("HIT ROLL",result.hit_rolls,int(result.hit_target))
		game.dice_tray.enqueue("WOUND ROLL",result.wound_rolls,int(result.wound_target))
		game.dice_tray.enqueue("ARMOR SAVES",result.save_rolls,int(result.save_target))
		game.dice_tray.damage_summary(int(result.damage),int(result.failed_saves))
	if not game.settings.combat_summary: return
	card.show()
	GrimTheme.enter(card,game.settings.reduce_motion)
	text.text = "[b]%s → %s[/b]\n%s / %d attacks\n" % [result.attacking_unit, result.target_unit, result.weapon.name, result.attacks]
	if game.settings.combat_resolution == "Fast":
		text.text += "\n%d attacks; %d hit.\n%d could damage the target.\n%d got through its armor.\n\n[b]%d damage dealt.[/b]" % [result.attacks,result.hits,result.wounds,result.failed_saves,result.damage]
		text.tooltip_text = plain_result(result)
		dice_button.show()
		sequence = create_tween()
		sequence.tween_interval(5.0)
		sequence.tween_callback(card.hide)
		return
	if game.settings.combat_resolution == "Manual":
		reveal_stage = 0
		reveal_button.text = "Show Hits"
		reveal_button.show()
		return
	var delay := 0.12 if game.settings.combat_speed == "Fast" else 0.65 if game.settings.combat_speed == "Detailed" else 0.3
	if game.settings.reduce_motion: delay = 0.01
	sequence = create_tween()
	sequence.tween_callback(func(): stage("HITS", result.hit_rolls, int(result.hit_target), int(result.hits)))
	sequence.tween_interval(delay)
	sequence.tween_callback(func(): stage("WOUNDS", result.wound_rolls, int(result.wound_target), int(result.wounds)))
	sequence.tween_interval(delay)
	sequence.tween_callback(func():
		text.text += "\nSAVE: base %s+ / AP %s / cover %s → %s\n" % [str(result.target_profile.get("save", 3)), str(result.weapon.get("ap", 0)), str(result.get("cover_bonus", 0)), "impossible" if result.save_target > 6 else str(result.save_target) + "+"]
		stage("SAVES", result.save_rolls, int(result.save_target), int(result.wounds) - int(result.failed_saves)))
	sequence.tween_interval(delay)
	sequence.tween_callback(func(): text.text += "\n[b]%d FAILED SAVES × %d = %d DAMAGE[/b]\nAllocate damage in Attack Control." % [result.failed_saves, result.weapon.damage, result.damage])
	sequence.tween_interval(3.5 if game.settings.combat_speed == "Detailed" else 1.8)
	sequence.tween_callback(card.hide)

func impact(result: Dictionary) -> void:
	if is_instance_valid(effect): effect.queue_free()
	var a := game.battlefield.units.get_node_or_null(str(result.attacker_id)) as TableUnit
	var b := game.battlefield.units.get_node_or_null(str(result.target_id)) as TableUnit
	if a == null or b == null or a.living_models().is_empty() or b.living_models().is_empty(): return
	effect = Node3D.new()
	game.add_child(effect)
	var from := a.living_models()[0].cosmetic_muzzle()
	var to := b.living_models()[0].eye()
	var energy: bool = "pulse" in str(result.weapon.name).to_lower() or "synthetic" in str(result.weapon.get("id",""))
	var color := GrimTheme.PLAYER if energy else GrimTheme.IVORY
	if result.weapon.get("type","ranged") == "melee":
		var arc := PackedVector3Array()
		for i in 10: arc.append(to+Vector3(cos(i*.25)*.8,sin(i*.25)*.7,0))
		TableVisuals.line(effect,arc,GrimTheme.IVORY)
	else:
		var beam := TableVisuals.cylinder(effect,.025 if not energy else .045,from.distance_to(to),(from+to)/2,color)
		beam.quaternion = Quaternion(Vector3.UP,(to-from).normalized())
		beam.material_override = TableVisuals.material(color,true)
		var flash := SphereMesh.new()
		flash.radius = .14
		flash.height = .28
		TableVisuals.mesh(effect,flash,from,color).material_override = TableVisuals.material(color,true)
	for i in 5:
		var direction := Vector3(cos(i*1.26),.5+float(i%2)*.4,sin(i*1.26))
		TableVisuals.line(effect,PackedVector3Array([to,to+direction*.45]),color)
	var spark := TableVisuals.ring(effect,.18,color,0)
	spark.position = to
	for child in effect.get_children():
		if child is GeometryInstance3D: child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var animation := create_tween()
	animation.tween_property(spark,"scale",Vector3.ONE*2.4,.16)
	animation.tween_interval(.08)
	animation.tween_callback(effect.queue_free)

func hit_feedback() -> void:
	if not is_instance_valid(game) or not game.is_inside_tree(): return
	for unit: TableUnit in game.battlefield.units.get_children():
		for model in unit.models:
			var previous: int = health_seen.get(model.model_id,model.wounds)
			health_seen[model.model_id] = model.wounds
			if previous <= model.wounds or not game.settings.particles: continue
			var flash := TableVisuals.ring(game,model.base_radius+.1,GrimTheme.IVORY,.24)
			flash.position += model.global_position
			var animation := create_tween()
			if not game.settings.reduce_motion: animation.tween_property(flash,"scale",Vector3(1.15,1,1.15),.12)
			animation.tween_interval(.1)
			animation.tween_callback(flash.queue_free)

static func plain_result(result: Dictionary) -> String:
	return "%s made %d attacks.\n%d hit the target.\n%d were strong enough to damage it.\n%d got through its armor.\n\n[b]%d damage dealt.[/b]" % [result.attacking_unit, result.attacks, result.hits, result.wounds, result.failed_saves, result.damage]

func show_dice() -> void:
	if sequence != null: sequence.kill()
	dice_button.hide()
	for group in [["HITS", "hit_rolls", "hit_target", "hits"], ["WOUNDS", "wound_rolls", "wound_target", "wounds"]]:
		stage(group[0], shown_result[group[1]], int(shown_result[group[2]]), int(shown_result[group[3]]))
	stage("SAVES", shown_result.save_rolls, int(shown_result.save_target), int(shown_result.wounds) - int(shown_result.failed_saves))

func reveal_next() -> void:
	var result := shown_result
	if reveal_stage == 0: stage("HITS", result.hit_rolls, int(result.hit_target), int(result.hits)); reveal_button.text = "Show Wounds"
	elif reveal_stage == 1: stage("WOUNDS", result.wound_rolls, int(result.wound_target), int(result.wounds)); reveal_button.text = "Show Saves"
	elif reveal_stage == 2: stage("SAVES", result.save_rolls, int(result.save_target), int(result.wounds) - int(result.failed_saves)); reveal_button.text = "Show Damage"
	else: text.text += "\n[b]%d failed saves × %d = %d damage[/b]" % [result.failed_saves, result.weapon.damage, result.damage]; reveal_button.hide()
	reveal_stage += 1
