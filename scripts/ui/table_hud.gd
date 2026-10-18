class_name TableHUD
extends CanvasLayer

signal removal_requested
signal save_requested
signal load_requested
signal menu_requested

var selection: SelectionManager
var interaction: InteractionController
var manager: GameManager
var dice: DiceManager
var selected_info: Label
var target_info: Label
var status: Label
var turn_label: Label
var mode_label: Label
var count_spin: SpinBox
var dice_result: Label
var dice_history: Label
var private_roll: CheckBox
var local_dice := DiceManager.new()
var tools: Array[Button] = []
var model_buttons: Array[Button] = []
var dice_panel: PanelContainer
var confirm_remove: ConfirmationDialog
var help_panel: PanelContainer
var root: Control
var history: ActionHistory
var movement_info: Label
var confirm_move: Button
var cancel_move: Button
var start_button: Button
var combat: CombatController
var combat_panel: CombatPanel
var editing_controls: Array[Control] = []
var objective_info: Label
var objective_clock := 0.0
var _objective_stamp: Array = []
var next_action_button: Button
var primary_box: VBoxContainer
var advanced_box: VBoxContainer
var advanced_controls: Array[Control] = []
var assistant_label: Label
var phase_warning: ConfirmationDialog
var next_unit_button: Button
var round_summary: AcceptDialog
var _last_round := 1
var sidebar: PanelContainer
var action_row: HBoxContainer
var action_title: Label
var continue_button: Button
var advanced_button: Button
var undo_button: Button
var top_panel: PanelContainer
var dock: PanelContainer
var override_box: CheckBox

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = _theme()
	_build_top()
	_build_sidebar()
	_build_toolbar()
	for control in advanced_controls: control.visible = get_parent().settings.assistance == "Tabletop"
	_build_dice()
	dice_panel.hide()
	_build_help()
	combat_panel = CombatPanel.new()
	combat_panel.combat = combat
	combat_panel.selection = selection
	combat_panel.interaction = interaction
	root.add_child(combat_panel)
	combat_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	combat_panel.offset_left = -400
	combat_panel.offset_top = 94
	combat_panel.offset_right = -16
	combat_panel.offset_bottom = -135
	combat_panel.hide()
	confirm_remove = ConfirmationDialog.new()
	confirm_remove.title = "Remove miniatures"
	confirm_remove.dialog_text = "Remove the selected miniatures from this tabletop?"
	confirm_remove.confirmed.connect(func(): removal_requested.emit())
	root.add_child(confirm_remove)
	selection.changed.connect(refresh_selection)
	manager.changed.connect(refresh_turn)
	interaction.status_changed.connect(set_status)
	interaction.target_changed.connect(func(message: String):
		target_info.text = message if not message.is_empty() else "RANGE / LINE OF SIGHT\n\nTarget [4]: select an attacker,\nthen click an opposing model.\n\nHover another model for\nedge-to-edge base distance.")
	interaction.mode_changed.connect(_mode_changed)
	interaction.movement_changed.connect(refresh_movement)
	dice.rolled.connect(_show_roll)
	phase_warning = ConfirmationDialog.new()
	phase_warning.title = "Leave these squads for now?"
	phase_warning.ok_button_text = "Continue anyway"
	phase_warning.cancel_button_text = "Go back"
	phase_warning.confirmed.connect(manager.next_phase)
	root.add_child(phase_warning)
	round_summary = AcceptDialog.new()
	round_summary.title = "Round complete"
	root.add_child(round_summary)
	manager.changed.connect(refresh_assistant)
	combat.log.changed.connect(refresh_assistant)
	refresh_selection()
	refresh_turn()
	refresh_assistant()
	interaction.set_mode(0)
	refresh_movement()

func _theme() -> Theme:
	return GrimTheme.theme(get_parent().settings.ui_scale)

func _panel(left: float, top: float, right: float, bottom: float, preset: int) -> PanelContainer:
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = left
	panel.offset_top = top
	panel.offset_right = right
	panel.offset_bottom = bottom
	return panel

func _label(parent: Node, caption: String, size: int = 15, color: Color = Color("dce5e9")) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", roundi(size * get_parent().settings.ui_scale))
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, callback: Callable, hint: String = "") -> Button:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = hint
	button.pressed.connect(callback)
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	return button

