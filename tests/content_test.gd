extends SceneTree

var checks := 0
var failures := 0
var game: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func frames() -> void:
	for i in 4: await process_frame
	await physics_frame
	await physics_frame

func run() -> void:
	check(ContentRegistry.validate().is_empty(), "All content definitions validate: " + str(ContentRegistry.validate()))
	check(ContentRegistry.catalog().factions.size() == 4, "Four original factions")
	check(ContentRegistry.catalog().units.size() == 16, "Sixteen unit archetypes")
	check(ContentRegistry.catalog().weapons.size() == 12, "Twelve reusable weapon definitions")
	check(not AppSettings.new().auto_allocate_damage and not AppSettings.new().auto_remove_defeated, "Tabletop automation defaults OFF")
	for pair in [[8, 4, 2], [5, 4, 3], [4, 4, 4], [3, 4, 5], [2, 4, 6], [1, 10, 6]]:
		check(AttackResolver.wound_target(pair[0], pair[1]) == pair[2], "Wound threshold " + str(pair))
	check(AttackResolver.modified_save_target(3, 1) == 4, "Positive AP worsens new saves")
	check(AttackResolver.modified_save_target(3, 9) == 7, "Impossible saves use 7+")
	check(AttackResolver.save_target(3, -1) == 4, "Legacy signed AP retained")
	for mm in [25, 32, 40, 50, 60, 80, 100]:
		check(is_equal_approx(ContentRegistry.base_radius({"base_mm": mm}) * 50.8, mm), "Millimeter base conversion " + str(mm))
	var broken := ContentRegistry.unit({"unit_id": "legion_trooper"})
	broken.weapons = ["unknown_weapon"]
	check(not ContentRegistry.profile_error(broken).is_empty(), "Missing weapon rejected")
	broken = ContentRegistry.unit({"unit_id": "legion_trooper"})
	broken.base_mm = -32
	check(not ContentRegistry.profile_error(broken).is_empty(), "Negative base rejected")
	broken.base_mm = 32
	broken.faction = "missing"
	check(not ContentRegistry.profile_error(broken).is_empty(), "Missing faction rejected")
	broken.faction = "legion"
	broken.movement = "six"
	check(not ContentRegistry.profile_error(broken).is_empty(), "Invalid numeric stat rejected")
	broken = ContentRegistry.unit({"unit_id": "legion_trooper"})
	broken.base_mm = []
	check(not ContentRegistry.profile_error(broken).is_empty(), "Malformed base type rejected without conversion crash")
	broken.base_mm = 32
	broken.weapons = 42
	check(not ContentRegistry.profile_error(broken).is_empty(), "Malformed loadout rejected without iteration crash")
	var manifest := NetworkCompatibility.manifest()
	check(NetworkCompatibility.error_for(manifest).is_empty(), "Matching content compatible")
	manifest.profiles["content"] = "different"
	check(not NetworkCompatibility.error_for(manifest).is_empty(), "Content catalog mismatch rejected")
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/third_party/assets.json"))
	for asset: Dictionary in registry.assets:
		if asset.status == "included":
			check(asset.license in ["CC0-1.0", "OFL-1.1"] and not str(asset.license_verified).is_empty() and asset.date_retrieved != null and asset.creator is String and asset.source.begins_with("https://"), "License provenance: " + asset.name)
	for id: String in ContentRegistry.catalog().models:
		var scene := load(ContentRegistry.catalog().models[id]) as PackedScene
		check(scene != null, "Reusable model scene: " + id)
		if scene != null:
			var instance := scene.instantiate()
			root.add_child(instance)
			check(instance.get_child_count() > 0, "Visual has geometry: " + id)
			instance.queue_free()
	# Load all imported GLBs, including material/texture dependencies.
	# docs are excluded from exports: audit source GLBs through their directories instead.
	for kit in ["space-station-kit", "modular-space-kit"]:
		var folder: String = "res://assets/third_party/kenney/terrain/" + kit + "/Models/GLB format/"
		for name in DirAccess.get_files_at(folder):
			if name.ends_with(".glb"): check(load(folder + name) is PackedScene, "Godot imports CC0 model: " + name)
	var source := ScenarioLibrary.read("res://resources/scenarios/legion_vs_swarm.json")
	check(source.has("data"), "Legion vs Swarm validates")
	check(ScenarioLibrary.read("res://resources/scenarios/horde_vs_synthetics.json").has("data"), "Horde vs Synthetics validates")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.scenario = source.data
	game.settings = AppSettings.new()
	game.settings.autosave = false
	root.add_child(game)
	await frames()
	var unit: TableUnit = game.battlefield.units.get_child(0)
	var target: TableUnit = game.battlefield.units.get_child(3)
	check(unit.models[0].visual_root.get_child_count() > 0, "Faction miniature renders reusable scene")
	check(is_equal_approx(unit.models[0].base_radius, 32.0 / 50.8), "Profile base drives geometry")
	check(unit.models[0].get_node("Collision").shape is CylinderShape3D, "Primitive picking collision")
	check(is_equal_approx(unit.models[0].eye().y, unit.definition.los_height), "Profile controls LOS independently of visual")
	check(game.interaction.pick(game.camera_rig.camera.unproject_position(unit.models[0].eye())) == unit.models[0], "Imported presentation retains primitive picking")
	game.selection.select_unit(unit)
	check(game.selection.models.size() == 5, "Select faction squad")
	game.interaction.set_mode(1)
	for model in unit.models:
		var start := model.global_position
		model.global_position += Vector3(0, 0, 0.5)
		game.interaction.session.stage(model, start)
	check(game.interaction.confirm_unit_move(), "Faction squad move confirms")
	check(CoherencyService.is_unit_coherent(unit), "Faction coherency retained")
	check(game.interaction.auto_arrange(), "Nearby legal auto-arrange proposal")
	check(game.interaction.confirm_unit_move(), "Auto-arrange still requires confirmation")
	var captured := ScenarioFactory.capture(game)
	check(captured.armies[0].unit_id == "legion_trooper" and captured.armies[0].models[0].has("cosmetic_id"), "Editor capture preserves profile/cosmetic IDs")
	# Fixture changes use a scenario, so replay reconstructs the actual starting positions.
	var data: Dictionary = source.data.duplicate(true)
	data.terrain = []
	data.objectives[0].position = [-10, 0, 6]
	for army: Dictionary in data.armies:
		for model: Dictionary in army.models:
			model.position[2] = 6 if army.team == 0 else -6
	game.apply_scenario(data)
	await frames()
	unit = game.battlefield.units.get_child(0)
	target = game.battlefield.units.get_child(3)
	var weapon: Dictionary = unit.weapon_profiles[0]
	var preview := AttackResolver.preview(unit, target, game.get_world_3d(), weapon)
	check(preview.eligible == 5 and preview.attacks == 10, "Five models x two attacks = ten")
	var old := unit.models[0].global_position
	unit.models[0].global_position.z = 30
	check(AttackResolver.preview(unit, target, game.get_world_3d(), weapon).attacks == 8, "Out-of-range model excluded")
	unit.models[0].global_position = old
	var blocker := TerrainPiece.new()
	blocker.size = Vector3(50, 6, 1)
	game.battlefield.terrain.add_child(blocker)
	await frames()
	check(AttackResolver.preview(unit, target, game.get_world_3d(), weapon).eligible == 0, "Per-model LOS rejects blocked shooters")
	blocker.queue_free()
	await frames()
	var melee: Dictionary = unit.weapon_profiles[1]
	check(AttackResolver.preview(unit, target, game.get_world_3d(), melee).attacks == 0, "Melee range is enforced")
	game.interaction.set_mode(3)
	game.selection.select_unit(unit)
	game.interaction.target_model = target.models[0]
	game.hud.combat_panel.show()
	game.hud.combat_panel.update_preview()
	check(game.hud.combat_panel.eligibility.text.contains("10 dice"), "Attack UI shows exact preview count")
	game.hud.combat_panel.weapon_choice.select(1)
	game.hud.combat_panel.update_preview()
	check(game.hud.combat_panel.eligibility.text.contains("0 dice"), "Weapon selector recalculates melee eligibility")
	game.hud.combat_panel.weapon_choice.select(0)
	game.hud.combat_panel.update_preview()
	game.dice.rng.seed = 42
	game.hud.combat_panel._resolve()
	check(game.hud.combat_panel.confirmation.visible, "Attack opens explicit confirmation")
	game.hud.combat_panel.confirmation.confirmed.emit()
	game.hud.combat_panel.confirmation.hide()
	check(game.combat.current != null, "Confirmed profile attack resolves")
	var result: Dictionary = game.combat.current.result
	check(result.hit_rolls.size() == 10 and result.wound_rolls.size() == result.hits and result.save_rolls.size() == result.wounds, "Exact dice in all stages")
	check(result.save_target == 7 and result.wound_target == 3, "Defense and positive AP used")
	check(result.damage == result.failed_saves * weapon.damage, "Fixed damage calculated transparently")
	check(CombatPanel.describe(result).contains(str(result.hit_rolls)), "UI displays exact dice")
	check(target.models[0].wounds == 1, "Damage remains manual by default")
	check(game.combat.allocate(target.models[0], 1), "Manual allocation works")
	check(target.models[0].wounds == 0 and not target.models[0].removed, "Defeated stays on table by default")
	check(game.combat.remove_casualty(target.models[0]), "Explicit casualty removal")
	var objective: TableObjective = game.battlefield.objectives.get_child(0)
	var objective_start := objective.global_position
	objective.global_position = unit.models[0].global_position
	var control := ObjectiveControl.evaluate(objective, game.battlefield.units.get_children())
	check(control.owner == 0 and int(control.counts["0"]) > 0, "Objective counts living bases by team")
	objective.global_position = objective_start
	# Reach second team's End phase through ordinary phase events.
	for i in 11: game.manager.next_phase()
	check(game.manager.phase == 5 and game.manager.active_team == 1 and game.manager.scored_rounds.has(1), "End phase records once-per-round scoring")
	check(int(game.manager.scores["0"]) > 0, "Controlled objectives award scenario points")
	var scores: Dictionary = game.manager.scores.duplicate()
	game.manager.previous_phase()
	game.manager.next_phase()
	check(game.manager.scores == scores, "Phase rewind cannot farm points")
	var final := WorldState.capture(game)
	var events: Array = JSON.parse_string(JSON.stringify(game.battle_log.entries, "", true, true))
	var initial: Dictionary = game.initial_scenario.duplicate(true)
	check(ActionCodec.validate(events, initial).is_empty(), "New combat and scoring history validates")
	check(SaveService.save_game(game, game.manager, game.battle_log, game.combat, "user://content_smoke.json").begins_with("Saved"), "Save faction match")
	check(SaveService.load_game(game, game.manager, game.battle_log, game.combat, "user://content_smoke.json").begins_with("Loaded"), "Load faction match")
	check(WorldState.capture(game) == final, "Save/load preserves models, wounds, scores and dice")
	check(game.initial_scenario.armies[0].profile_snapshot.weapon_snapshots.size() == 2, "Replay embeds gameplay loadout snapshot")
	var replay := ReplayController.new()
	replay.game = game
	game.add_child(replay)
	check(replay.open({"initial_scenario": initial, "events": events}).is_empty(), "Open new faction replay")
	replay.seek(events.size())
	check(WorldState.capture(game) == final, "Replay exactly reproduces faction combat and scoring")
	check(game.combat.current.result.hit_rolls == result.hit_rolls, "Replay never rerolls dice")
	game.replay_mode = false
	game.interaction.read_only = false
	game.apply_scenario(data)
	await frames()
	unit = game.battlefield.units.get_child(0)
	target = game.battlefield.units.get_child(4)
	game.selection.select(target.models[1])
	game.hud._wounds(-1)
	game.settings.auto_allocate_damage = true
	game.settings.auto_remove_defeated = true
	game.dice.rng.seed = 42
	check(game.combat.resolve(unit, target, game.get_world_3d()), "Opt-in automatic allocation resolves")
	check(target.models[1].wounds == 0 and target.models[1].removed, "Wounded recipient chosen first and auto-removed")
	check(target.models[0].wounds <= target.models[0].max_wounds, "Auto-allocation remains within health limits")
	var bad_request := {"command": "attack", "args": {"attacker": str(unit.name), "target": str(target.name), "weapon_index": 500}, "sequence": game.battle_log.sequence}
	check(not NetworkAuthority.validate_request(game, bad_request, 0, WorldState.capture(game)).is_empty(), "Host rejects unowned loadout index")
	bad_request.args.weapon_index = 0
	check(not NetworkAuthority.validate_request(game, bad_request, 1, WorldState.capture(game)).is_empty(), "Host rejects enemy ownership")
	# A replay must retain old gameplay definitions after the catalog changes.
	var frozen := ContentRegistry.freeze(data)
	frozen.armies[0].profile_snapshot.movement = 4.25
	check(ContentRegistry.unit(frozen.armies[0]).movement == 4.25, "Embedded profile supersedes installed stats")
	var bad_scenario := data.duplicate(true)
	bad_scenario.armies[0].unit_id = "unknown"
	check(not ScenarioDefinition.validate(bad_scenario).is_empty(), "Invalid scenario unit reference rejected")
	game.settings.auto_allocate_damage = false
	game.settings.auto_remove_defeated = false
	objective = game.battlefield.objectives.get_child(0)
	for squad: TableUnit in game.battlefield.units.get_children():
		for model in squad.models: model.global_position = Vector3(25, 0, 20)
	unit.models[0].global_position = objective.global_position
	target.models[0].global_position = objective.global_position
	check(ObjectiveControl.evaluate(objective, game.battlefield.units.get_children()).owner == -1, "Equal nearby living models contest objective")
	target.models[0].wounds = 0
	check(ObjectiveControl.evaluate(objective, game.battlefield.units.get_children()).owner == 0, "Defeated model excluded from objective control")
	game.apply_scenario(data)
	await frames()
	# Missing visuals preserve gameplay and picking.
	var fallback := Miniature.new()
	fallback.model_id = "missing_visual_test"
	fallback.profile = {"id": "missing_visual_test", "model_scene": "res://missing.glb"}
	root.add_child(fallback)
	check(fallback.get_node("Collision") != null and fallback.get_child_count() > 5, "Missing asset uses playable fallback")
	fallback.queue_free()
	if "--render-content" in OS.get_cmdline_user_args():
		game.replay_mode = false
		game.hud.show()
		game.hud.combat_panel.show()
		game.selection.select_unit(game.battlefield.units.get_child(0))
		game.interaction.target_model = game.battlefield.units.get_child(3).models[1]
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/content_smoke.png")
	game.queue_free()
	await process_frame
	print("GRIMTABLE CONTENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
