extends SceneTree

var checks := 0
var failures := 0
var game: Node3D
var unit: TableUnit
var enemy: TableUnit

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func frames() -> void:
	for i in 3: await process_frame
	await physics_frame
	await physics_frame

func fixture(phase: int = 1, deploy: bool = false) -> Dictionary:
	var data: Dictionary = ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json").data.duplicate(true)
	data.armies = [data.armies[0], data.armies[4]]
	for i in data.armies[1].models.size(): data.armies[1].models[i].position = [-11.05 + i * 2.1, 0, -6]
	var profile := ContentRegistry.unit({"unit_id": "legion_trooper"})
	profile.weapons = ["legion_rifle", "legion_cannon", "combat_blade"]
	data.armies[0].profile_snapshot = profile
	data.terrain = [{"id": "rubble", "title": "Rubble", "kind": "box", "size": [16, .1, 2], "position": [-10, 0, 4], "blocks_movement": false, "blocks_los": false, "difficult_ground": true}]
	data.rules = {"difficult_ground_penalty": 2, "charge": {"dice": 1, "sides": 2, "bonus": 18, "engagement_range": 1}}
	data.starting_state = {"round": 1, "phase": phase, "team": 0, "deployment": deploy}
	return data

func load_fixture(phase: int = 1, deploy: bool = false) -> void:
	if game == null:
		game = load("res://scenes/main/main.tscn").instantiate()
		game.settings = AppSettings.new()
		game.settings.autosave = false
		game.settings.camera_assistance = false
		game.settings.combat_camera = false
		game.scenario = fixture(phase, deploy)
		root.add_child(game)
	else:
		game.replay_mode = false
		game.interaction.read_only = false
		game.apply_scenario(fixture(phase, deploy))
	game.hud.show()
	unit = game.battlefield.units.get_child(0)
	enemy = game.battlefield.units.get_child(1)
	game.selection.select_unit(unit)
	await frames()

