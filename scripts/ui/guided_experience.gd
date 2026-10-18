class_name GuidedExperience
extends Node

# Presentation only. Decisions still go through the existing action controllers.
const PHASE_NAMES := ["Move", "Move", "Shoot", "Charge", "Fight", "Score"]
const INSTRUCTIONS := ["Position your squads around the battlefield.", "Position your squads around the battlefield.", "Choose a squad, then choose an enemy to attack.", "Bring a squad close enough to fight an enemy.", "Attack enemies within close-combat range.", "Objectives are counted and points are awarded."]
var game: Node3D
var steps: Array[Label] = []
var instruction: Label
var guidance_label: Label
var hint_card: PanelContainer
var hint_title: Label
var hint_text: Label
var hint_key := ""
var toast: Label
var why_button: Button
var why_text: Label
var round_card: PanelContainer
var round_text: Label
var labels: Dictionary = {}
var refresh_pending := false
var last_round := 1
var last_score := {"0": 0, "1": 0}
var objective_stamp := -1
var stamp := ""
var advanced := false
var measure_button: Button
var done_button: Button
var primary_style: StyleBoxFlat
var timeline: PhaseTimeline
var label_layout: DioramaLabels
var unit_card: UnitCard
var last_card_unit := ""

func _ready() -> void:
	last_round = game.manager.round_number
	last_score = game.manager.scores.duplicate()
	var hud: TableHUD = game.hud
	var header: Control = hud.top_panel.get_child(0)
	hud.top_panel.remove_child(header)
	var chrome := VBoxContainer.new()
	chrome.add_theme_constant_override("separation", 5)
	hud.top_panel.add_child(chrome)
	chrome.add_child(header)
	var strip := VBoxContainer.new()
	chrome.add_child(strip)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	strip.add_child(box)
	var row := PhaseTimeline.new()
	timeline = row
	box.add_child(row)
	for i in 5:
		var item := hud._label(row, ["➜  Move", "⊕  Shoot", "»  Charge", "⚔  Fight", "◇  Score"][i], 17)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		item.custom_minimum_size.y = 34
		item.add_theme_font_size_override("font_size", roundi(13*game.settings.ui_scale))
		steps.append(item)
	var help := hud._button(row, "How to play", show_phase_help)
	help.add_theme_font_size_override("font_size", 12)
	instruction = hud._label(box, "", 14, Color("b8c9d1"))
	guidance_label = hud.action_title
	guidance_label.custom_minimum_size.x = 160
	guidance_label.clip_text = true
	guidance_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var manual_grid := GridContainer.new()
	manual_grid.columns = 2
	hud.advanced_box.add_child(manual_grid)
	# Move legacy toolbar tools into the existing scrollable Advanced card.
	# They keep their original callbacks and keyboard bindings.
	for control in hud.advanced_controls:
		if control is Button and control.get_parent() == hud.next_action_button.get_parent(): control.reparent(manual_grid)
	for button: Button in [hud.advanced_button, hud.undo_button]: button.add_theme_font_size_override("font_size", 12)
	measure_button = hud._button(hud.action_row, "Measure", func(): game.interaction.set_mode(2))
	done_button = hud._button(hud.action_row, "Done", func(): game.interaction.cancel(); game.selection.clear())
	primary_style = GrimTheme.primary()
	hud.confirm_move.add_theme_stylebox_override("normal",primary_style)
	game.assistance.commit_button.add_theme_stylebox_override("normal",primary_style)
	for primary: Button in [game.assistance.move_button, game.assistance.attack_button, game.assistance.charge_button]:
		primary.custom_minimum_size = Vector2(92, 38)
		primary.add_theme_stylebox_override("normal", primary_style)
	for pair in [[game.assistance.move_button,"move"],[game.assistance.attack_button,"shoot"],[game.assistance.charge_button,"charge"],[measure_button,"measure"]]: pair[0].icon = GrimTheme.icon(pair[1])
	var dock_actions: Node = hud.next_action_button.get_parent()
	for button: Button in [hud.next_action_button,hud.continue_button,hud.undo_button,hud.advanced_button]: button.reparent(hud.action_row)
	for control in dock_actions.get_children():
		if control is Button: control.reparent(manual_grid)
		else: control.hide()
	hud.status.hide()
	var inspect_parent: VBoxContainer = hud.selected_info.get_parent()
	unit_card = UnitCard.new()
	unit_card.scale_factor = game.settings.ui_scale
	unit_card.inspect_requested.connect(func():
		var model: Miniature=game.selection.primary()
		if model==null or game.get_node_or_null("MiniatureInspection")!=null: return
		var inspector:=MiniatureInspector.new()
		inspector.name="MiniatureInspection"
		inspector.game=game; inspector.model=model
		game.add_child(inspector))
	inspect_parent.add_child(unit_card)
	inspect_parent.move_child(unit_card,0)
	label_layout = DioramaLabels.new()
	label_layout.game = game
	hud.root.add_child(label_layout)
	labels = label_layout.squad_labels

	game.assistance.hint.hide()
	game.assistance.roster.hide()
	hud.assistant_label.hide()
	hud.next_unit_button.hide()
	hint_card = hud._panel(16, 164, 294, 164, Control.PRESET_TOP_LEFT)
	var hints := VBoxContainer.new()
	hint_card.add_child(hints)
	hint_title = hud._label(hints, "Welcome to Ashfall", 17, Color("a4e5d8"))
	hint_text = hud._label(hints, "", 14)
	hint_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_text.custom_minimum_size.x = 215
	hint_text.add_theme_font_size_override("font_size", roundi(13*game.settings.ui_scale))
	hint_card.add_theme_stylebox_override("panel", GrimTheme.surface(GrimTheme.PLAYER.darkened(.4),true))
	hud._button(hints, "Got it", dismiss_hint)
	toast = hud._label(hud.root, "", 20, Color("ffe3a8"))
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_top = 165
	toast.offset_left = -240
	toast.offset_right = 240
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.hide()
	var preview_box: VBoxContainer = game.assistance.preview.get_parent().get_parent()
	why_button = hud._button(preview_box, "Why can these models attack?", func(): why_text.visible = not why_text.visible)
	why_text = hud._label(preview_box, "", 13)
	why_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why_text.hide()
	round_card = hud._panel(-230, -165, 230, 165, Control.PRESET_CENTER)
	var round_box := VBoxContainer.new()
	round_card.add_child(round_box)
	round_text = hud._label(round_box, "", 21)
	round_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	round_text.custom_minimum_size.x = 420
	hud._button(round_box, "Start next round", func():
		round_card.hide()
		game.assistance.understood("round_summary")
		if game.manager.phase == 0 and game.settings.assistance in ["Guided", "Standard"]: game.hud.advance_with_warning())
	round_card.hide()
	for source in [game.selection.changed, game.manager.changed, game.history.changed, game.combat.changed, game.interaction.movement_changed]: source.connect(schedule_refresh)
	game.interaction.damage_click = allocate_clicked
	var timer := Timer.new()
	timer.wait_time = .08
	timer.timeout.connect(refresh_label_distance)
	add_child(timer)
	timer.start()
	schedule_refresh()

