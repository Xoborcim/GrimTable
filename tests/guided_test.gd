extends SceneTree

var checks := 0
var failures := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL: " + message)

func settle() -> void:
	for i in 4: await process_frame
	await physics_frame

func run() -> void:
	var settings := AppSettings.new()
	check(settings.assistance == "Guided", "First launch Guided")
	settings.apply_assistance_preset("Standard")
	check(settings.assistance == "Standard" and settings.quick_movement and settings.combat_resolution == "Fast", "Standard has automation without tutorial mode")
	settings.apply_assistance_preset("Tabletop")
	check(not settings.quick_movement and settings.combat_resolution == "Detailed", "Tabletop preserves manual positioning and detailed rolls")
	settings.apply_assistance_preset("Assisted")
	check(settings.assistance == "Standard", "Old Assisted preset alias migrates")
	settings.gameplay_hints = {"welcome": true}
	settings.save_settings()
	var restored := AppSettings.new()
	restored.load_settings()
	check(restored.gameplay_hints.get("welcome", false), "Dismissed hints persist")
	var config := ConfigFile.new()
	config.set_value("experience", "assistance", "Assisted")
	config.save(AppSettings.PATH)
	restored.load_settings()
	check(restored.assistance == "Standard", "Existing settings migrate without new-player hints")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new()
	game.settings.autosave = false
	game.settings.camera_assistance = false
	game.scenario = ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json").data
	root.add_child(game)
	await settle()
	var guide: GuidedExperience = game.guidance
	check(game.manager.phase == 1 and guide.steps.size() == 5, "Showcase starts at first visible turn step")
	check(not game.hud.sidebar.visible and game.hud.next_action_button.visible, "Empty state has next-squad action without large sidebar")
	check(guide.hint_title.text == "Your turn", "First contextual hint explains ownership")
	guide.dismiss_hint()
	await settle()
	check(guide.hint_title.text == "Objectives win points", "Objective explanation follows once")
	guide.dismiss_hint()
	await settle()
	check(guide.hint_title.text == "Look around", "Camera explanation is dismissible")
	guide.dismiss_hint()
	await settle()
	check(not guide.hint_card.visible, "Acknowledged hints disappear")
	game.settings.apply_assistance_preset("Standard")
	game.settings.gameplay_hints = {}
	guide.refresh()
	check(not guide.hint_card.visible, "Standard omits tutorial hints")
	game.settings.apply_assistance_preset("Guided")
	var unit: TableUnit = game.battlefield.units.get_child(0)
	game.selection.select_unit(unit)
	await settle()
	check(game.hud.sidebar.visible and game.hud.sidebar.offset_bottom < 500, "Selection expands compact unit card")
	check(game.hud.selected_info.text.contains("Health") and game.hud.selected_info.text.contains("Armor"), "Friendly stat names")
	check(game.assistance.move_button.get_parent().get_parent() == game.hud.action_row, "Primary actions exist only in dock")
	check(not game.hud.next_action_button.visible, "Selected ready squad has primary move rather than duplicate next")
	check(guide.labels[unit].text.contains("YOU"), "Ownership has text cue")
	check(unit.models[0].phase_ready, "Ready unit base cue")
	game.assistance.begin_move()
	await settle()
	check(not game.assistance.formation_choice.visible, "Automatic formation is default without extra menu")
	check(game.hud.confirm_move.disabled, "No destination cannot be confirmed as a move")
	check(game.interaction.preview_destination(Vector3(-10, 0, 3.5)), "Obvious first move fits")
	await settle()
	check(game.interaction.session.validation_error().is_empty(), "Quick formation obeys existing geometry and coherency")
	game.interaction.cancel()
	# Thin obstacle makes exact placement fail while a bounded nearby offset fits.
	var obstacle := TerrainPiece.new()
	obstacle.object_id = "test_obstruction"
	obstacle.name = obstacle.object_id
	obstacle.title = "Practice wall"
	obstacle.size = Vector3(7, 1, .2)
	obstacle.position = Vector3(-10, 0, 4)
	game.battlefield.terrain.add_child(obstacle)
	game.assistance.begin_move()
	check(game.interaction.preview_destination(Vector3(-10, 0, 4)), "Blocked destination gets automatic nearby alternative")
	check(game.interaction.last_formation.adjusted, "Alternative explicitly identified")
	check(game.interaction.session.validation_error().is_empty(), "Alternative remains legal")
	check(FormationPlanner.center(unit.living_models()).distance_to(Vector3(-10, 0, 4)) <= 3.001, "Search is bounded local geometry, not tactical relocation")
	game.interaction.cancel()
	game.assistance.begin_move()
	check(not game.interaction.preview_destination(Vector3(-10, 0, -19)), "Impossible move rejected")
	await settle()
	check(game.hud.confirm_move.disabled, "Failed preview cannot commit origin as successful move")
	check(game.assistance.formation_choice.visible, "Failure exposes manual escape route")
	check(not game.interaction.last_formation.ghosts.is_empty(), "Failed placement retains destination ghosts")
	check(game.interaction.move_preview.failure.get_child_count() > 0, "Failed placement has visible markers")
	game.interaction.cancel()
	obstacle.queue_free()
	await settle()
	game.manager.phase = 2
	game.manager.changed.emit()
	await settle()
	check(guide.steps[0].text.begins_with("✓") and guide.steps[1].text.begins_with("➜"), "Completed/current phases use symbols and color")
	check(game.hud.continue_button.text == "Continue to Charge", "Continuation explains destination")
	game.assistance.begin_attack()
	var enemy: TableUnit = game.battlefield.units.get_child(3)
	game.assistance.choose_target(enemy)
	await settle()
	check(enemy.models[0].target_candidate and not enemy.models[0].target_hint.is_empty(), "Target marking provides explanation")
	check(guide.why_button.visible, "Explicit Why control")
	guide.why_button.pressed.emit()
	check(guide.why_text.visible and guide.why_text.text.contains("Why:"), "Why reveals calculation details")
	var objective: TableObjective = game.battlefield.objectives.get_child(0)
	objective.present({"owner": -1, "counts": {"0": 2, "1": 2}}, 0)
	check(objective.marker_label.text.contains("Contested"), "Contested objective has text status")
	objective.present({"owner": 0, "counts": {"0": 2, "1": 0}}, 0)
	check(objective.marker_label.text.contains("YOUR TEAM"), "Controlled objective explains ownership")
	game.manager.scores = {"0": 2, "1": 1}
	game.manager.round_number = 2
	game.manager.changed.emit()
	await settle()
	check(guide.round_card.visible and guide.round_text.text.contains("You control"), "Round summary explains points")
	check(not guide.hint_card.visible, "Round summary immediately replaces tutorial hint")
	check(game.hud.turn_label.text.contains("You  2") and game.hud.turn_label.text.contains("1  Enemy"), "Score is always top-level")
	game.queue_free()
	await process_frame
	print("GRIMTABLE GUIDED: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
