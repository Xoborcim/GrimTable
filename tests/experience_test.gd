extends SceneTree

var checks := 0
var failures := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func run() -> void:
	var settings := AppSettings.new()
	check(not settings.combat_camera and settings.phase_warnings and settings.automatic_scoring, "Conservative automation defaults")
	settings.quality = "Low"
	settings.reduce_motion = true
	settings.save_settings()
	var restored := AppSettings.new()
	restored.load_settings()
	check(restored.quality == "Low" and restored.reduce_motion, "Experience preferences persist")
	var item := ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json")
	check(item.has("data"), "Showcase validates")
	if not item.has("data"): quit(1); return
	for theme in ["industrial", "desert", "alien"]:
		check(BattlefieldPresentation.ground(theme) != null, "Theme loads: " + theme)
	var invalid: Dictionary = item.data.duplicate(true)
	invalid.board.theme = "unknown"
	check(not ScenarioDefinition.validate(invalid).is_empty(), "Unknown theme rejected")
	invalid = item.data.duplicate(true)
	invalid.terrain[0].cover_bonus = -1
	check(not ScenarioDefinition.validate(invalid).is_empty(), "Invalid terrain trait rejected")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new()
	game.settings.autosave = false
	game.scenario = item.data
	root.add_child(game)
	await physics_frame
	await physics_frame
	check(game.get_node("KeyLight").shadow_enabled, "Medium key shadows enabled")
	BattlefieldPresentation.apply_quality(game, settings)
	check(not game.get_node("KeyLight").shadow_enabled, "Low disables expensive shadows")
	check(root.msaa_3d == Viewport.MSAA_DISABLED, "Low disables MSAA")
	check(ScenarioFactory.capture(game).board.theme == "industrial", "Editor capture preserves theme")
	var unit: TableUnit = game.battlefield.units.get_child(0)
	var enemy: TableUnit = game.battlefield.units.get_child(3)
	game.manager.phase = 1
	game.selection.select_unit(unit)
	check(PhaseAssistant.pending(game.battlefield, game.manager, game.battle_log).has(unit), "Unmoved unit suggested")
	game.interaction.begin_unit_move()
	for model in unit.models:
		var before: Vector3 = model.global_position
		model.global_position += Vector3(0, 0, -.5)
		game.interaction.session.stage(model, before)
	check(game.interaction.confirm_unit_move(), "Squad movement commits through existing validation")
	check(int(PhaseAssistant.states(game.battle_log, 1).get(str(unit.name), {}).get("moved", 0)) == 1, "Move bookkeeping automatic")
	game.history.undo()
	check(int(PhaseAssistant.states(game.battle_log, 1).get(str(unit.name), {}).get("moved", 0)) == 0, "Undo restores unmoved status")
	game.history.redo()
	check(int(PhaseAssistant.states(game.battle_log, 1).get(str(unit.name), {}).get("moved", 0)) == 1, "Redo restores moved status")
	check(game.interaction.auto_arrange("Line"), "Line formation proposal legal")
	check(game.interaction.session.validation_error().is_empty(), "Formation uses existing validation")
	if game.interaction.session != null: game.interaction.cancel()
	check(CoherencyService.is_unit_coherent(unit), "Cancelled formation leaves coherent squad")
	game.manager.deployment = true
	check(game.interaction.auto_place_unit(), "Auto place finds a legal deployment")
	check(game.interaction.session.validation_error().is_empty(), "Auto placement obeys zones, collision and coherency")
	game.interaction.cancel()
	game.manager.deployment = false
	# Explicit cover patch; use the all-model criterion and retain its metadata.
	var patch: TerrainPiece = game.battlefield.terrain.get_node("cover_0")
	check(patch.cover_bonus == 1 and not patch.blocks_movement, "Cover area metadata loaded")
	for i in enemy.models.size(): enemy.models[i].global_position = patch.global_position + Vector3(i * 1.4 - 2.8, 0, 0)
	check(AttackResolver.cover_for(enemy) == 1, "All defending bases in area receive cover")
	enemy.models[0].global_position += Vector3(0, 0, 10)
	check(AttackResolver.cover_for(enemy) == 0, "Partially covered unit gets no implicit bonus")
	check(ScenarioFactory.capture(game).terrain.any(func(piece): return piece.id == "cover_0" and piece.cover_bonus == 1), "Terrain trait survives scenario capture")
	# Move attackers/targets into a clear lane for exact canonical combat checks.
	for i in unit.models.size(): unit.models[i].global_position = Vector3(-3 + i * 1.5, 0, 16)
	for i in enemy.models.size(): enemy.models[i].global_position = Vector3(-3 + i * 1.5, 0, 10)
	await physics_frame
	await physics_frame
	game.manager.phase = 2
	game.dice.rng.seed = 42
	check(game.combat.resolve(unit, enemy, game.get_world_3d()), "Existing canonical attack resolves")
	check(int(PhaseAssistant.states(game.battle_log, 1).get(str(unit.name), {}).get("ranged", 0)) == 1, "Ranged action automatically tracked")
	check(game.combat.current.result.hit_rolls.size() == game.combat.current.result.attacks, "Exact hit dice retained")
	check(CombatPresentation.dice_line([1, 4, 6], 4).contains("+4"), "Dice distinguish success with symbol and color")
	check(game.combat.current.remaining == game.combat.current.result.damage, "Manual damage allocation remains default")
	var panel: CombatPanel = game.hud.combat_panel
	check(panel.get_combined_minimum_size().y < 400, "Combat controls scroll instead of overflowing the viewport")
	game.interaction.target_model = enemy.models[0]
	panel.update_preview()
	panel.refresh_targets()
	check(panel.target_units.has(enemy), "Available targets include enemy")
	panel.assign_group()
	check(panel.queued_groups.size() == 1, "Weapon group assigned without resolving")
	panel.assign_group()
	check(panel.queued_groups.size() == 1, "Same group cannot be queued twice")
	panel.refresh()
	enemy.models[1].max_wounds = 2
	enemy.models[1].wounds = 1
	panel.suggest_model()
	check(panel.chosen() == enemy.models[1], "Wounded model suggested without committing damage")
	check(enemy.models[1].wounds > 0, "Suggestion leaves health untouched")
	game.combat.discard_pending()
	for i in enemy.models.size(): enemy.models[i].global_position = Vector3(-3 + i * 1.5, 0, 14)
	await physics_frame
	await physics_frame
	panel.weapon_choice.select(1)
	panel.assign_group()
	check(panel.queued_groups.size() == 2, "Different weapon groups can share or split targets")
	panel.batch_running = true
	panel.continue_batch()
	check(game.combat.current.result.weapon.id == unit.weapon_profiles[0].id, "Batch begins with first assigned group")
	game.combat.discard_pending()
	panel.continue_batch()
	check(game.combat.current.result.weapon.id == unit.weapon_profiles[1].id, "Batch keeps second profile dice separate")
	game.combat.discard_pending()
	panel.continue_batch()
	check(not panel.batch_running, "Batch completes after pending damage is handled")
	check(ActionCodec.validate(game.battle_log.entries, game.initial_scenario).is_empty(), "Canonical records retain existing replay schema")
	check(NetworkCompatibility.error_for(NetworkCompatibility.manifest()).is_empty(), "Matching 0.6 profile manifest accepted")
	var manifest := NetworkCompatibility.manifest()
	manifest.game_version = "0.5.0"
	check(not NetworkCompatibility.error_for(manifest).is_empty(), "Older gameplay build rejected")
	var replay_scenario := ScenarioFactory.capture(game)
	replay_scenario.starting_state = game.manager.snapshot()
	game.apply_scenario(replay_scenario)
	await physics_frame
	await physics_frame
	unit = game.battlefield.units.get_child(0)
	enemy = game.battlefield.units.get_child(3)
	game.dice.rng.seed = 99
	check(game.combat.resolve(unit, enemy, game.get_world_3d()), "Replay fixture attack resolves")
	var exact: Dictionary = game.combat.current.result.duplicate(true)
	var expected_hash := NetworkSession.state_hash(WorldState.capture(game))
	var replay := ReplayController.new()
	replay.game = game
	game.add_child(replay)
	check(replay.open({"initial_scenario": game.initial_scenario, "events": game.battle_log.entries.duplicate(true)}).is_empty(), "0.6 replay opens")
	replay.seek(replay.events.size())
	check(NetworkSession.state_hash(WorldState.capture(game)) == expected_hash, "0.6 replay reproduces exact canonical state")
	check(game.combat.current.result == exact, "All replay result fields retain exact canonical types")
	check(game.combat.current.result.hit_rolls == exact.hit_rolls, "Cosmetic presentation never rerolls replay dice")
	game.queue_free()
	await process_frame
	print("GRIMTABLE EXPERIENCE CHECKS: %d passed / %d failed" % [checks - failures, failures])
	quit(0 if failures == 0 else 1)