func player_team() -> int:
	if game.get("ai") != null and not game.ai.config.is_empty(): return int(game.ai.config.get("human_team",0))
	return 0 if game.network_session == null or game.network_session.host else 1

func schedule_refresh() -> void:
	if refresh_pending or not is_inside_tree(): return
	refresh_pending = true
	call_deferred("refresh")

func continuation() -> String:
	if game.manager.phase == 4 and game.manager.active_team == 0: return "Review turn"
	if game.manager.phase == 5 and game.manager.active_team == 1: return "Finish round"
	return ["Start moving", "Continue to Shooting", "Continue to Charge", "Continue to Fight", "Count points", "Finish turn"][game.manager.phase]

func refresh() -> void:
	refresh_pending = false
	if not is_instance_valid(game) or not game.is_inside_tree() or game.is_queued_for_deletion(): return
	if game.replay_mode or game.editing: return
	if game.get("ai") != null and game.ai.finished:
		round_card.hide()
		hint_card.hide()
		return
	var hud: TableHUD = game.hud
	var assistant: TurnAssistant = game.assistance
	var unit: TableUnit = game.selection.selected_unit()
	var moving: bool = game.interaction.session != null
	var pending: bool = game.combat.current != null and game.combat.current.remaining > 0
	var index := maxi(0, game.manager.phase - 1)
	timeline.current = index
	timeline.queue_redraw()
	for i in steps.size():
		steps[i].modulate = Color("9aead8") if i == index else Color("889da8") if i < index else Color("536572")
		steps[i].text = ("✓  " if i < index else "➜  " if i == index else "    ") + ["Move", "Shoot", "Charge", "Fight", "Score"][i]
	instruction.text = INSTRUCTIONS[game.manager.phase]
	if game.manager.phase == 0 and not game.manager.deployment: instruction.text = "Start moving when you're ready to begin your turn."
	if game.manager.phase == 5 and game.manager.active_team == 0: instruction.text = "Your turn is complete. Swap sides; objectives score after both teams have played."
	var us := player_team()
	hud.turn_label.text = "Round %d    ·    %s    |    You  %d   —   %d  Enemy" % [game.manager.round_number, "Your turn" if game.manager.active_team == us else "Enemy turn · local players swap sides" if game.network_session == null and game.ai.config.is_empty() else "Enemy turn", game.manager.scores[str(us)], game.manager.scores[str(1-us)]]
	if game.manager.deployment: hud.turn_label.text = "Place your squads    |    Keep them inside your deployment zone"
	hud.continue_button.text = continuation()
	hud.continue_button.visible = not moving and not pending and assistant.intent.is_empty() and not game.manager.deployment
	hud.continue_button.disabled = not assistant.owned(game.manager.active_team) or hud.combat_panel.batch_running
	hud.undo_button.visible = not game.history.undo_stack.is_empty() and not moving
	# NEXT is solely navigation. It never duplicates confirm/damage/continue.
	var ready: Array = assistant.ready_units
	for button: Button in [hud.next_action_button, hud.continue_button]: button.remove_theme_stylebox_override("normal")
	if ready.is_empty(): hud.continue_button.add_theme_stylebox_override("normal", primary_style)
	else: hud.next_action_button.add_theme_stylebox_override("normal", primary_style)
	hud.next_action_button.text = "Select next squad" if game.manager.phase in [0, 1] else "Next attacker" if game.manager.phase in [2, 4] else "Next squad"
	hud.next_action_button.visible = not moving and not pending and assistant.intent.is_empty() and not ready.is_empty() and not game.manager.deployment
	if unit != null and ready.has(unit): hud.next_action_button.hide()
	hud.next_action_button.disabled = not assistant.owned(game.manager.active_team)
	hud.sidebar.visible = (unit != null and not moving and assistant.intent.is_empty() and not pending) or hud.advanced_box.visible
	hud.sidebar.set_anchor(SIDE_BOTTOM, 1.0 if hud.advanced_box.visible else 0.0)
	hud.sidebar.offset_top = 142
	hud.sidebar.offset_bottom = -110 if hud.advanced_box.visible else 465
	hud.sidebar.offset_right = 294
	hud.selected_info.visible = hud.advanced_box.visible
	unit_card.visible = not hud.advanced_box.visible and unit != null
	if unit != null and not hud.advanced_box.visible:
		unit_card.show_unit(unit,assistant.state(unit))
		if last_card_unit != str(unit.name): GrimTheme.enter(hud.sidebar,game.settings.reduce_motion)
		last_card_unit = str(unit.name)
	assistant.quick_card.set_anchor(SIDE_BOTTOM, 0)
	assistant.quick_card.offset_top = 142
	assistant.quick_card.offset_bottom = minf(game.get_viewport().get_visible_rect().size.y - 110, 462 if moving else 592 if not assistant.intent.is_empty() or pending else 480)
	# A compact card grows with content rather than claiming a full-height sidebar.
	hud.movement_info.visible = hud.advanced_box.visible
	if not moving and not game.history.undo_stack.is_empty(): game.assistance.understood("destination")
	measure_button.visible = unit != null and not moving and not pending and assistant.intent.is_empty()
	done_button.visible = measure_button.visible
	assistant.roster.visible = hud.advanced_box.visible
	hud.advanced_button.text = "Close advanced" if hud.advanced_box.visible else "Advanced"
	var can_act: bool = unit != null and unit.team == game.manager.active_team and assistant.owned(unit.team)
	if moving:
		guidance_label.text = "Place squad"
	elif pending:
		guidance_label.text = "Allocate damage"
	elif not assistant.intent.is_empty():
		guidance_label.text = "Choose an enemy"
	elif unit == null:
		guidance_label.text = "Choose a squad"
	elif not can_act:
		guidance_label.text = "Enemy squad · select one of yours"
	else:
		guidance_label.text = unit.display_name
	if game.manager.phase == 0 and not game.manager.deployment and game.settings.assistance in ["Guided", "Standard"]:
		assistant.move_button.hide()
		measure_button.hide()
		done_button.hide()
		guidance_label.text = "Ready for your turn"
	why_button.visible = assistant.intent == "attack" and assistant.target != null
	why_text.visible = why_text.visible and why_button.visible
	why_text.text = assistant.preview.tooltip_text
	update_hint(unit, moving)
	update_units(ready)
	show_scoring()
	if game.get("ai") != null and game.ai.active() and not pending:
		instruction.text = "The computer is taking its turn."
		guidance_label.text = "Enemy is planning..." if game.ai.busy else game.ai.status
		measure_button.hide()
		done_button.hide()
		hud.undo_button.hide()
	var ground := game.battlefield.visuals.get_node_or_null("GroundSurface") as MeshInstance3D
	if ground != null: (ground.material_override as ShaderMaterial).set_shader_parameter("grid_visibility", 1.0 if moving or game.interaction.mode == 2 or game.editing or (game.life!=null and game.life.tactical) else 0.0)

