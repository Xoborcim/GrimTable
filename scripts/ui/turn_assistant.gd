class_name TurnAssistant
extends Node

var quick_card: PanelContainer
var cancel_intent: Button
var dice_details: Button
var game: Node3D
var move_button: Button
var attack_button: Button
var charge_button: Button
var commit_button: Button
var focus_button: Button
var next_button: Button
var hint: Label
var preview: Label
var damage: Label
var apply_button: Button
var other_button: Button
var casualties_button: Button
var target_choice: OptionButton
var formation_choice: OptionButton
var split_button: Button
var roster: Label
var targets: Array[TableUnit] = []
var available: Array[Dictionary] = []
var ready_units: Array = []
var target: TableUnit
var intent := ""
var refresh_pending := false
var problem: Dictionary = {}
var marked: Array[Miniature] = []
var last_charge := ""
var last_scores := {"0": 0, "1": 0}
var dismissed_result := -1
var override_window: Window

func _ready() -> void:
	build(game.hud.primary_box)
	for signal_source in [game.selection.changed, game.manager.changed, game.history.changed, game.combat.changed, game.battle_log.changed, game.interaction.movement_changed]: signal_source.connect(schedule_refresh)
	game.interaction.target_selected.connect(func(model: Miniature):
		if intent in ["attack", "charge"]: target = model.get_parent() as TableUnit; schedule_refresh())
	game.hud.combat_panel.batch_completed.connect(schedule_refresh)
	game.manager.changed.connect(func():
		if game.combat.current != null and game.combat.current.remaining == 0: dismissed_result = game.combat.current.attack_id)
	game.selection.changed.connect(func():
		intent = ""
		target = null
		last_charge = ""
		problem = {}
		clear_marks()
		if game.selection.primary() != null:
			understood("select")
			understood("welcome")
			if game.settings.camera_assistance: game.camera_rig.focus(game.selection.primary().global_position))
	game.interaction.status_changed.connect(func(_text: String):
		if not game.interaction.last_problem.is_empty(): problem = game.interaction.last_problem; schedule_refresh())
	schedule_refresh()

func label(parent: Node, text: String = "") -> Label:
	var item := AppUI.label(parent, text, 14)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return item

func build(parent: VBoxContainer) -> void:
	var row := AppUI.row(game.hud.action_row)
	move_button = AppUI.button(row, "Move", begin_move)
	attack_button = AppUI.button(row, "Attack", begin_attack)
	charge_button = AppUI.button(row, "CHARGE", begin_charge)
	hint = label(game.hud.action_row)
	quick_card = game.hud._panel(-330, 164, -16, -140, Control.PRESET_RIGHT_WIDE)
	var quick_box := VBoxContainer.new()
	quick_card.add_child(quick_box)
	label(quick_box, "Review your action")
	formation_choice = AppUI.choices(quick_box, ["Auto", "Line", "Two Rows", "Cluster", "Manual"], 0)
	formation_choice.item_selected.connect(func(index: int):
		game.interaction.quick_layout = ["Auto", "Line", "Two Rows", "Cluster", "Manual"][index]
		game.interaction.quick_anchor = index != 4
		game.hud.set_status("Choose another destination to preview this formation." if index != 4 else "Drag individual models, then Confirm."))
	target_choice = OptionButton.new()
	target_choice.fit_to_longest_item = false
	quick_box.add_child(target_choice)
	target_choice.item_selected.connect(func(index: int):
		if index >= 0 and index < targets.size(): choose_target(targets[index]))
	var preview_scroll := ScrollContainer.new()
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_scroll.custom_minimum_size.y = 80
	quick_box.add_child(preview_scroll)
	preview = label(preview_scroll)
	commit_button = AppUI.button(quick_box, "Confirm attack", confirm_attack)
	split_button = AppUI.button(quick_box, "Advanced: split fire / weapons", func():
		game.hud.combat_panel.show()
		game.hud.combat_panel.update_preview()
		game.hud.combat_panel.refresh_targets())
	cancel_intent = AppUI.button(quick_box, "Cancel", func():
		if intent.is_empty() and game.combat.current != null: dismissed_result = game.combat.current.attack_id
		intent = ""; target = null; problem = {}; game.interaction.cancel(); schedule_refresh())
	dice_details = AppUI.button(quick_box, "Show dice / history", func(): game.hud.combat_panel.show(); game.hud.combat_panel.refresh())
	damage = label(quick_box)
	apply_button = AppUI.button(quick_box, "Apply to Suggested Model", apply_suggestion)
	other_button = AppUI.button(quick_box, "Choose on battlefield", func(): game.hud.set_status("Click a highlighted defending model to give it damage."))
	casualties_button = AppUI.button(quick_box, "Remove Casualties", func():
		if game.combat.current != null: AssistanceService.request(game, "remove_defeated", {"unit": str(game.combat.current.target.name)}))
	focus_button = AppUI.button(quick_box, "Focus Problem", focus_problem)
	next_button = game.hud.next_action_button
	game.hud.confirm_move.get_parent().reparent(quick_box)
	game.hud.combat_panel.visibility_changed.connect(schedule_refresh)
	roster = label(parent)
	roster.hide()