func run() -> void:
	root.size = Vector2i(1440, 900)
	var settings := AppSettings.new()
	check(settings.assistance == "Guided" and settings.quick_movement and settings.combat_resolution == "Fast", "New player defaults use Guided quick flow")
	check(settings.offer_next_phase and not settings.auto_advance_phase, "Phase offer defaults ON; silent advance OFF")
	check(not settings.auto_allocate_damage and not settings.auto_remove_defeated, "Important allocation/removal choices retained by default")
	settings.apply_assistance_preset("Tabletop")
	check(not settings.quick_movement and settings.combat_resolution == "Detailed", "Tabletop preserves manual positioning and detailed results")
	settings.apply_assistance_preset("Custom")
	settings.combat_resolution = "Manual"
	settings.auto_allocate_damage = true
	settings.save_settings()
	var restored := AppSettings.new()
	restored.load_settings()
	check(restored.assistance == "Custom" and restored.combat_resolution == "Manual" and restored.auto_allocate_damage, "Custom preferences persist")
	settings.apply_assistance_preset("Assisted")
	check(settings.quick_movement and not settings.auto_advance_phase and not settings.auto_allocate_damage, "Assisted reset keeps decisions explicit")
	await load_fixture()
	check(not game.hud.advanced_box.visible, "Advanced controls hidden during normal play")
	check(game.assistance.move_button.visible, "Move is prominent during Movement")
	game.assistance.move_button.pressed.emit()
	check(game.interaction.quick_anchor and game.interaction.session != null, "Move starts anchor placement without model dragging")
	var destination := FormationPlanner.center(unit.living_models()) + Vector3(0, 0, -2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.camera_rig.camera.unproject_position(destination)
	root.push_input(click, true)
	check(FormationPlanner.center(unit.living_models()).distance_to(destination) < .02, "Destination click generates whole-squad preview")
	check(CoherencyService.is_unit_coherent(unit), "Generated preview is coherent")
	check(game.interaction.session.validation_error().is_empty(), "Preview obeys collision/bounds/movement")
	game.hud.confirm_move.pressed.emit()
	check(game.interaction.session == null and game.battle_log.entries.back().payload.kind == "unit_move", "Confirm emits canonical squad move")
	check(int(game.assistance.state(unit).get("moved", 0)) == 1, "Confirmed movement tracks completion")
	game.history.undo()
	check(int(game.assistance.state(unit).get("moved", 0)) == 0, "Undo restores readiness")
	game.history.redo()
	check(int(game.assistance.state(unit).get("moved", 0)) == 1, "Redo restores completion")
	game.interaction.begin_quick_move()
	var origins: Dictionary = game.interaction.session.origins.duplicate()
	var rejected := FormationPlanner.propose(game.interaction.session, Vector3(-10, 0, 0), "Auto", false)
	check(not rejected.ok, "Movement plus difficult terrain cannot exceed budget")
	for model in origins: check(model.global_position == origins[model], "Rejected formation restores every model")
	var route := [ScenarioFactory.array(unit.models[0].global_position), ScenarioFactory.array(unit.models[0].global_position + Vector3(0, 0, -4))]
	check(is_equal_approx(MovementService.path_cost(game.battlefield, unit.models[0], route), 6), "4 inch move plus 2 inch terrain penalty costs 6")
	var many := [route[0], ScenarioFactory.array(unit.models[0].global_position + Vector3(0, 0, -2)), route[1]]
	check(is_equal_approx(MovementService.path_cost(game.battlefield, unit.models[0], many), 6), "Extra waypoints never multiply terrain penalty")
	game.interaction.cancel()
	check(ScenarioFactory.capture(game).terrain[0].movement_penalty == 2, "Editor capture persists difficult terrain")
	var malformed := fixture()
	malformed.terrain[0].movement_penalty = -2
	check(not ScenarioDefinition.validate(malformed).is_empty(), "Invalid terrain cost rejected")
	malformed = fixture()
	malformed.rules.charge.sides = 100
	check(not ScenarioDefinition.validate(malformed).is_empty(), "Invalid charge dice rejected")
	await load_fixture(2)
	game.assistance.begin_attack()
	check(game.assistance.target == enemy, "One legal target is preselected, not fired on")
	check(game.combat.current == null, "Smart default remains reversible before confirmation")
	check(game.assistance.available.size() == 2, "All usable ranged groups discovered automatically")
	check(game.assistance.preview.text.contains("attacks"), "Concise preview includes automatic attack counts")
	check(AttackOptions.explanation(unit, enemy, game.assistance.available, game.get_world_3d()).contains("Why:"), "Automatic calculations are explainable")
	game.dice.rng.seed = 42
	game.assistance.commit_button.pressed.emit()
	check(game.combat.current != null, "One confirmation resolves full first-group dice pipeline")
	check(game.combat.current.result.hit_rolls.size() == game.combat.current.result.attacks, "Exact attack dice recorded")
	var first_id: int = game.combat.current.attack_id
	var presentation: CombatPresentation
	for child in game.get_children():
		if child is CombatPresentation: presentation = child
	var canonical_before := NetworkSession.state_hash(WorldState.capture(game))
	for mode in ["Fast", "Detailed", "Manual"]:
		game.settings.combat_resolution = mode
		presentation.last_attack = -1
		presentation.on_combat()
		if mode == "Fast": check(presentation.dice_button.visible, "Fast result offers optional exact dice")
		if mode == "Detailed": check(presentation.sequence != null, "Detailed resolves presentation automatically")
		if mode == "Manual":
			check(presentation.reveal_button.visible, "Manual offers explicit result stages")
			for i in 4: presentation.reveal_next()
			check(not presentation.reveal_button.visible, "Manual stages finish without rerolling")
		check(NetworkSession.state_hash(WorldState.capture(game)) == canonical_before, "Combat display mode does not alter canonical results: " + mode)
	game.settings.combat_resolution = "Fast"
	if game.combat.current.remaining > 0:
		var before: int = game.combat.current.remaining
		var recipient := AttackOptions.suggested(game.combat.current)
		var wounds := recipient.wounds
		game.assistance.apply_suggestion()
		check(game.combat.current.remaining == before - mini(before, wounds), "Apply handles arithmetic for suggested allocation")
	game.combat.discard_pending()
	game.hud.combat_panel.continue_batch()
	check(game.combat.current.attack_id != first_id, "Fire All automatically advances to next weapon group")
	game.combat.discard_pending()
	game.hud.combat_panel.continue_batch()
	check(not game.hud.combat_panel.batch_running, "Weapon batch completes without extra dice steps")
	check(int(game.assistance.state(unit).get("ranged", 0)) > 0, "Attack completion tracked from canonical records")
	await load_fixture(3)
	game.assistance.begin_charge()
	game.assistance.choose_target(enemy)
	var needed := ChargeRules.required(unit, enemy)
	check(needed > 0 and game.combat.current == null, "Charge previews required base distance without attacking")
	game.dice.rng.seed = 7
	game.assistance.confirm_attack()
	await frames()
	var grant := ChargeRules.grant(game, unit)
	check(not grant.is_empty() and grant.rolls.size() == 1 and grant.distance >= 19, "Configured host dice produce a recorded allowance")
	check(game.interaction.session != null and game.interaction.session.allowance == grant.distance, "Successful charge automatically opens movement preview")
	check(game.interaction.session.validation_error().is_empty(), "Charge formation obeys coherency, cost, target and collision")
	var record: Dictionary = game.interaction.session.action().record()
	var baseline := WorldState.capture(game)
	for item in baseline.models:
		for model in game.interaction.session.origins:
			if item.id == model.model_id: item.position = ScenarioFactory.array(game.interaction.session.origins[model])
	check(NetworkAuthority.validate_action(game, record, 0, baseline).is_empty(), "Host validates charge geometry from canonical grant")
	var forged: Dictionary = record.duplicate(true)
	forged.metadata.charge_target = "unselected_enemy"
	check(not NetworkAuthority.validate_action(game, forged, 0, baseline).is_empty(), "Client cannot swap the rolled charge target")
	forged = record.duplicate(true)
	forged.metadata.charge_target = ""
	forged.metadata.allowance = 200
	check(not NetworkAuthority.validate_action(game, forged, 0, baseline).is_empty(), "Client cannot forge a movement allowance")
	check(game.interaction.confirm_unit_move(), "Player confirms charge position")
	check(ChargeRules.required(unit, enemy) <= .001, "Charge ends within configured engagement range")
	check(int(game.assistance.state(unit).get("charged", 0)) == 1, "Charge completion tracked canonically")
	var sequence: int = game.battle_log.sequence
	check(not AssistanceService.request(game, "charge", {"attacker": str(unit.name), "target": str(enemy.name)}), "Same squad cannot reroll charge this round")
	check(game.battle_log.sequence == sequence, "Rejected reroll emits no gameplay result")
	game.history.undo()
	check(not ChargeRules.grant(game, unit).is_empty(), "Undo permits repositioning from same roll")
	game.history.redo()
	check(ChargeRules.grant(game, unit).is_empty(), "Redo consumes recorded movement, not another roll")
	check(AssistanceService.request(game, "referee", {"field": "score", "team": 0, "value": 7}), "Local referee score correction")
	check(AssistanceService.request(game, "referee", {"field": "objective", "id": "objective_1", "value": 1}), "Local objective ownership correction")
	check(game.battlefield.control_for(game.battlefield.objectives.get_child(0)).owner == 1, "Objective override applies immediately")
	check(AssistanceService.request(game, "referee", {"field": "cover", "id": str(enemy.name), "value": 2}), "Local cover override")
	check(AttackResolver.cover_for(enemy) == 2, "Cover correction reaches shared combat rule")
	var remote := NetworkSession.new()
	game.network_session = remote
	check(not AssistanceService.validate(game, "referee", {"field": "score", "team": 1, "value": 100}, 1).is_empty(), "Guest cannot issue referee score corrections")
	check(not AssistanceService.validate(game, "charge", {"attacker": str(unit.name), "target": str(enemy.name)}, 1).is_empty(), "Guest cannot charge with host's squad")
	game.network_session = null
	remote.free()
	check(AssistanceService.request(game, "referee", {"field": "phase", "value": 4}), "Referee phase correction recorded")
	check(not AttackOptions.groups(unit, enemy, game.get_world_3d(), 4).is_empty(), "Melee context discovers melee groups")
	check(ActionCodec.validate(game.battle_log.entries, game.initial_scenario).is_empty(), "All new actions use validated canonical records")
	var expected := WorldState.capture(game)
	var expected_hash := NetworkSession.state_hash(expected)
	check(SaveService.save_game(game, game.manager, game.battle_log, game.combat, "user://assistance_test.json").begins_with("Saved"), "New assistance state saves")
	check(SaveService.load_game(game, game.manager, game.battle_log, game.combat, "user://assistance_test.json").begins_with("Loaded"), "New assistance state loads")
	if WorldState.capture(game) != expected: differences(expected, WorldState.capture(game), "state")
	check(WorldState.capture(game) == expected, "Save/load retains exact charge, readiness and override types")
	var replay := ReplayController.new()
	replay.game = game
	game.add_child(replay)
	check(replay.open({"initial_scenario": game.initial_scenario, "events": game.battle_log.entries.duplicate(true)}).is_empty(), "Automation replay opens")
	replay.seek(replay.events.size())
	check(NetworkSession.state_hash(WorldState.capture(game)) == expected_hash, "Replay reconstructs charges, moves and corrections exactly")
	await load_fixture(0, true)
	var problem := AssistanceService.deployment_problem(game, 0)
	check(not problem.is_empty() and problem.has("model"), "Deployment errors identify a model for Focus")
	game.assistance.ready()
	check(not game.assistance.problem.is_empty(), "Cannot Ready gives focus guidance")
	game.assistance.refresh()
	check(game.assistance.focus_button.is_visible_in_tree(), "Deployment Focus is visible without opening manual tools")
	var deployed := AssistanceService.request(game, "auto_deploy")
	if not deployed: print("DEPLOY ISSUE ", game.hud.status.text)
	check(deployed, "One-button local deployment places both armies")
	check(AssistanceService.deployment_problem(game, 0).is_empty() and AssistanceService.deployment_problem(game, 1).is_empty(), "Auto deployment is zoned, coherent, collision-free")
	game.assistance.ready()
	check(not game.manager.deployment, "Ready validates and starts local battle")
	check(int(game.assistance.state(unit).get("moved", 0)) == 0 and int(game.assistance.state(unit).get("deployed", 0)) > 0, "Deployment does not consume first-round movement")
	game.manager.next_phase()
	check(PhaseAssistant.pending(game.battlefield, game.manager, game.battle_log).has(unit), "Auto-deployed units are ready to move")
	check(NetworkCompatibility.error_for(NetworkCompatibility.manifest()).is_empty(), "Matching new content/gameplay build accepted")
	game.camera_rig.focus(Vector3(12, 0, 7))
	game.camera_rig.interrupt_focus()
	check(not game.camera_rig.assisted_focus and game.camera_rig.destination == game.camera_rig.position, "Manual camera input cancels assistance motion")
	game.assistance.understood("action")
	check(game.settings.gameplay_hints.get("action", false), "Understood hints are remembered")
	game.settings.gameplay_hints.clear()
	check(game.settings.gameplay_hints.is_empty(), "Gameplay hints can be reset")
	var invalid_turn: Dictionary = game.manager.snapshot()
	invalid_turn.charges = {"bad": {"rolls": [100]}}
	check(not WorldState.turn_error(invalid_turn).is_empty(), "Untrusted malformed charge state rejected")
	await load_fixture(2)
	game.dice.rng.seed = 42
	check(game.combat.resolve(unit, enemy, game.get_world_3d(), 1), "Overkill fixture resolves using equipped cannon")
	for model in enemy.models:
		if game.combat.current.remaining > 0: game.combat.allocate(model, model.wounds)
	check(enemy.living_models().is_empty() and game.combat.current.remaining == 0, "Excess damage clears automatically when no allocation decision remains")
	game.history.undo()
	check(not enemy.living_models().is_empty() and game.combat.current.remaining > 0, "Undo restores casualty and overkill pool atomically")
	game.queue_free()
	await process_frame
	print("GRIMTABLE ASSISTANCE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func differences(a: Variant, b: Variant, path: String) -> void:
	if a is Dictionary and b is Dictionary:
		for key in a:
			if not b.has(key): print("DIFF ", path, ".", key, " missing")
			else: differences(a[key], b[key], path + "." + str(key))
	elif a is Array and b is Array:
		if a.size() != b.size(): print("DIFF array size ", path)
		else:
			for i in a.size(): differences(a[i], b[i], path + "[" + str(i) + "]")
	elif a != b or typeof(a) != typeof(b): print("DIFF ", path, " ", a, " (", typeof(a), ") vs ", b, " (", typeof(b), ")")