func update_hint(unit: TableUnit, moving: bool) -> void:
	hint_card.hide()
	if round_card.visible: return
	if game.combat.current != null and game.combat.current.remaining > 0: return
	if game.settings.assistance != "Guided" or not game.assistance.owned(game.manager.active_team): return
	var key := ""
	var title := ""
	var body := ""
	if moving and not game.settings.gameplay_hints.get("destination", false):
		key = "destination"; title = "Choose where to go"; body = 'Click inside the movement guide. We arrange the squad and check walls, spacing and distance. Then confirm.'
	elif unit != null and not game.settings.gameplay_hints.get("move_help", false) and game.manager.phase in [0, 1]:
		key = "move_help"; title = "Move your squad"; body = 'This squad can move up to %.0f". Choose Move below, then click a destination.' % unit.models[0].movement
	elif not game.settings.gameplay_hints.get("welcome", false):
		key = "welcome"; title = "Your turn"; body = "These blue-rimmed squads are yours. Select one to begin. Local play controls both teams in turn."
	elif game.manager.phase == 2 and not game.settings.gameplay_hints.get("shoot_help", false):
		key = "shoot_help"; title = "Choose an enemy"; body = "Select your squad, then Attack. Target symbols show enemies you can reach and see. Confirm once; we handle the dice."
	elif not game.settings.gameplay_hints.get("objectives", false):
		key = "objectives"; title = "Objectives win points"; body = "Keep more of your models near the numbered beacons than the enemy. Controlled objectives score automatically at the end of the round."
	elif not game.settings.gameplay_hints.get("camera", false):
		key = "camera"; title = "Look around"; body = "WASD — move\nMouse wheel — zoom\nRight drag — rotate\nHome shows the whole board."
	if key.is_empty(): return
	if key != hint_key: GrimTheme.enter(hint_card,game.settings.reduce_motion)
	hint_key = key
	hint_title.text = title
	hint_text.text = body
	hint_card.offset_left = 24
	hint_card.offset_right = 284
	hint_card.offset_top = 150 if not game.hud.sidebar.visible else 484
	hint_card.offset_bottom = hint_card.offset_top
	hint_card.show()