func schedule_refresh() -> void:
	if refresh_pending or not is_inside_tree(): return
	refresh_pending = true
	call_deferred("refresh")

func owned(team: int) -> bool:
	if game.get("ai") != null and game.ai.controls(team): return false
	return game.network_session == null or team == (0 if game.network_session.host else 1)

func state(unit: TableUnit) -> Dictionary:
	return PhaseAssistant.states(game.battle_log, game.manager.round_number, int(game.initial_scenario.starting_state.round), bool(game.initial_scenario.starting_state.deployment)).get(str(unit.name), {})

func begin_move() -> void:
	understood("action")
	understood("move_help")
	intent = ""
	target = null
	clear_marks()
	game.interaction.begin_quick_move("Auto" if game.settings.quick_movement else "Manual")
	formation_choice.select(0 if game.settings.quick_movement else 4)
	schedule_refresh()

func begin_attack() -> void:
	understood("action")
	understood("shoot_help")
	game.interaction.set_mode(3)
	intent = "attack"
	target = null
	problem = {}
	refresh()
	var legal := targets.filter(func(enemy): return not AttackOptions.groups(game.selection.selected_unit(), enemy, game.get_world_3d(), game.manager.phase).is_empty())
	if legal.size() == 1: choose_target(legal[0])

func begin_charge() -> void:
	understood("action")
	var unit: TableUnit = game.selection.selected_unit()
	if unit == null: return
	var grant := ChargeRules.grant(game, unit)
	if not grant.is_empty(): preview_charge(unit, grant); return
	game.interaction.set_mode(3)
	intent = "charge"
	target = null
	problem = {}
	refresh()

func choose_target(enemy: TableUnit) -> void:
	if enemy.living_models().is_empty(): return
	target = enemy
	game.interaction.target_model = enemy.living_models()[0]
	if game.selection.primary() != null: game.interaction.update_target(game.selection.primary(), enemy.living_models()[0])
	refresh()

func clear_marks() -> void:
	for model in marked:
		if is_instance_valid(model): model.target_candidate = false; model.attack_eligibility = -1; model.target_hint = ""; model.refresh()
	marked.clear()

