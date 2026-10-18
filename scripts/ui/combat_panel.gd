class_name CombatPanel
extends PanelContainer

signal batch_completed

var combat: CombatController
var selection: SelectionManager
var interaction: InteractionController
var weapon_choice: OptionButton
var eligibility: Label
var confirmation: ConfirmationDialog
var loadout_unit: TableUnit
var preview_clock := 0.0
var _preview_stamp: Array = []
var summary: Label
var pending_label: Label
var resolve_button: Button
var model_choice: OptionButton
var amount: SpinBox
var apply_button: Button
var remove_button: Button
var log_window: Window
var log_text: RichTextLabel
var candidates: Array[Miniature] = []
var target_choice: OptionButton
var target_units: Array[TableUnit] = []
var queued_groups: Array[Dictionary] = []
var queue_label: Label
var batch_running := false
var batch_waiting := false
var batch_previous_id := -1
var batch_wait_started := 0
var batch_owner: TableUnit
var target_stamp: Array = []

func _ready() -> void:
	var body := ScrollContainer.new()
	body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(body)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(column)
	var title := Label.new()
	title.text = "ATTACK CONTROL  /  EXACT DICE"
	column.add_child(title)
	weapon_choice = OptionButton.new()
	weapon_choice.fit_to_longest_item = false
	column.add_child(weapon_choice)
	weapon_choice.item_selected.connect(func(_index: int): update_preview())
	target_choice = OptionButton.new()
	target_choice.fit_to_longest_item = false
	column.add_child(target_choice)
	target_choice.item_selected.connect(func(index: int):
		if index < 0 or index >= target_units.size(): return
		interaction.target_model = target_units[index].living_models()[0]
		if selection.primary() != null: interaction.update_target(selection.primary(), interaction.target_model)
		update_preview())
	button(column, "Choose Enemy on Table [4]", func(): interaction.set_mode(3))
	var groups := HBoxContainer.new()
	column.add_child(groups)
	button(groups, "Assign Group", assign_group)
	button(groups, "Resolve Groups", resolve_groups)
	button(groups, "Clear", func(): queued_groups.clear(); batch_running = false; queue_label.text = "")
	queue_label = Label.new()
	queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(queue_label)
	eligibility = Label.new()
	eligibility.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(eligibility)
	resolve_button = button(column, "Confirm Attack...", _resolve)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Confirm attack"
	add_child(confirmation)
	var override := CheckBox.new()
	override.text = "Offline sandbox: ignore active player"
	override.toggled.connect(func(enabled: bool): combat.sandbox_override = enabled and not combat.submit.is_valid())
	column.add_child(override)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 180
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	summary = Label.new()
	summary.custom_minimum_size.x = 330
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(summary)
	pending_label = Label.new()
	column.add_child(pending_label)
	button(column, "Suggested Model (no damage applied)", suggest_model)
	model_choice = OptionButton.new()
	model_choice.fit_to_longest_item = false
	model_choice.item_selected.connect(func(_index: int): _buttons())
	column.add_child(model_choice)
	var row := HBoxContainer.new()
	column.add_child(row)
	amount = SpinBox.new()
	amount.min_value = 1
	amount.max_value = 10000
	amount.value = 1
	row.add_child(amount)
	apply_button = button(row, "Apply Damage", func(): combat.allocate(chosen(), int(amount.value)))
	var casualty_row := HBoxContainer.new()
	column.add_child(casualty_row)
	remove_button = button(casualty_row, "Remove Casualty", func(): combat.remove_casualty(chosen()))
	button(casualty_row, "Discard Damage", combat.discard_pending)
	var log_row := HBoxContainer.new()
	column.add_child(log_row)
	button(log_row, "Battle Log", func(): log_window.popup_centered(Vector2i(760, 560)))
	button(log_row, "Close", hide)
	log_window = Window.new()
	log_window.visible = false
	log_window.title = "Battle Log · chronological events"
	log_window.close_requested.connect(log_window.hide)
	add_child(log_window)
	log_text = RichTextLabel.new()
	log_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	log_text.offset_left = 12
	log_text.offset_top = 12
	log_text.offset_right = -12
	log_text.offset_bottom = -12
	log_window.add_child(log_text)
	combat.changed.connect(refresh)
	combat.history.changed.connect(refresh)
	combat.log.changed.connect(_refresh_log)
	selection.changed.connect(_buttons)
	interaction.target_changed.connect(func(_text: String): _buttons())
	refresh()
	_refresh_log()

