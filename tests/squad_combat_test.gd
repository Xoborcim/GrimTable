extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func press(tool: InteractionController, model: Miniature, alt: bool = false, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = tool.rig.camera.unproject_position(model.eye())
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.alt_pressed = alt
	event.shift_pressed = shift
	root.push_input(event, true)

func drag_to(tool: InteractionController, point: Vector3) -> void:
	var event := InputEventMouseMotion.new()
	event.position = tool.rig.camera.unproject_position(point - tool.drag_offset)
	root.push_input(event, true)
	tool._process(0)
	var release := InputEventMouseButton.new()
	release.position = event.position
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	root.push_input(release, true)

func run() -> void:
	root.size = Vector2i(1440, 900)
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 3: await process_frame
	await physics_frame
	var unit := get_nodes_in_group("units")[0] as TableUnit
	var enemy := get_nodes_in_group("units")[1] as TableUnit
	var a := unit.models[0]
	var b := unit.models[1]
	var origin := a.global_position
	var second_origin := b.global_position
	check(main.manager.deployment and main.deployment.visible, "New game begins in visible deployment")
	check(main.deployment.zones.size() == 2, "Scenario creates two deployment resources")
	check(main.deployment.validation_error().is_empty(), "Default scenario has legal coherent armies")
	main.manager.next_phase()
	check(main.manager.phase == 0, "Deployment cannot advance normal phases")
	a.global_position = Vector3(-6, 0, 12)
	check(not main.start_game(), "Cannot start with a base outside deployment zone")
	a.global_position = origin
	var terrain := get_nodes_in_group("terrain")[0] as TerrainPiece
	var terrain_origin := terrain.global_position
	terrain.global_position = Vector3(25, 0, 17)
	check(not main.deployment.placement_error(a, Vector3(25, 0, 17)).is_empty(), "Deployment terrain blocking is enforced")
	terrain.global_position = terrain_origin
	check(CoherencyService.is_unit_coherent(unit), "Starting squad is coherent")
	press(main.interaction, a)
	check(main.selection.models.size() == 5 and main.selection.selected_unit() == unit, "Default click selects full squad")
	check(main.hud.selected_info.text.contains("5 models") and main.hud.selected_info.text.contains("10 / 10"), "Unit HUD aggregates count and wounds")
	for model in unit.models: check(model.selected, "Squad member highlighted")
	press(main.interaction, b, true)
	check(main.selection.models.size() == 1 and main.selection.primary() == b and main.selection.selected_unit() == null, "Alt-click selects one model")
	press(main.interaction, a)
	press(main.interaction, enemy.models[0], false, true)
	check(main.selection.models.size() == 10 and main.selection.selected_unit() == null, "Shift-click supports multiple units")
	press(main.interaction, enemy.models[0], false, true)
	check(main.selection.models.size() == 5 and main.selection.selected_unit() == unit, "Shift-click toggles whole unit")
	main.interaction.set_mode(1)
	check(main.interaction.session != null and main.interaction.session.origins.size() == 5, "Move unit records every model")
	check(not main.start_game(), "Cannot start battle with unconfirmed move")
	check(main.interaction.session.preview_error(a, origin, Vector3(-25, 0, 17)).is_empty(), "Deployment ignores movement characteristic")
	check(not main.interaction.session.preview_error(a, origin, Vector3(-25, 0, -17)).is_empty(), "Wrong-team deployment zone rejected")
	check(not main.deployment.placement_error(a, Vector3(0, 0, 13)).is_empty(), "Entire base must be within deployment zone")
	check(not main.deployment.placement_error(a, b.global_position).is_empty(), "Deployment rejects base collisions")
	main.interaction.cancel()
	check(main.start_game(), "Legal armies can start battle")
	check(not main.manager.deployment and not main.deployment.visible, "Starting battle hides zones")
	main.selection.select_unit(unit)
	main.interaction.set_mode(1)
	press(main.interaction, a)
	drag_to(main.interaction, origin + Vector3(0, 0, 1))
	press(main.interaction, b)
	drag_to(main.interaction, second_origin + Vector3(0, 0, 1))
	check(a.global_position.is_equal_approx(origin + Vector3(0, 0, 1)) and b.global_position.is_equal_approx(second_origin + Vector3(0, 0, 1)), "Multiple models stage in one squad move")
	check(is_equal_approx(main.interaction.session.spent[a], 1), "Movement cost recorded per model")
	check(not main.interaction.session.preview_error(a, a.global_position, a.global_position + Vector3(0, 0, 5.1)).is_empty(), "Multiple drags cannot reset allowance")
	main.interaction.cancel()
	check(a.global_position.is_equal_approx(origin) and b.global_position.is_equal_approx(second_origin), "Cancel restores entire squad")
	main.interaction.begin_unit_move()
	press(main.interaction, a)
	drag_to(main.interaction, origin + Vector3(0, 0, 3))
	check(not CoherencyService.is_unit_coherent(unit), "Isolated model breaks coherency")
	check(CoherencyService.get_incoherent_models(unit).has(a), "Disconnected model identified")
	check(not main.interaction.confirm_unit_move(), "Out-of-coherency confirmation rejected")
	check(main.hud.movement_info.text.contains("UNIT OUT OF COHERENCY"), "Coherency warning visible")
	main.interaction.manual_override = true
	main.interaction.session.spent[a] = 7.0
	check(not main.interaction.confirm_unit_move(), "Manual override cannot bypass movement allowance")
	main.interaction.session.spent[a] = 3.0
	check(main.interaction.confirm_unit_move(), "Explicit coherency override permits placement")
	main.undo_action()
	check(a.global_position.is_equal_approx(origin), "Undo unit movement restores model")
	main.interaction.manual_override = false
	main.selection.select_unit(unit)
	main.interaction.set_mode(1)
	press(main.interaction, a)
	drag_to(main.interaction, origin + Vector3(0, 0, 1))
	press(main.interaction, b)
	drag_to(main.interaction, second_origin + Vector3(0, 0, 1))
	check(main.interaction.confirm_unit_move(), "Legal coherent squad move confirms")
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.ctrl_pressed = true
	key.pressed = true
	root.push_input(key, true)
	check(a.global_position.is_equal_approx(origin) and b.global_position.is_equal_approx(second_origin), "Ctrl+Z restores all squad positions")
	key = key.duplicate()
	key.keycode = KEY_Y
	root.push_input(key, true)
	check(a.global_position.is_equal_approx(origin + Vector3(0, 0, 1)) and b.global_position.is_equal_approx(second_origin + Vector3(0, 0, 1)), "Ctrl+Y reapplies squad movement")
	main.undo_action()
	# Connectivity rejects separate internally coherent groups, and is configurable.
	var saved_positions := {}
	for i in unit.models.size():
		var model := unit.models[i]
		saved_positions[model] = model.global_position
		model.global_position = Vector3(i * 2 if i < 2 else 15 + i * 2, 0, 17)
	check(not CoherencyService.is_unit_coherent(unit), "Two disconnected groups fail coherency")
	unit.coherency_distance = 30
	check(CoherencyService.is_unit_coherent(unit), "Rulesets can configure coherency distance")
	unit.coherency_distance = 2
	for model: Miniature in saved_positions: model.global_position = saved_positions[model]
	check(AttackResolver.wound_target(8, 4) == 2 and AttackResolver.wound_target(5, 4) == 3 and AttackResolver.wound_target(4, 4) == 4 and AttackResolver.wound_target(3, 4) == 5 and AttackResolver.wound_target(2, 4) == 6, "Strength/defense thresholds")
	check(AttackResolver.save_target(3, -1) == 4 and AttackResolver.save_target(3, -5) == 7, "AP worsens saving threshold, including impossible saves")
	check(DiceManager.count_successes([1, 2, 3, 4, 5, 6], 4) == 3, "Dice success helper")
	check(main.dice.roll_d6(0).is_empty(), "Zero hits produces zero subsequent dice")
	for i in unit.models.size():
		unit.models[i].global_position = Vector3(-27 + i * 1.4, 0, 18)
		enemy.models[i].global_position = Vector3(-27 + i * 1.4, 0, 2)
	await physics_frame
	await physics_frame
	check(AttackResolver.eligible_attackers(unit, enemy, main.get_world_3d(), unit.weapon_profiles[0]).size() == 5, "Each attacker checked for range and LOS")
	a.wounds = 0
	check(AttackResolver.eligible_attackers(unit, enemy, main.get_world_3d(), unit.weapon_profiles[0]).size() == 4, "Defeated models do not contribute attacks")
	a.wounds = 2
	var short_weapon: Dictionary = unit.weapon_profiles[0].duplicate()
	short_weapon.range = 1
	check(AttackResolver.resolve(main.dice, unit, enemy, main.get_world_3d(), short_weapon).has("error"), "Attack rejects out-of-range units")
	check(AttackResolver.resolve(main.dice, unit, unit, main.get_world_3d(), unit.weapon_profiles[0]).has("error"), "Cannot resolve friendly attacks")
	main.interaction.set_mode(3)
	main.selection.select_unit(unit)
	main.camera_rig.destination = Vector3(-24, 0, 10)
	main.camera_rig.distance = 45
	main.camera_rig._update_camera(1)
	press(main.interaction, enemy.models[0])
	check(main.interaction.target_model != null and main.interaction.target_model.get_parent() == enemy and main.selection.selected_unit() == unit, "Target click retains attacking squad and chooses enemy unit")
	main.dice.rng.seed = 42
	check(main.combat.resolve(unit, enemy, main.get_world_3d()), "Generic attack resolves")
	var result: Dictionary = main.combat.current.result
	check(result.attacks == 10 and result.hit_rolls.size() == 10, "Attacks scale with eligible models")
	check(result.hits == DiceManager.count_successes(result.hit_rolls, 3), "Hit rolls determine hits")
	check(result.wound_rolls.size() == result.hits and result.wounds == DiceManager.count_successes(result.wound_rolls, 4), "Actual hit count feeds wound rolls")
	check(result.save_rolls.size() == result.wounds and result.failed_saves == result.wounds - DiceManager.count_successes(result.save_rolls, 4), "Actual wound count feeds save rolls")
	check(result.damage == result.failed_saves and enemy.models[0].wounds == 2, "Damage calculated without applying wounds")
	check(main.hud.combat_panel.summary.text.contains("HIT") and main.hud.combat_panel.summary.text.contains("SAVE"), "Attack panel displays all stages")
	main.undo_action()
	check(main.combat.current == null, "Attack resolution itself is undoable")
	main.redo_action()
	check(main.combat.current.result.hit_rolls == result.hit_rolls, "Redo resolution restores stored dice without reroll")
	# Fix a generic damage value for the same deterministic rolls, to exercise allocation.
	if main.combat.current.remaining < 2:
		main.combat.discard_pending()
		unit.weapon_profiles[0].damage = 2
		main.dice.rng.seed = 42
		main.combat.resolve(unit, enemy, main.get_world_3d())
	check(main.combat.current.remaining >= 2, "Fixture produces allocatable damage")
	var victim := enemy.models[0]
	var remaining: int = main.combat.current.remaining
	check(not main.combat.allocate(a, 1), "Cannot allocate to an attacker")
	check(main.combat.allocate(victim, 2), "Player explicitly allocates damage")
	check(victim.wounds == 0 and not victim.removed and main.combat.current.remaining == remaining - 2, "Defeated model stays and damage pool decreases")
	main.undo_action()
	check(victim.wounds == 2 and main.combat.current.remaining == remaining, "Undo damage restores health and pending pool")
	main.redo_action()
	check(victim.wounds == 0, "Redo damage uses stored values, no reroll")
	check(main.combat.remove_casualty(victim) and victim.removed, "Explicit remove casualty action")
	main.undo_action()
	check(not victim.removed and victim.wounds == 0, "Casualty removal can be undone")
	check(main.battle_log.entries.any(func(event: Dictionary): return event.kind == "attack" and event.payload.has("hit_rolls")), "Battle log records individual attack rolls")
	check(main.battle_log.entries.any(func(event: Dictionary): return event.kind == "execute" and event.payload.metadata.get("casualties", []).has(victim.model_id)), "Battle log records casualties")
	check(not JSON.stringify(main.battle_log.entries).contains("RefCounted"), "Event records contain serializable state and stable IDs")
	var objective := get_nodes_in_group("objectives")[0] as TableObjective
	var objective_start := objective.global_position
	objective.global_position += Vector3(1, 0, 0)
	main.interaction.record_move(objective, objective_start, "Move objective")
	main.undo_action()
	check(objective.global_position.is_equal_approx(objective_start), "Undo objective movement")
	main.selection.select(a)
	main.hud._wounds(-1)
	main.undo_action()
	check(a.wounds == 2, "Manual wound changes are undoable")
	var save_path := SaveService.PATH
	var existed := FileAccess.file_exists(save_path)
	var backup := FileAccess.get_file_as_bytes(save_path) if existed else PackedByteArray()
	var saved_remaining: int = main.combat.current.remaining
	var saved_log_count: int = main.battle_log.entries.size()
	main.hud.save_requested.emit()
	main.combat.reset()
	main.manager.deployment = true
	main.hud.load_requested.emit()
	check(not main.manager.deployment and not main.deployment.visible, "Load restores battle/deployment state")
	check(main.combat.current != null and main.combat.current.remaining == saved_remaining, "Load preserves unapplied damage")
	check(main.battle_log.entries.size() == saved_log_count and main.history.undo_stack.is_empty(), "Load restores event log and clears stale action commands")
	var malformed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	malformed.battle_log.append({"sequence": 999, "kind": "attack", "payload": {}})
	var bad_file := FileAccess.open(save_path, FileAccess.WRITE)
	bad_file.store_string(JSON.stringify(malformed))
	bad_file.close()
	check(SaveService.load_game(main, main.manager, main.battle_log, main.combat).begins_with("Load failed"), "Malformed attack log rejected without partial restore")
	if existed:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		file.store_buffer(backup)
		file.close()
	else: DirAccess.remove_absolute(save_path)
	print("GRIMTABLE SQUADS/COMBAT: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