func dismiss_hint() -> void:
	game.assistance.understood(hint_key)
	schedule_refresh()

func show_phase_help() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = PHASE_NAMES[game.manager.phase] + " — how it works"
	dialog.dialog_text = INSTRUCTIONS[game.manager.phase] + "\n\n" + ["Choose a squad, choose Move, click a destination, then confirm. The guide shows your movement budget; the preview checks the whole squad.", "Choose a squad, choose Move, click a destination, then confirm. Walls, base overlap and squad spacing are checked automatically.", "Choose Attack, then an enemy. We check distance and visibility for each model, group weapons and calculate all dice. Why? explains who can participate.", "Choose Charge, then an enemy. We measure the gap and roll your configured charge dice. On success, review and confirm the nearby formation.", "Choose Attack on a squad close to an enemy. Close-combat weapons use the same automatic dice and damage workflow.", "Keep models near objectives. The team with more eligible models controls each beacon. Scenario points are added once at the end of the full round."][game.manager.phase]
	game.hud.root.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func update_units(ready: Array) -> void:
	for unit: TableUnit in game.battlefield.units.get_children():
		label_layout.update_squad(unit,ready.has(unit),game.selection.selected_unit()==unit,player_team())
		for model in unit.models:
			model.phase_ready = ready.has(unit) and unit.team == game.manager.active_team
			model.damage_recipient = game.combat.current != null and game.combat.current.remaining > 0 and game.combat.current.target == unit and model.wounds > 0 and game.assistance.owned(unit.team)
			model.refresh()
	for objective: TableObjective in game.battlefield.objectives.get_children():
		objective.context_radius = game.manager.phase == 5 or (game.interaction.session != null and FormationPlanner.center(game.interaction.session.unit.living_models()).distance_to(objective.global_position) < objective.radius + 7)
		objective.radius_ring.visible = objective.context_radius or game.interaction.objective_selected == objective or game.interaction.hovered_objective == objective
	refresh_label_distance()