func _build_top() -> void:
	var panel := _panel(24, 16, -24, 124, Control.PRESET_TOP_WIDE)
	top_panel = panel
	var row := HBoxContainer.new()
	panel.add_child(row)
	_label(row, "GRIMTABLE", 22, Color("8bddc9"))
	var match_title := _label(row,"  /  " + str(interaction.board.scenario.name),11,GrimTheme.MUTED)
	match_title.clip_text = true
	match_title.custom_minimum_size.x = 160
	match_title.tooltip_text = str(interaction.board.scenario.name)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	turn_label = _label(row, "", 16)
	top_panel.add_theme_stylebox_override("panel", GrimTheme.surface(GrimTheme.LINE,true))
	advanced_controls.append(_button(row, "‹ Phase", manager.previous_phase))
	advanced_controls.append(_button(row, "Phase ›", advance_with_warning, "Space · Advance phase / player"))
	advanced_controls.append(_button(row, "Round +", manager.next_round))
	_button(row, "?", func(): help_panel.visible = not help_panel.visible)
	start_button = _button(row, "READY", func(): get_parent().assistance.ready())
	_button(row, "Menu", func(): menu_requested.emit())

func _build_sidebar() -> void:
	var panel := _panel(16, 164, 294, 460, Control.PRESET_TOP_LEFT)
	sidebar = panel
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	
	assistant_label = _label(column, "", 14)
	assistant_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_unit_button = _button(column, "Select Next Unit", select_next_unit)
	next_unit_button.visible = get_parent().settings.assistance == "Tabletop"
	
	selected_info = _label(column, "", 14)
	selected_info.custom_minimum_size = Vector2(225, 0)
	selected_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var normal_column := column
	primary_box = VBoxContainer.new()
	column.add_child(primary_box)
	
	advanced_box = VBoxContainer.new()
	column.add_child(advanced_box)
	advanced_box.visible = get_parent().settings.assistance == "Tabletop"
	column = advanced_box
	_button(column, "Manual Override", func(): get_parent().assistance.show_overrides())
	_button(column, "Measure", func(): interaction.set_mode(2))
	var wound_row := HBoxContainer.new()
	column.add_child(wound_row)
	editing_controls.append(wound_row)
	model_buttons.append(_button(wound_row, "− Wound", func(): _wounds(-1)))
	model_buttons.append(_button(wound_row, "+ Wound", func(): _wounds(1)))
	var row := HBoxContainer.new()
	column.add_child(row)
	editing_controls.append(row)
	model_buttons.append(_button(row, "Focus", func():
		if selection.primary() != null: interaction.rig.focus(selection.primary().global_position)))
	model_buttons.append(_button(row, "Remove", request_removal))
	var unit_row := HBoxContainer.new()
	column.add_child(unit_row)
	editing_controls.append(unit_row)
	_button(unit_row, "Move Unit", func():
		if selection.primary() != null:
			selection.select_unit(selection.primary().get_parent() as TableUnit)
			interaction.set_mode(1))
	_button(unit_row, "Target", func(): interaction.set_mode(3))
	var formations := HBoxContainer.new()
	column.add_child(formations)
	for layout in ["Line", "Two Rows", "Cluster"]:
		_button(formations, layout, func(): interaction.auto_arrange(layout), "Propose a formation; confirm or cancel")
	_button(column, "Auto Place Unit (deployment)", func(): interaction.auto_place_unit())
	editing_controls.append(_button(column, "Clear Selection", func(): interaction.cancel(); selection.clear()))
	var history_row := HBoxContainer.new()
	column.add_child(history_row)
	editing_controls.append(history_row)
	_button(history_row, "Undo", func(): get_parent().undo_action(), "Ctrl+Z")
	_button(history_row, "Redo", func(): get_parent().redo_action(), "Ctrl+Y")
	editing_controls.append(_button(column, "Attack / Battle Log", func(): combat_panel.show(); dice_panel.hide()))
	movement_info = _label(column, "", 13)
	movement_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var confirm_row := HBoxContainer.new()
	column.add_child(confirm_row)
	confirm_move = _button(confirm_row, "Confirm Move", interaction.confirm_unit_move)
	cancel_move = _button(confirm_row, "Cancel Move", interaction.cancel)
	override_box = CheckBox.new()
	override_box.text = "Manual coherency override"
	override_box.toggled.connect(func(enabled: bool): interaction.manual_override = enabled; refresh_movement())
	column.add_child(override_box)
	column.add_child(HSeparator.new())
	target_info = _label(column, "Target tool [4]\nSelect an attacker, then\nclick an opposing miniature.", 14)
	target_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_info.custom_minimum_size = Vector2(225, 190)
	objective_info = _label(column, "", 13)
	objective_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	movement_info.reparent(normal_column)
	confirm_row.reparent(normal_column)
	normal_column.move_child(movement_info, primary_box.get_index() + 1)
	normal_column.move_child(confirm_row, primary_box.get_index() + 2)

