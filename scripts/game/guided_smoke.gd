class_name GuidedSmoke
extends Node

var checks := 0
var failures: Array[String] = []
var game: Node3D

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error("GUIDED SMOKE: " + message)

func settle() -> void:
	for i in 8: await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func click_world(point: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game.camera_rig.camera.unproject_position(point)
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)

func advance() -> void:
	game.hud.continue_button.pressed.emit()
	if game.hud.phase_warning.visible:
		game.hud.phase_warning.confirmed.emit()
		game.hud.phase_warning.hide()
	await settle()

func run(app: Node) -> void:
	check(app.settings.assistance == "Guided", "Fresh settings default Guided")
	app.settings.autosave = false
	check(is_instance_valid(app.game) if "--smoke-visual" in OS.get_cmdline_user_args() else app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json")), "Ashfall starts without documentation")
	game = app.game
	await settle()
	check(game.battlefield.units.get_child_count() == 6, "Three squads on each side")
	check(game.manager.phase == 1 and game.guidance.steps[0].text.contains("Move"), "Starts on visible Move step")
	check(game.guidance.instruction.text.contains("Position"), "Plain-language phase instruction")
	check(not game.hud.sidebar.visible, "No-selection unit card hidden")
	check(game.guidance.hint_title.text == "Your turn", "First hint explains whose units to use")
	check(game.hud.next_action_button.is_visible_in_tree(), "Selection next step visible")
	await capture("user://guided_first_minute.png")
	game.guidance.dismiss_hint()
	check(game.settings.gameplay_hints.get("welcome", false), "Welcome dismiss persists")
	var unit: TableUnit = game.battlefield.units.get_child(0)
	var enemy: TableUnit = game.battlefield.units.get_child(3)
	click_world(unit.models[2].global_position)
	await settle()
	check(game.selection.selected_unit() == unit, "Battlefield click selects squad")
	if game.selection.selected_unit() != unit: finish(); return
	check(game.hud.sidebar.visible and game.hud.selected_info.text.contains("Health") and game.hud.selected_info.text.contains("Armor"), "Unit card teaches approachable stats")
	check(game.assistance.move_button.is_visible_in_tree(), "Move action visible in dock")
	check(not game.hud.advanced_box.visible, "Advanced tools hidden")
	check(game.guidance.labels[unit].text.contains("YOU"), "World banner states ownership with text")
	await capture("user://guided_selected.png")
	game.assistance.move_button.pressed.emit()
	await settle()
	check(not game.assistance.formation_choice.visible, "Automatic formation choices hidden normally")
	check(game.interaction.move_preview.soft_area != null, "Movement guide has projected area")
	click_world(Vector3(-10, 0, 3.5))
	await settle()
	check(game.interaction.last_formation.get("ok", false), "Destination click generates legal squad")
	check(not game.hud.confirm_move.disabled, "Legal preview enables confirmation")
	await capture("user://guided_move.png")
	game.hud.confirm_move.pressed.emit()
	await settle()
	check(game.interaction.session == null and int(game.assistance.state(unit).get("moved", 0)) > 0, "Move confirms and marks squad automatically")
	check(game.hud.continue_button.text == "Continue to Shooting", "Continuation names next activity")
	await advance()
	check(game.manager.phase == 2, "Continue button enters Shooting")
	game.assistance.attack_button.pressed.emit()
	game.assistance.choose_target(enemy)
	await settle()
	check(not game.assistance.available.is_empty(), "Clear first shooting lane offers a valid attack")
	check(enemy.models[0].target_candidate, "Valid enemies visibly marked")
	check(game.guidance.why_button.is_visible_in_tree(), "Why explanation is discoverable")
	game.guidance.why_button.pressed.emit()
	check(game.guidance.why_text.visible and game.guidance.why_text.text.contains("Why:"), "Why reveals range/visibility/calculation details")
	game.guidance.why_button.pressed.emit()
	await capture("user://guided_attack.png")
	game.dice.rng.seed = 42
	game.assistance.commit_button.pressed.emit()
	await settle()
	check(game.combat.current != null and not game.combat.current.result.hit_rolls.is_empty(), "One confirmation produces canonical exact dice")
	if game.combat.current == null: finish(); return
	check(CombatPresentation.plain_result(game.combat.current.result).contains("got through its armor"), "Result explains attack without tabletop jargon")
	await capture("user://guided_result.png")
	while game.combat.current.remaining > 0:
		var recipient := AttackOptions.suggested(game.combat.current)
		if recipient == null: check(false, "Damage has a valid recipient"); break
		var before: int = game.combat.current.remaining
		click_world(recipient.global_position + Vector3.UP * .1)
		await settle()
		check(game.combat.current.remaining < before, "Battlefield click gives damage through canonical allocation")
		if game.combat.current.remaining >= before: check(false, "Damage allocation makes progress"); break
	game.hud.combat_panel.continue_batch()
	await settle()
	check(game.combat.current.remaining == 0, "Damage arithmetic handled")
	for i in 10:
		if game.manager.round_number > 1: break
		await advance()
	check(game.manager.round_number == 2, "Player can finish full round with continuation buttons")
	check(int(game.manager.scores["0"]) > 0, "Nearby objective scores automatically")
	check(game.guidance.round_card.visible and game.guidance.round_text.text.contains("You control"), "Round summary explains objectives and score")
	await capture("user://guided_score.png")
	var state := WorldState.capture(game)
	check(SaveService.save_game(game, game.manager, game.battle_log, game.combat, "user://guided_smoke.json").begins_with("Saved"), "UX still saves")
	check(SaveService.load_game(game, game.manager, game.battle_log, game.combat, "user://guided_smoke.json").begins_with("Loaded"), "UX still loads")
	check(WorldState.capture(game) == state, "Save/load preserves gameplay exactly")
	finish()

func finish() -> void:
	print("GRIMTABLE GUIDED SMOKE: %d checks / %d failures %s" % [checks, failures.size(), str(failures)])
	get_tree().quit(0 if failures.is_empty() else 1)

func run_damage(app: Node) -> void:
	# Focused graphical follow-up, without replaying the whole turn matrix.
	app.settings.autosave = false
	check(app.launch_scenario(ScenarioLibrary.read(ScenarioLibrary.BUILTINS[4])), "Packaged scenario starts")
	game = app.game
	get_window().size = Vector2i(1280, 800)
	game.manager.phase = 2
	game.manager.changed.emit()
	var unit: TableUnit = game.battlefield.units.get_child(0)
	var enemy: TableUnit = game.battlefield.units.get_child(3)
	game.selection.select_unit(unit)
	game.assistance.begin_attack()
	game.assistance.choose_target(enemy)
	game.dice.rng.seed = 42
	game.assistance.confirm_attack()
	await settle()
	game.camera_rig._update_camera(1)
	check(game.combat.current != null and game.combat.current.remaining > 0, "Damage decision visible")
	for model in enemy.living_models(): check(model.damage_recipient and model.caption.text.length() <= 5, "Per-model damage cue is a compact arrow/code")
	check(game.assistance.apply_button.get_global_rect().end.y < 660, "Damage confirmation fits minimum window height")
	await capture("user://guided_damage_compact.png")
	var before: int = game.combat.current.remaining
	click_world(enemy.models[0].global_position + Vector3.UP * .1)
	await settle()
	check(game.combat.current.remaining < before, "Compact marker keeps direct model allocation")
	while game.combat.current.remaining > 0: game.assistance.apply_suggestion()
	game.hud.combat_panel.continue_batch()
	await settle()
	game.manager.restore({"round": 2, "phase": 0, "team": 0, "scores": {"0": 1, "1": 0}})
	await settle()
	check(game.guidance.round_card.visible and not game.assistance.quick_card.visible, "Round summary replaces transient combat UI")
	check(not game.guidance.hint_card.visible, "Round summary is the sole guidance overlay")
	await capture("user://guided_round_compact.png")
	finish()