func button(parent: Node, text: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = text
	control.focus_mode = Control.FOCUS_NONE
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

func _resolve() -> void:
	var source := selection.primary()
	var target := interaction.target_model
	if source == null or target == null: return
	var attacker := source.get_parent() as TableUnit
	var defender := target.get_parent() as TableUnit
	var index := maxi(0, weapon_choice.selected)
	update_preview()
	confirmation.dialog_text = eligibility.text + "\nTarget: " + defender.display_name + "\nRoll all dice and resolve?"
	for connection in confirmation.confirmed.get_connections(): confirmation.confirmed.disconnect(connection.callable)
	confirmation.confirmed.connect(func():
		if is_instance_valid(attacker) and is_instance_valid(defender): combat.resolve(attacker, defender, interaction.get_world_3d(), index), CONNECT_ONE_SHOT)
	confirmation.popup_centered()

func _process(delta: float) -> void:
	preview_clock += delta
	if preview_clock < 0.2: return
	preview_clock = 0
	if visible:
		update_preview()
		refresh_targets()
	else: clear_eligibility()
	if batch_running: continue_batch()

func clear_eligibility() -> void:
	_preview_stamp = []
	if is_instance_valid(loadout_unit):
		for model in loadout_unit.models:
			if model.attack_eligibility >= 0:
				model.attack_eligibility = -1
				model.refresh()

func update_preview() -> void:
	var source := selection.primary()
	var unit: TableUnit = source.get_parent() as TableUnit if source != null else null
	if unit != loadout_unit:
		clear_eligibility()
		loadout_unit = unit
		weapon_choice.clear()
		if unit != null:
			for weapon in unit.weapon_profiles: weapon_choice.add_item("%s ×%d" % [weapon.name, weapon.get("_equipped_models",unit.living_models()).size()])
	if unit == null or unit.weapon_profiles.is_empty():
		eligibility.text = "Select an attacking unit."
		return
	var weapon: Dictionary = unit.weapon_profiles[maxi(0, weapon_choice.selected)]
	if interaction.target_model == null:
		eligibility.text = str(weapon.name) + "\nChoose an opposing target with [4]."
		clear_eligibility()
		return
	var target := interaction.target_model.get_parent() as TableUnit
	var stamp: Array = [unit.get_instance_id(), target.get_instance_id(), weapon, interaction.board.spatial_revision,combat.log.sequence,combat.manager.phase]
	for squad in [unit, target]:
		for model in squad.models: stamp.append([model.global_position, model.wounds, model.removed, model.selected])
	if stamp == _preview_stamp: return
	_preview_stamp = stamp.duplicate(true)
	var preview := AttackResolver.preview(unit, target, interaction.get_world_3d(), weapon)
	eligibility.text = '%s (%s) | Range %s"\nIn range: %d / %d | Range + LOS: %d\n%d models x %d attacks = %d dice' % [weapon.name, weapon.get("type", "ranged"), str(weapon.range).trim_suffix(".0"), preview.in_range, preview.living, preview.eligible, preview.eligible, weapon.attacks, preview.attacks]
	for model in unit.models:
		model.attack_eligibility = 1 if preview.eligible_models.has(model.model_id) else 0
		model.refresh()

func chosen() -> Miniature:
	var index := model_choice.selected
	return candidates[index] if index >= 0 and index < candidates.size() else null

static func describe(result: Dictionary) -> String:
	result = AttackResolver.normalize_result(result)
	var weapon: Dictionary = result.weapon
	var profile: Dictionary = result.get("target_profile", {}) if result.get("target_profile", {}) is Dictionary else {}
	var stats := '%s · Range %s"\nA %s · Hit %s+ · Strength %s\nAP %s · Damage %s\nTarget defense %s · Save %s+' % [weapon.name, str(weapon.get("range", 0)).trim_suffix(".0"), str(int(weapon.get("attacks", 0))), str(int(weapon.get("hit", 3))), str(int(weapon.get("strength", 4))), str(int(weapon.get("ap", 0))), str(int(weapon.get("damage", 1))), str(int(profile.get("defense", profile.get("toughness", 4)))), str(int(profile.get("save", 3)))]
	return '%s → %s\n%s\n%d eligible models · %d ATTACKS\n\nHIT %d+\n%s\n%d hits\n\nWOUND %d+\n%s\n%d wounds\n\nSAVE %s\n%s\n%d failed saves\n\n%d DAMAGE' % [result.attacking_unit, result.target_unit, stats, result.eligible_models.size(), result.attacks, result.hit_target, str(result.hit_rolls), result.hits, result.wound_target, str(result.wound_rolls), result.wounds, "impossible" if result.save_target > 6 else str(result.save_target) + "+", str(result.save_rolls), result.failed_saves, result.damage]

func refresh() -> void:
	pending_label.text = "DAMAGE POOL · %d remaining" % (combat.current.remaining if combat.current != null else 0)
	var selected_id := chosen().model_id if chosen() != null else ""
	model_choice.clear()
	candidates.clear()
	if combat.current == null:
		summary.text = "Target an opposing unit with [4].\nRolls stay visible at every stage.\nDamage requires manual allocation."
	else:
		summary.text = describe(combat.current.result) + "\nRemaining to allocate: %d" % combat.current.remaining
		summary.tooltip_text = "Wound target: Strength vs Defense. Save target: base save + AP penalty - explicit cover bonus (minimum 2+, above 6 impossible).\nCover bonus: %s" % str(combat.current.result.get("cover_bonus", 0))
		for model in combat.current.target.models:
			if model.removed: continue
			candidates.append(model)
			model_choice.add_item("%s · %d/%d wounds%s" % [model.code(), model.wounds, model.max_wounds, " DOWN" if model.wounds == 0 else ""])
			if model.model_id == selected_id: model_choice.select(candidates.size() - 1)
	_buttons()

func _buttons() -> void:
	if not is_instance_valid(resolve_button): return
	resolve_button.disabled = combat.manager.deployment or interaction.session != null or selection.primary() == null or interaction.target_model == null or (combat.current != null and combat.current.remaining > 0)
	var model := chosen()
	amount.max_value = maxi(1, mini(model.wounds, combat.current.remaining)) if model != null and combat.current != null else 1
	apply_button.disabled = model == null or model.wounds <= 0 or combat.current == null or combat.current.remaining <= 0
	remove_button.disabled = model == null or model.wounds != 0

func _refresh_log() -> void:
	var rows := PackedStringArray()
	for entry in combat.log.entries:
		var text := "#%d  %s" % [entry.sequence, entry.kind]
		if entry.kind == "attack": text += "\n" + describe(entry.payload)
		elif entry.kind == "dice": text += "\nD6: " + str(entry.payload.values) + " · Total " + str(entry.payload.total)
		elif entry.kind in ["turn", "start_game"] and entry.payload.get("after") is Dictionary:
			var state: Dictionary = entry.payload.after
			text += "\nRound %d · %s · Team %s" % [state.round, "Deployment" if state.deployment else GameManager.PHASES[int(state.phase)], "A" if state.team == 0 else "B"]
		elif entry.payload.has("title"): text += "  " + str(entry.payload.title) + "\n" + JSON.stringify(entry.payload.get("metadata", {}))
		rows.append(text)
	log_text.text = "\n\n".join(rows)

func suggest_model() -> void:
	var valid := candidates.filter(func(model): return not model.removed and model.wounds > 0)
	valid.sort_custom(func(a, b):
		if (a.wounds < a.max_wounds) != (b.wounds < b.max_wounds): return a.wounds < a.max_wounds
		return a.model_id < b.model_id)
	if not valid.is_empty(): model_choice.select(candidates.find(valid[0])); _buttons()

func refresh_targets() -> void:
	var unit := selection.selected_unit()
	var stamp := [unit, weapon_choice.selected, interaction.board.spatial_revision]
	if stamp == target_stamp: return
	target_stamp = stamp
	target_choice.clear()
	target_units.clear()
	if unit == null or unit.weapon_profiles.is_empty(): return
	var weapon: Dictionary = unit.weapon_profiles[maxi(0, weapon_choice.selected)]
	for target: TableUnit in interaction.board.units.get_children():
		if target.team == unit.team or target.living_models().is_empty(): continue
		var preview := AttackResolver.preview(unit, target, interaction.get_world_3d(), weapon)
		target_units.append(target)
		target_choice.add_item("%s | %d/%d LOS + range | %d dice" % [target.display_name, preview.eligible, preview.living, preview.attacks])
	target_choice.select(-1)

func assign_group() -> void:
	var unit := selection.selected_unit()
	if unit == null or interaction.target_model == null or batch_running: return
	if batch_owner != unit: queued_groups.clear(); batch_owner = unit
	var index := maxi(0, weapon_choice.selected)
	for item in queued_groups:
		if item.weapon == index: queue_label.text = "Group already assigned. Clear to reassign."; return
	var target := interaction.target_model.get_parent() as TableUnit
	if target.team == unit.team: return
	queued_groups.append({"weapon": index, "target": target})
	var lines := PackedStringArray()
	for item in queued_groups: lines.append("%s → %s" % [unit.weapon_profiles[item.weapon].name, item.target.display_name])
	queue_label.text = "\n".join(lines)

func resolve_groups() -> void:
	if queued_groups.is_empty() or batch_running: return
	confirmation.dialog_text = queue_label.text + "\nResolve these groups sequentially? Damage allocation stays manual."
	for connection in confirmation.confirmed.get_connections(): confirmation.confirmed.disconnect(connection.callable)
	confirmation.confirmed.connect(func(): batch_running = true; continue_batch(), CONNECT_ONE_SHOT)
	confirmation.popup_centered()

func continue_batch() -> void:
	if batch_waiting:
		if combat.current != null and combat.current.attack_id != batch_previous_id: batch_waiting = false
		elif Time.get_ticks_msec() - batch_wait_started > 5000:
			batch_waiting = false
			batch_running = false
			queue_label.text = "Waiting for host result timed out. Check the battle log before retrying."
			return
		else: return
	if combat.current != null and combat.current.remaining > 0: return
	if queued_groups.is_empty(): batch_running = false; queue_label.text = "ATTACK GROUPS COMPLETE"; batch_completed.emit(); return
	if not is_instance_valid(batch_owner) or interaction.session != null: batch_running = false; return
	var item: Dictionary = queued_groups.pop_front()
	if not is_instance_valid(item.target) or item.target.living_models().is_empty(): return
	# One normal host-authoritative attack per group. No new batch wire protocol.
	batch_previous_id = combat.current.attack_id if combat.current != null else -1
	if combat.submit.is_valid():
		batch_waiting = true
		batch_wait_started = Time.get_ticks_msec()
	if not combat.resolve(batch_owner, item.target, interaction.get_world_3d(), item.weapon):
		batch_waiting = false
		batch_running = false
		queue_label.text = "Group paused. Check ownership, target eligibility and pending damage."