func refresh() -> void:
	refresh_pending = false
	if not is_instance_valid(game) or game.replay_mode or game.editing: return
	var unit: TableUnit = game.selection.selected_unit()
	var moving := game.interaction.session != null
	var pending: bool = game.combat.current != null and game.combat.current.remaining > 0
	var ours: bool = unit != null and owned(unit.team) and unit.team == game.manager.active_team and not unit.living_models().is_empty()
	var actions: Dictionary = state(unit) if unit != null else {}
	var todo: Array = PhaseAssistant.pending(game.battlefield, game.manager, game.battle_log) if game.manager.phase in [1, 2, 3, 4] else []
	ready_units = todo
	move_button.visible = ours and (game.manager.deployment or game.manager.phase in [0, 1])
	if moving or pending or not intent.is_empty(): move_button.hide()
	move_button.disabled = moving or pending or (not game.manager.deployment and int(actions.get("moved", 0)) > 0)
	move_button.tooltip_text = "This squad has moved. Advanced allows manual adjustments." if move_button.disabled else "Click a destination, then Confirm."
	attack_button.visible = ours and not game.manager.deployment and game.manager.phase in [2, 4]
	if moving or pending or not intent.is_empty(): attack_button.hide()
	attack_button.disabled = moving or pending or not todo.has(unit)
	attack_button.tooltip_text = "This squad has attacked, or has no eligible target for this phase." if attack_button.disabled else "Choose an enemy; review and confirm Fire All."
	charge_button.visible = ours and not game.manager.deployment and game.manager.phase == 3
	if moving or pending or not intent.is_empty(): charge_button.hide()
	var charge: Dictionary = ChargeRules.grant(game, unit) if unit != null else {}
	charge_button.disabled = moving or pending or int(actions.get("charged", 0)) > 0 or (not todo.has(unit) and (charge.is_empty() or float(charge.distance) < float(charge.required)))
	charge_button.text = "Resume charge" if not charge.is_empty() and not charge_button.disabled else "Charge"
	formation_choice.visible = moving and (not problem.is_empty() or game.hud.advanced_box.visible or not game.settings.quick_movement)
	if moving:
		var rows := PackedStringArray()
		for model in game.interaction.session.origins:
			var session: SquadMoveSession = game.interaction.session
			var penalty := MovementService.path_penalty(game.battlefield, model, session.paths[model])
			rows.append('%s: %.1f" moved / %.1f" left%s' % [model.code(), maxf(0, session.route_cost(model) - penalty), maxf(0, session.limit(model) - session.route_cost(model)), ' / terrain %.1f"' % penalty if penalty > 0 else ""])
		preview.text = "\n".join(rows)
		if game.interaction.quick_anchor:
			var result: Dictionary = game.interaction.last_formation
			if result.is_empty(): preview.text = "Click a destination on the battlefield.\n\nThe soft guide shows your movement budget. Walls and spacing are checked when you click."
			elif not result.ok: preview.text = "This squad doesn't fit here.\n" + game.hud.friendly_message(str(result.error)) + "\n\nTry a nearby point, or choose Manual below."
			else: preview.text = ("Closest legal formation\nThe exact position didn't fit. Confirm to use this, or click to adjust.\n\n" if result.adjusted else "✓ Squad fits here\nConfirm, or click another destination.\n\n") + preview.text
			game.hud.confirm_move.disabled = result.is_empty() or not bool(result.get("ok", false))
		target_choice.hide()
		commit_button.hide()
		split_button.hide()
	else:
		refresh_targets(unit)
	if unit != null:
		var grant := ChargeRules.grant(game, unit)
		var signature := "%s/%s/%s" % [str(unit.name), str(grant.get("round", "")), str(grant.get("rolls", []))]
		if not grant.is_empty() and signature != last_charge and intent == "charge":
			last_charge = signature
			if float(grant.distance) + .001 >= float(grant.required): preview_charge(unit, grant)
			else:
				intent = ""
				preview.text = 'Charge needed %.1f". Dice %s = %d". Not enough this time.' % [grant.required, str(grant.rolls), grant.distance]
				game.hud.set_status(preview.text)
	refresh_damage()
	var show_casualties: bool = casualties_button.visible and game.combat.current.attack_id != dismissed_result
	quick_card.visible = (moving or not intent.is_empty() or pending or not problem.is_empty() or show_casualties or game.hud.combat_panel.batch_running) and not game.hud.combat_panel.visible
	cancel_intent.visible = (not intent.is_empty() or not problem.is_empty() or show_casualties) and not moving and not pending
	cancel_intent.text = "Keep defeated models / close" if show_casualties and intent.is_empty() else "Cancel"
	if not problem.is_empty() and not moving and intent.is_empty() and not pending: preview.text = str(problem.get("error", "Check this placement."))
	dice_details.visible = not moving and intent.is_empty() and game.combat.current != null
	if not moving and intent.is_empty() and game.combat.current != null:
		var result: Dictionary = game.combat.current.result
		preview.text = "%s\n%d Attacks → %d Hits → %d Wounds\n%d Failed Saves → %d Damage" % [result.weapon.name, result.attacks, result.hits, result.wounds, result.failed_saves, result.damage]
	focus_button.visible = not problem.is_empty() or pending
	focus_button.text = "Focus defenders" if pending else "Show problem"
	next_button.text = "Confirm Move" if moving else "Allocate Damage" if pending else "Next Unit" if not todo.is_empty() else "Continue to " + GameManager.PHASES[(game.manager.phase + 1) % 6]
	next_button.visible = moving or pending or not todo.is_empty() or game.settings.offer_next_phase
	next_button.disabled = game.manager.deployment or not owned(game.manager.active_team)
	if not moving and not pending and intent.is_empty() and game.settings.offer_next_phase and todo.is_empty() and not game.manager.deployment:
		hint.text = GameManager.PHASES[game.manager.phase] + " complete. Continue when ready."
	else:
		hint.text = "Select one of your squads to begin." if not game.settings.gameplay_hints.get("select", false) else "Choose Move, Attack or Charge." if not game.settings.gameplay_hints.get("action", false) else ""
	var rows := PackedStringArray()
	for squad: TableUnit in game.battlefield.units.get_children():
		if squad.team != game.manager.active_team: continue
		var flags := state(squad)
		var field := "moved" if game.manager.phase in [0, 1] else "ranged" if game.manager.phase == 2 else "charged" if game.manager.phase == 3 else "melee"
		rows.append("%s  %s" % [squad.display_name.trim_suffix(" Squad"), "Defeated" if squad.living_models().is_empty() else "✓ Done" if int(flags.get(field, 0)) > 0 else "Charge rolled" if field == "charged" and int(flags.get("charge_rolled", 0)) > 0 else "○ Ready"])
	roster.text = "\n".join(rows)
	if game.guidance != null: game.guidance.schedule_refresh()
	if game.manager.scores != last_scores:
		game.hud.set_status("Score: %s +%d / %s +%d → %s — %s" % [ObjectiveControl.team_name(game.battlefield.units.get_children(), 0), int(game.manager.scores["0"]) - int(last_scores["0"]), ObjectiveControl.team_name(game.battlefield.units.get_children(), 1), int(game.manager.scores["1"]) - int(last_scores["1"]), str(game.manager.scores["0"]), str(game.manager.scores["1"])])
		last_scores = game.manager.scores.duplicate()
	if game.settings.auto_advance_phase and game.manager.phase in [1, 2, 3, 4] and todo.is_empty() and not moving and not pending and intent.is_empty() and not game.hud.combat_panel.batch_running and owned(game.manager.active_team):
		game.manager.next_phase()