func _build_toolbar() -> void:
	var panel := _panel(16, -118, -16, -14, Control.PRESET_BOTTOM_WIDE)
	dock = panel
	var column := VBoxContainer.new()
	panel.add_child(column)
	var row := HBoxContainer.new()
	column.add_child(row)
	for i in range(4):
		var button := _button(row, ["1  Select", "2  Move", "3  Measure", "4  Target"][i], func(): interaction.set_mode(i))
		button.toggle_mode = true
		tools.append(button)
	mode_label = _label(row, "SELECT", 13, Color("8bddc9"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var setup := _button(row, "Setup", func(): pass, "Drag terrain and objectives in setup mode")
	setup.toggle_mode = true
	setup.toggled.connect(func(enabled: bool):
		interaction.cancel()
		interaction.setup_mode = enabled
		set_status("SETUP · Drag terrain / objectives. Toggle Setup off to play." if enabled else "PLAY · Setup locked"))
	_button(row, "Footprints", func():
		for piece: TerrainPiece in interaction.board.terrain.get_children(): piece.footprint_overlay.visible = not piece.footprint_overlay.visible)
	_button(row, "Dice", func(): dice_panel.visible = not dice_panel.visible; combat_panel.hide())
	_button(row, "Save", func(): save_requested.emit())
	_button(row, "Load", func(): load_requested.emit())
	for control: Control in row.get_children():
		advanced_controls.append(control)
		control.visible = get_parent().settings.assistance == "Tabletop"
	undo_button = _button(row, "Undo", func(): get_parent().undo_action())
	next_action_button = _button(row, "NEXT", func(): get_parent().assistance.next_action())
	continue_button = _button(row, "Continue", advance_with_warning)
	var deploy_army := _button(row, "Auto Deploy Army", func(): AssistanceService.request(get_parent(), "auto_deploy"))
	deploy_army.visible = manager.deployment
	manager.changed.connect(func(): deploy_army.visible = manager.deployment)
	advanced_button = _button(row, "Advanced", toggle_more)
	action_row = HBoxContainer.new()
	column.add_child(action_row)
	column.move_child(action_row, 0)
	action_title = _label(action_row, "Choose a squad", 17)
	_button(row, "Overview", func(): interaction.rig.destination = Vector3.ZERO; interaction.rig.distance = 65)
	_button(row, "History", func(): combat_panel.show(); combat_panel.refresh())
	status = _label(column, "", 14, Color("b6c8d0"))
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _build_dice() -> void:
	dice_panel = _panel(-300, 94, -16, 565, Control.PRESET_TOP_RIGHT)
	var column := VBoxContainer.new()
	dice_panel.add_child(column)
	_label(column, "DICE TRAY / D6", 13, Color("8bddc9"))
	var row := HBoxContainer.new()
	column.add_child(row)
	_button(row, "−", func(): count_spin.value -= 1)
	count_spin = SpinBox.new()
	count_spin.min_value = 1
	count_spin.max_value = 100
	count_spin.value = 10
	count_spin.custom_minimum_size.x = 75
	row.add_child(count_spin)
	_button(row, "+", func(): count_spin.value += 1)
	_button(row, "ROLL", func(): roll_manual(int(count_spin.value)))
	private_roll = CheckBox.new()
	private_roll.text = "Private / local only"
	column.add_child(private_roll)
	var shortcuts := HBoxContainer.new()
	column.add_child(shortcuts)
	_button(shortcuts, "1D6", func(): roll_manual(1))
	_button(shortcuts, "2D6", func(): roll_manual(2))
	dice_result = _label(column, "Roll to begin.", 17)
	dice_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dice_result.custom_minimum_size = Vector2(250, 90)
	_label(column, "PREVIOUS ROLLS", 12, Color("91a9b5"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 150)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	dice_history = _label(scroll, "—", 13)
	dice_history.custom_minimum_size.x = 230
	dice_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func roll_manual(count: int) -> void:
	if not private_roll.button_pressed: dice.roll(count); return
	var result := local_dice.roll(count)
	_show_roll(result)
	get_parent().dice_tray.enqueue("PRIVATE LOCAL ROLL",result.values)

func _build_help() -> void:
	help_panel = _panel(-260, -270, 260, 270, Control.PRESET_CENTER)
	help_panel.visible = false
	var column := VBoxContainer.new()
	help_panel.add_child(column)
	_label(column, "WELCOME TO GRIMTABLE", 23, Color("8bddc9"))
	_label(column, '60 × 44 inches · 1 world unit = 1 inch\n\nWASD / middle drag   Pan     Wheel   Zoom\nQ / E   Rotate     Right drag   Orbit / tilt\nF   Focus selection     Home   Reset camera\n\nClick   Select squad     Alt-click   Select model\nShift-click   Add/remove squad or model\n1 Select   2 Move   3 / M Measure   4 Target\nSquad move: reposition members, then Confirm Move\nCancel Move / Esc restores the whole squad\nMeasure: click start, click end to lock\n\nDeploy inside team zones, then click Start Game\nTarget enemy, then open Attack / Battle Log\nResolve attack; choose recipient; Apply Damage\nRemove Casualty explicitly removes a defeated model\nCtrl+Z   Undo     Ctrl+Y   Redo\nSpace   Advance phase     Delete   Confirm removal\nHold T   Tactical view     F7   AI diagnostics\nF3   Collision overlays     F4   LOS rays\nSetup   Reposition terrain and objectives', 15)
	_button(column, "Back to table", func(): help_panel.hide())

func _mode_changed(value: String) -> void:
	mode_label.text = value
	for i in tools.size(): tools[i].set_pressed_no_signal(i == interaction.mode)

func set_status(message: String) -> void:
	status.tooltip_text = message # Preserve diagnostic detail for inspection.
	status.text = friendly_message(message)

func friendly_message(message: String) -> String:
	var text := message.replace("UNIT OUT OF COHERENCY", 'Squad is too spread out. Move highlighted models within 2" of a squadmate.').replace("Exceeds movement allowance", "That destination is too far. Choose a closer point.").replace("Base crosses board boundary", "Keep every model on the battlefield.").replace("Canonical action rejected:", "That action isn't available:")
	for model: Miniature in selection.models: text = text.replace(model.model_id + ": ", "One model: ")
	if "Base overlaps " in text: text = "A model would overlap another miniature. Choose a little more space."
	return text

func refresh_selection() -> void:
	var model := selection.primary()
	for button in model_buttons: button.disabled = model == null
	if model == null:
		selected_info.text = "Choose a squad\nYour ready squads have illuminated bases."
		return
	var unit := selection.selected_unit()
	if unit != null:
		var total := 0
		var maximum := 0
		var count := 0
		for member in unit.models:
			if member.removed: continue
			count += 1
			total += member.wounds
			maximum += member.max_wounds
		selected_info.text = '%s\n%s\n\n%d models · Health %d / %d\nMove %.0f"     Armor %d+\nHealth %d per model' % [unit.display_name, unit.definition.get("name", model.display_name), unit.living_models().size(), total, maximum, model.movement, int(unit.definition.get("save", 3)), model.max_wounds]
		selected_info.tooltip_text = "Health = wounds. Armor = save characteristic. Accuracy = hit threshold. Advanced shows full weapon and defense values."
		for weapon in unit.weapon_profiles:
			selected_info.text += '\n%s · %s" · %d attacks' % [weapon.name, str(weapon.range).trim_suffix(".0"), int(weapon.attacks)]
		var action_state: Dictionary = PhaseAssistant.states(combat.log, manager.round_number, int(interaction.board.scenario.starting_state.round), bool(interaction.board.scenario.starting_state.deployment)).get(str(unit.name), {})
		selected_info.text += "\n%s  |  %s" % ["✓ Moved" if int(action_state.get("moved", 0)) > 0 else "○ Not moved", "✓ Attacked" if int(action_state.get("ranged", 0)) + int(action_state.get("melee", 0)) > 0 else "○ Not attacked"]
		if not advanced_box.visible: return
		selected_info.text += "\n\nWEAPONS"
		for weapon in unit.weapon_profiles:
			selected_info.text += '\n%s\n%s" | A%s | Hit %s+ | S%s | AP%s | D%s' % [weapon.name, str(weapon.range).trim_suffix(".0"), str(int(weapon.attacks)), str(int(weapon.hit)), str(int(weapon.strength)), str(int(weapon.get("ap", 0))), str(int(weapon.damage))]
		return
	selected_info.text = '%s  /  %s\n%s\n\nTeam %s · %d selected\nMovement    %.0f"\nWounds        %d / %d%s\nBase              %.0f mm' % [model.code(), model.display_name, model.unit_name, "A" if model.team == 0 else "B", selection.models.size(), model.movement, model.wounds, model.max_wounds, "  DOWN" if model.wounds == 0 else "", model.base_radius * 2 * 25.4]

func refresh_turn() -> void:
	start_button.visible = manager.deployment
	turn_label.text = "ROUND %d   /   %s   /   TEAM %s  " % [manager.round_number, manager.PHASES[manager.phase].to_upper(), "A" if manager.active_team == 0 else "B"]
	if int(manager.scores["0"]) > 0 or int(manager.scores["1"]) > 0: turn_label.text += " SCORE %s : %s" % [str(manager.scores["0"]), str(manager.scores["1"])]
	if manager.deployment: turn_label.text = "DEPLOYMENT"
	if get_parent().network_session != null:
		turn_label.text += "   /   YOU: TEAM " + ("A (HOST)" if get_parent().network_session.host else "B (GUEST)")

func _wounds(delta: int) -> void:
	interaction.cancel()
	var changes: Array[Dictionary] = []
	for model in selection.models:
		changes.append({"object": model, "id": model.model_id, "property": "wounds", "before": model.wounds, "after": clampi(model.wounds + delta, 0, model.max_wounds)})
	if history != null: history.perform(GameAction.new("Adjust wounds", "wounds", changes))
	refresh_selection()

func refresh_movement() -> void:
	var session := interaction.session
	for control in editing_controls: control.visible = session == null
	target_info.visible = session == null
	override_box.visible = session != null
	confirm_move.visible = session != null
	cancel_move.visible = session != null
	if session == null:
		movement_info.text = ""
		return
	var error := session.validation_error(interaction.manual_override)
	confirm_move.disabled = not error.is_empty() or interaction.dragging != null
	var rows := PackedStringArray(["UNIT MOVE · " + ("COHERENT" if CoherencyService.is_unit_coherent(session.unit) else "UNIT OUT OF COHERENCY")])
	if interaction.manual_override: rows.append("MANUAL COHERENCY OVERRIDE")
	for model: Miniature in session.origins:
		var spent := float(session.spent[model])
		if interaction.dragging == model: spent += MeasurementService.horizontal_distance(interaction.drag_origin, model.global_position)
		rows.append(model.code() + ": free deployment" if manager.deployment else '%s: %.1f" used / %.1f" left' % [model.code(), spent, maxf(0, session.limit(model) - spent)])
	if not error.is_empty(): rows.append(error)
	movement_info.text = "\n".join(rows)
	if interaction.move_preview != null and interaction.move_preview.compact: movement_info.text = rows[0] + ("\n" + error if not error.is_empty() else "")

func request_removal() -> void:
	if selection.models.is_empty(): return
	interaction.cancel()
	confirm_remove.dialog_text = "Remove %d selected miniature(s)?\nThey remain in the save data as removed." % selection.models.size()
	confirm_remove.popup_centered()

func _show_roll(result: Dictionary) -> void:
	var values := PackedStringArray()
	for value in result.values: values.append(str(value))
	dice_result.text = "%dD6  ·  TOTAL %d\n%s" % [result.count, result.total, "  ".join(values)]
	var previous := PackedStringArray()
	for i in range(1, dice.history.size()):
		var roll := dice.history[i]
		previous.append("%dD6 → %s\nTotal %d" % [roll.count, str(roll.values), roll.total])
	dice_history.text = "\n\n".join(previous) if not previous.is_empty() else "—"

func _unhandled_key_input(event: InputEvent) -> void:
	if get_parent().replay_mode or get_parent().editing or get_parent().menu_open: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE: request_removal()
		if event.keycode == KEY_SPACE: advance_with_warning()

func _process(delta: float) -> void:
	objective_clock += delta
	if objective_clock < 0.3 or objective_info == null: return
	objective_clock = 0
	var board := interaction.board
	var stamp := [board.spatial_revision, manager.scores.duplicate()]
	if stamp == _objective_stamp: return
	_objective_stamp = stamp
	var names := [ObjectiveControl.team_name(board.units.get_children(), 0), ObjectiveControl.team_name(board.units.get_children(), 1)]
	var rows: Array[String] = ["OBJECTIVE CONTROL"]
	for objective: TableObjective in board.objectives.get_children():
		var control := board.control_for(objective)
		objective.present(control, 0 if get_parent().network_session == null or get_parent().network_session.host else 1)
		rows.append("%s: %s %d / %s %d\n%s" % [objective.display_name, names[0], control.counts["0"], names[1], control.counts["1"], "Contested / neutral" if control.owner < 0 else "Controlled by " + names[control.owner]])
	rows.append("SCORE\n%s %d | %s %d" % [names[0], manager.scores["0"], names[1], manager.scores["1"]])
	objective_info.text = "\n\n".join(rows)

func refresh_assistant() -> void:
	if assistant_label == null: return
	var todo: Array = PhaseAssistant.pending(interaction.board, manager, combat.log) if manager.phase in [1, 2, 3, 4] else interaction.board.units.get_children().filter(func(unit): return unit.team == manager.active_team and not unit.living_models().is_empty())
	assistant_label.text = "%s\n%d units %s" % ["DEPLOYMENT" if manager.deployment else manager.PHASES[manager.phase].to_upper(), todo.size(), "have not moved" if manager.phase == 1 else "can charge" if manager.phase == 3 else "can still attack" if manager.phase in [2, 4] else "ready"]
	next_unit_button.text = "Next Unmoved Unit" if manager.phase == 1 else "Next Unit That Can Attack" if manager.phase in [2, 4] else "Select Next Unit"
	if manager.round_number > _last_round and get_parent().settings.combat_summary and get_parent().settings.assistance == "Tabletop":
		round_summary.dialog_text = "ROUND %d COMPLETE\n\n%s: %s points\n%s: %s points\n\nRound %d is ready." % [_last_round, ObjectiveControl.team_name(interaction.board.units.get_children(), 0), manager.scores["0"], ObjectiveControl.team_name(interaction.board.units.get_children(), 1), manager.scores["1"], manager.round_number]
		round_summary.popup_centered()
	_last_round = manager.round_number

func select_next_unit() -> void:
	var candidates: Array = PhaseAssistant.pending(interaction.board, manager, combat.log) if manager.phase in [1, 2, 3, 4] else interaction.board.units.get_children().filter(func(unit): return unit.team == manager.active_team and not unit.living_models().is_empty())
	if candidates.is_empty(): set_status("No eligible units. You may pass or use manual tools."); return
	var index := candidates.find(selection.selected_unit())
	var unit: TableUnit = candidates[(index + 1) % candidates.size()]
	interaction.cancel()
	selection.select_unit(unit)
	interaction.rig.focus(unit.models[0].global_position)

func advance_with_warning() -> void:
	if get_parent().get("ai") != null and (get_parent().ai.active() or get_parent().ai.finished): return
	if combat_panel.batch_running or (combat.current != null and combat.current.remaining > 0):
		set_status("Finish the attack and allocate pending damage before advancing.")
		return
	if get_parent().settings.phase_warnings and not manager.deployment and manager.phase in [1, 2, 3, 4]:
		var todo: Array = PhaseAssistant.pending(interaction.board, manager, combat.log)
		if not todo.is_empty():
			phase_warning.dialog_text = "%d squads could still %s. You can leave them where they are and continue." % [todo.size(), "move" if manager.phase == 1 else "charge" if manager.phase == 3 else "attack"]
			phase_warning.popup_centered()
			return
	manager.next_phase()

func toggle_more() -> void:
	advanced_box.visible = not advanced_box.visible
	for control in advanced_controls: control.visible = advanced_box.visible
	refresh_selection()
	if get_parent().guidance != null: get_parent().guidance.schedule_refresh()

func apply_assistance_layout() -> void:
	var tabletop: bool = get_parent().settings.assistance == "Tabletop"
	advanced_box.visible = tabletop
	for control in advanced_controls: control.visible = tabletop
	next_unit_button.visible = tabletop
	refresh_selection()