func refresh_label_distance() -> void:
	if not is_instance_valid(game) or not game.is_inside_tree(): return
	label_layout.layout_labels()
	var width := minf(game.hud.action_row.get_combined_minimum_size().x + 36,game.get_viewport().get_visible_rect().size.x - 48)
	game.hud.dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	game.hud.dock.offset_left = -width/2
	game.hud.dock.offset_right = width/2
	game.hud.dock.offset_top = -76
	game.hud.dock.offset_bottom = -18

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8: game.hud.visible = not game.hud.visible
		if event.keycode == KEY_F9: capture_clean()

func capture_clean() -> void:
	var was_visible: bool = game.hud.visible
	game.hud.hide()
	var quality: String = game.settings.quality
	game.settings.quality = "High"
	BattlefieldPresentation.apply_quality(game,game.settings)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	game.get_viewport().get_texture().get_image().save_png("user://screenshots/grimtable_"+str(Time.get_unix_time_from_system())+".png")
	game.settings.quality = quality
	BattlefieldPresentation.apply_quality(game,game.settings)
	game.hud.visible = was_visible

func allocate_clicked(model: Miniature) -> bool:
	var current: AttackResolution = game.combat.current
	if current == null or current.remaining <= 0: return false
	if not game.assistance.owned(current.target.team):
		game.hud.set_status("Waiting for the defending player to choose who takes damage.")
		return true
	if not current.target.models.has(model) or model.removed or model.wounds <= 0:
		game.hud.set_status("Choose a highlighted model in the defending squad.")
		return true
	game.combat.allocate(model, mini(model.wounds, current.remaining))
	return true

func show_scoring() -> void:
	if game.manager.scores != last_score:
		var us := player_team()
		var delta := int(game.manager.scores[str(us)]) - int(last_score[str(us)])
		var theirs := int(game.manager.scores[str(1-us)]) - int(last_score[str(1-us)])
		toast.text = "%s%d %s for you · %s%d for the enemy\nControlled objectives score automatically" % ["+" if delta >= 0 else "", delta, "point" if abs(delta) == 1 else "points", "+" if theirs >= 0 else "", theirs]
		toast.show()
		GrimTheme.enter(toast,game.settings.reduce_motion)
		for objective: TableObjective in game.battlefield.objectives.get_children():
			if game.battlefield.control_for(objective).owner >= 0: objective.celebrate(game.settings.reduce_motion)
		get_tree().create_timer(5).timeout.connect(func(): if is_instance_valid(toast): toast.hide())
		last_score = game.manager.scores.duplicate()
	if game.manager.round_number > last_round:
		var controlled := 0
		for objective: TableObjective in game.battlefield.objectives.get_children():
			if game.battlefield.control_for(objective).owner == player_team(): controlled += 1
		round_text.text = "Round %d complete\n\nYou   %d  —  %d   Enemy\n\nYou control %d %s.\n\n%s" % [last_round, game.manager.scores[str(player_team())], game.manager.scores[str(1-player_team())], controlled, "objective" if controlled == 1 else "objectives", "Try Standard next time for the same automation without hints." if game.settings.assistance == "Guided" else "Your next round is ready."]
		if game.settings.combat_summary:
			round_card.show()
			hint_card.hide()
	last_round = game.manager.round_number