func refresh_targets(unit: TableUnit) -> void:
	clear_marks()
	targets.clear()
	target_choice.clear()
	target_choice.visible = intent in ["attack", "charge"] and unit != null
	commit_button.visible = target_choice.visible and is_instance_valid(target)
	split_button.visible = intent == "attack" and unit != null
	if not target_choice.visible: return
	for enemy: TableUnit in game.battlefield.units.get_children():
		if enemy.team == unit.team or enemy.living_models().is_empty(): continue
		var groups: Array = AttackOptions.groups(unit, enemy, game.get_world_3d(), game.manager.phase) if intent == "attack" else []
		var distance := ChargeRules.required(unit, enemy, 0)
		var attacks := 0
		for group in groups: attacks += int(group.preview.attacks)
		var legal := attacks > 0 if intent == "attack" else ChargeRules.error_for(game, unit, enemy, unit.team).is_empty()
		var reach := 0.0
		for weapon in unit.weapon_profiles:
			if (weapon.get("type", "ranged") == "melee") == (game.manager.phase == 4): reach = maxf(reach, float(weapon.range))
		for model in enemy.living_models():
			model.target_hint = "Can attack · %d attacks available" % attacks if legal else 'Out of range · %.1f" away' % distance if distance > reach else "Blocked by terrain · try moving for a clear view"
			marked.append(model)
		if not legal and game.settings.hide_illegal_targets: continue
		targets.append(enemy)
		target_choice.add_item('%s / %.1f" / %s' % [enemy.display_name, distance, str(attacks) + " attacks" if intent == "attack" and legal else "charge target" if legal else "out of range / blocked"])
		if enemy == target: target_choice.select(targets.size() - 1)
		if legal:
			for model in enemy.living_models(): model.target_candidate = true; model.refresh(); marked.append(model)
	if target == null:
		target_choice.select(-1)
		preview.text = "Choose an enemy on the battlefield or in this list."
		commit_button.hide()
		return
	if intent == "charge":
		preview.text = 'CHARGE → %s\nRequired: %.1f"\nRoll configured dice, then review the movement preview.' % [target.display_name, ChargeRules.required(unit, target, ChargeRules.reach(game))]
		commit_button.text = "ROLL CHARGE"
		commit_button.disabled = not ChargeRules.error_for(game, unit, target, unit.team).is_empty()
	else:
		available = AttackOptions.groups(unit, target, game.get_world_3d(), game.manager.phase)
		preview.text = AttackOptions.summary(unit, target, available) if not available.is_empty() else target.living_models()[0].target_hint if not target.living_models().is_empty() else "This squad has been defeated."
		preview.tooltip_text = AttackOptions.explanation(unit, target, available, game.get_world_3d())
		commit_button.text = "Confirm attack"
		commit_button.disabled = available.is_empty()
		for model in unit.living_models():
			var eligible := false
			for group in available:
				if group.preview.eligible_models.has(model.model_id): eligible = true
			model.attack_eligibility = 1 if eligible else 0
			model.refresh()
			marked.append(model)

