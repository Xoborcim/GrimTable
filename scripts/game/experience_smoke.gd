class_name ExperienceSmoke
extends Node

var failures: Array[String] = []
var checks := 0

func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures.append(description)

func run(app: Node) -> void:
	# Opt-in package verification, never runs in normal sessions.
	check(app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json")), "Showcase starts")
	var game: Node3D = app.game
	game.settings.autosave = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(game.get_node_or_null("TableEnvironment") != null, "Environment loads")
	check(game.battlefield.units.get_child_count() == 6, "Built-in content loads")
	var unit: TableUnit = game.battlefield.units.get_child(0)
	var enemy: TableUnit = game.battlefield.units.get_child(3)
	check(unit.models[0].visual_root.get_child_count() == 1, "Authored art loads")
	game.manager.phase = 1
	game.selection.select_unit(unit)
	game.interaction.begin_unit_move()
	for model in unit.models:
		var before: Vector3 = model.global_position
		model.global_position += Vector3(0, 0, -.5)
		game.interaction.session.stage(model, before)
	check(game.interaction.confirm_unit_move(), "Move confirms")
	check(CoherencyService.is_unit_coherent(unit), "Coherency preserved")
	check(int(PhaseAssistant.states(game.battle_log, 1).get(str(unit.name), {}).get("moved", 0)) == 1, "Move tracked")
	game.manager.phase = 2
	game.interaction.target_model = enemy.models[0]
	game.hud.combat_panel.show()
	game.hud.combat_panel.update_preview()
	game.dice.rng.seed = 42
	check(game.combat.resolve(unit, enemy, game.get_world_3d()), "Ranged attack resolves")
	if game.combat.current != null:
		check(game.combat.current.result.hit_rolls.size() == game.combat.current.result.attacks, "Exact canonical dice shown")
		game.combat.discard_pending()
	# Exercise melee using an open adjacent lane. Manual setup repositioning is
	# test-only, while the attack still uses the same authoritative rules path.
	for i in unit.models.size(): unit.models[i].global_position = Vector3(-3 + i * 1.5, 0, 16)
	for i in enemy.models.size(): enemy.models[i].global_position = Vector3(-3 + i * 1.5, 0, 14)
	await get_tree().physics_frame
	await get_tree().physics_frame
	game.manager.phase = 4
	check(game.combat.resolve(unit, enemy, game.get_world_3d(), 1), "Melee uses shared attack flow")
	game.combat.discard_pending()
	game.manager.active_team = 1
	game.manager.phase = 4
	game.manager.next_phase()
	check(game.manager.scored_rounds.has(1), "End phase scoring recorded once")
	var before := WorldState.capture(game)
	check(SaveService.save_game(game, game.manager, game.battle_log, game.combat, "user://experience_smoke.json").begins_with("Saved"), "Save succeeds")
	check(SaveService.load_game(game, game.manager, game.battle_log, game.combat, "user://experience_smoke.json").begins_with("Loaded"), "Load succeeds")
	check(NetworkSession.state_hash(before) == NetworkSession.state_hash(WorldState.capture(game)), "Load preserves complete canonical state")
	for i in 40: await get_tree().process_frame
	check(game.hud.combat_panel.get_global_rect().end.y <= get_viewport().get_visible_rect().size.y - 100, "Combat controls stay inside HUD bounds")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://experience_packaged.png")
	print("GRIMTABLE 0.6 PACKAGE: %d checks / %d failures %s" % [checks, failures.size(), str(failures)])
	get_tree().quit(0 if failures.is_empty() else 1)