func confirm_attack() -> void:
	var unit: TableUnit = game.selection.selected_unit()
	if unit == null or not is_instance_valid(target): return
	if intent == "charge":
		AssistanceService.request(game, "charge", {"attacker": str(unit.name), "target": str(target.name)})
		schedule_refresh()
		return
	available = AttackOptions.groups(unit, target, game.get_world_3d(), game.manager.phase)
	if available.is_empty(): schedule_refresh(); return
	var panel: CombatPanel = game.hud.combat_panel
	panel.queued_groups.clear()
	panel.batch_waiting = false
	panel.batch_owner = unit
	for group in available: panel.queued_groups.append({"weapon": group.index, "target": target})
	panel.batch_running = true
	intent = ""
	clear_marks()
	panel.continue_batch()
	schedule_refresh()

func preview_charge(unit: TableUnit, grant: Dictionary) -> bool:
	target = NetworkAuthority.unit(game, str(grant.target))
	if target == null: return false
	game.interaction.set_mode(1)
	var session: SquadMoveSession = game.interaction.session
	if session == null: return false
	session.allowance = float(grant.distance)
	session.charge_target = str(target.name)
	game.interaction.quick_layout = "Auto"
	game.interaction.quick_anchor = true
	game.interaction.move_preview.set_compact()
	intent = ""
	var destination := ChargeRules.anchor(unit, target, ChargeRules.reach(game))
	var result := FormationPlanner.propose(session, destination)
	if not result.ok:
		problem = result
		game.hud.set_status("Charge rolled %s = %d. No legal direct formation fits. Try Manual or another destination." % [str(grant.rolls), grant.distance])
	else:
		game.hud.set_status('Charge dice %s = %d". Movement preview ready. Confirm or adjust.' % [str(grant.rolls), grant.distance])
	game.interaction.movement_changed.emit()
	return bool(result.ok)

func refresh_damage() -> void:
	var current: AttackResolution = game.combat.current
	var pending := current != null and current.remaining > 0
	var recipient := AttackOptions.suggested(current)
	var can_apply := pending and owned(current.target.team) and recipient != null
	damage.visible = pending
	apply_button.visible = can_apply
	other_button.visible = can_apply and game.hud.advanced_box.visible
	if pending:
		damage.text = "%d DAMAGE\nChoose a highlighted model.\n%s" % [current.remaining, "Suggested: " + recipient.display_name + (" (already hurt)" if recipient.wounds < recipient.max_wounds else "") if recipient != null and owned(current.target.team) else "Waiting for the defending player."]
	var dead := false
	if current != null:
		for model in current.target.models:
			if model.wounds == 0 and not model.removed: dead = true
	casualties_button.visible = dead and not pending and owned(current.target.team)

func apply_suggestion() -> void:
	var current: AttackResolution = game.combat.current
	var recipient := AttackOptions.suggested(current)
	if recipient != null and current.remaining > 0: game.combat.allocate(recipient, mini(current.remaining, recipient.wounds))

func next_action() -> void:
	if game.get("ai") != null and (game.ai.active() or game.ai.finished): return
	if game.interaction.session != null: game.interaction.confirm_unit_move(); return
	if game.combat.current != null and game.combat.current.remaining > 0: focus_problem(); return
	if game.hud.combat_panel.batch_running: game.hud.set_status("Finishing weapon groups. Allocate pending damage first."); return
	var todo: Array = PhaseAssistant.pending(game.battlefield, game.manager, game.battle_log) if game.manager.phase in [1, 2, 3, 4] else []
	if not todo.is_empty(): game.hud.select_next_unit()
	else: game.manager.next_phase()

func ready() -> void:
	problem = {}
	for team in ([game.manager.active_team] if game.network_session != null else [0, 1]):
		problem = AssistanceService.deployment_problem(game, team)
		if not problem.is_empty(): game.hud.set_status(problem.error); schedule_refresh(); return
	AssistanceService.request(game, "ready")

func focus_problem() -> void:
	if game.interaction.session != null and not problem.get("ghosts", []).is_empty():
		game.camera_rig.focus(problem.ghosts[0])
		return
	var model: Miniature
	if problem.has("model"): model = WorldState.registry(game).get(str(problem.model)) as Miniature
	if model == null and problem.has("unit"):
		var unit := NetworkAuthority.unit(game, str(problem.unit))
		if unit != null and not unit.models.is_empty(): model = unit.models[0]
	if model == null: model = AttackOptions.suggested(game.combat.current)
	if model == null: model = game.selection.primary()
	if model != null: game.camera_rig.focus(model.global_position)
	if game.combat.current != null and game.combat.current.remaining > 0 and owned(game.combat.current.target.team) and game.hud.advanced_box.visible: game.hud.combat_panel.show(); game.hud.combat_panel.suggest_model()

func understood(key: String) -> void:
	if game.settings.gameplay_hints.get(key, false): return
	game.settings.gameplay_hints[key] = true
	game.settings.save_settings()

func show_overrides() -> void:
	if game.network_session != null and not game.network_session.host: game.hud.set_status("Only the host can use Manual Override."); return
	if is_instance_valid(override_window): override_window.queue_free()
	override_window = Window.new()
	override_window.title = "Manual Override / Referee"
	override_window.size = Vector2i(490, 600)
	override_window.close_requested.connect(override_window.hide)
	add_child(override_window)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	override_window.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.theme = AppUI.theme()
	scroll.add_child(box)
	label(box, "Corrections are recorded. Host / local referee only.")
	var team_choice := AppUI.choices(box, ["Team A", "Team B"], game.manager.active_team)
	var points := AppUI.spin(box, "Score", game.manager.scores[str(game.manager.active_team)], 0, 10000000)
	AppUI.button(box, "Set Score", func(): AssistanceService.request(game, "referee", {"field": "score", "team": team_choice.selected, "value": int(points.value)}))
	var phase := AppUI.choices(box, Array(GameManager.PHASES), game.manager.phase)
	AppUI.button(box, "Set Phase", func(): AssistanceService.request(game, "referee", {"field": "phase", "value": phase.selected}))
	var objectives := OptionButton.new()
	var ids: Array[String] = []
	for objective: TableObjective in game.battlefield.objectives.get_children(): ids.append(objective.object_id); objectives.add_item(objective.display_name)
	box.add_child(objectives)
	var owner := AppUI.choices(box, ["Automatic", "Neutral", "Team A", "Team B"], 0)
	AppUI.button(box, "Set Objective Owner", func():
		if objectives.selected >= 0: AssistanceService.request(game, "referee", {"field": "objective", "id": ids[objectives.selected], "value": [-2, -1, 0, 1][owner.selected]}))
	var selected: Miniature = game.selection.primary()
	if selected != null:
		label(box, "Selected: " + selected.unit_name + " / " + selected.code())
		var wounds := AppUI.spin(box, "Wounds", selected.wounds, 0, selected.max_wounds)
		AppUI.button(box, "Set Wounds", func(): AssistanceService.request(game, "referee", {"field": "wounds", "id": selected.model_id, "value": int(wounds.value)}))
		var cover := AppUI.spin(box, "Cover (-1 automatic)", -1, -1, 3)
		AppUI.button(box, "Set Squad Cover", func(): AssistanceService.request(game, "referee", {"field": "cover", "id": str(selected.get_parent().name), "value": int(cover.value)}))
	label(box, "Position: use More > Manual Move or Setup where permitted.")
	override_window.popup_centered()
