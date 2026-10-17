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

func run() -> void:
	root.size = Vector2i(1440, 900)
	var demo := ScenarioLibrary.read(ScenarioLibrary.BUILTINS[0])
	var empty := ScenarioLibrary.read(ScenarioLibrary.BUILTINS[1])
	check(demo.has("data") and empty.has("data"), "Bundled demo and empty scenarios deserialize")
	check(demo.data.terrain.size() == 12 and demo.data.armies.size() == 2, "Demo setup migrated entirely to data")
	check(ScenarioDefinition.validate(JSON.parse_string(JSON.stringify(demo.data))).is_empty(), "Scenario serialization round trip")
	var invalid: Dictionary = demo.data.duplicate(true)
	invalid.board.width = "oops"
	check(not ScenarioDefinition.validate(invalid).is_empty(), "Malformed board dimensions rejected")
	invalid = demo.data.duplicate(true)
	invalid.armies[0].profile = "C:/not-portable.json"
	check(not ScenarioDefinition.validate(invalid).is_empty(), "Absolute asset paths rejected")
	invalid.armies[0].profile = "res://resources/units/missing.json"
	check(ScenarioDefinition.validate(invalid).contains("Missing"), "Missing profile produces recoverable error")
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	main.scenario = empty.data.duplicate(true)
	main.settings = AppSettings.new()
	main.settings.autosave = false
	root.add_child(main)
	await process_frame
	var editor := ScenarioEditor.new()
	editor.game = main
	main.add_child(editor)
	var data: Dictionary = editor.document.duplicate(true)
	data.board = {"width": 80, "depth": 60}
	check(editor.commit(data), "Editor can resize board")
	check(main.battlefield.contains_base(Vector3(35, 0, 0), 1), "Gameplay bounds use scenario dimensions")
	editor.terrain_index = 1
	editor.angle = 90
	editor.set_tool(1)
	check(editor.place(Vector3(-16, 0, 0)), "Terrain palette places ruin")
	check(editor.preview.get_child_count() == 2, "Ruin preview uses translucent reusable primitives")
	editor.set_tool(2)
	check(editor.place(Vector3.ZERO), "Editor places objective")
	editor.profile_index = 1
	editor.unit_count = 3
	editor.team = 1
	editor.set_tool(3)
	check(editor.place(Vector3(10, 0, 8)), "Editor places full generic unit")
	editor.set_tool(4)
	check(editor.place(Vector3(25, 0, -12)), "Editor creates rectangle zone")
	data = ScenarioFactory.capture(main)
	data.terrain[0].blocks_los = false
	data.terrain[0].rotation = 45
	data.objectives[0].name = "Control Point"
	data.objectives[0].number = 8
	data.objectives[0].radius = 5
	data.deployment_zones[2].size = [15, 6]
	data.armies[0].team = 0
	check(editor.commit(data), "Editor properties apply for terrain/objective/zone/team")
	var path := ScenarioLibrary.DIRECTORY + "validation_scenario.json"
	editor.path = path
	var saved := editor.save_scenario()
	check(saved.begins_with("Saved"), "Custom scenario saves separately from game saves")
	var loaded := ScenarioLibrary.read(path)
	check(loaded.has("data"), "Saved custom scenario deserializes")
	check(is_equal_approx(float(loaded.data.terrain[0].rotation), 45) and loaded.data.terrain[0].blocks_los == false, "Terrain rotation and blocker properties persist")
	check(loaded.data.objectives[0].radius == 5 and loaded.data.objectives[0].number == 8 and loaded.data.objectives[0].name == "Control Point", "Objective configuration persists")
	check(is_equal_approx(float(loaded.data.deployment_zones[2].size[0]), 15) and is_equal_approx(float(loaded.data.deployment_zones[2].size[1]), 6), "Zone dimensions persist")
	check(loaded.data.armies[0].team == 0 and loaded.data.armies[0].models.size() == 3, "Unit roster and ownership persist")
	check(ScenarioLibrary.list_scenarios().any(func(item: Dictionary): return item.get("path") == path), "Custom scenarios appear in browser catalog")
	editor.selected_kind = "terrain"
	editor.selected_id = data.terrain[0].id
	editor.delete_selected()
	check(main.battlefield.terrain.get_child_count() == 0, "Editor deletes selected terrain")
	DirAccess.remove_absolute(path)
	main.remove_child(editor)
	editor.queue_free()
	main.interaction.editor = null
	main.editing = false
	# A legal game fixture: every state change below uses actual actions.
	data = demo.data.duplicate(true)
	data.terrain = [data.terrain[0]]
	data.terrain[0].position = [22, 0, 0]
	data.terrain[0].size = [3, 3, 3]
	data.starting_state.deployment = false
	for t in 2:
		for i in 5: data.armies[t].models[i].position = [-6 + i * 3, 0, 5 if t == 0 else -5]
	main.apply_scenario(data)
	var units: Array = main.battlefield.units.get_children()
	var source := units[0] as TableUnit
	var target := units[1] as TableUnit
	main.selection.select_unit(source)
	main.interaction.set_mode(1)
	for model in source.models:
		var origin := model.global_position
		model.global_position += Vector3(0, 0, 1)
		main.interaction.session.stage(model, origin)
	check(main.interaction.confirm_unit_move(), "Recorded legal squad movement")
	main.selection.select(target.models[0])
	main.hud._wounds(-1)
	await physics_frame
	await physics_frame
	main.dice.rng.seed = 42
	check(main.combat.resolve(source, target, main.get_world_3d()), "Recorded generic attack resolves")
	var recorded_rolls: Array = main.combat.current.result.hit_rolls.duplicate()
	check(main.combat.allocate(target.models[0], 1), "Recorded manual damage")
	check(main.combat.remove_casualty(target.models[0]), "Recorded casualty removal")
	var objective := main.battlefield.objectives.get_child(0) as TableObjective
	var start := objective.global_position
	objective.global_position += Vector3(1, 0, 0)
	main.interaction.record_move(objective, start, "Move objective")
	main.manager.next_phase()
	main.undo_action()
	main.redo_action()
	var final_state := WorldState.capture(main)
	var events: Array = JSON.parse_string(JSON.stringify(main.battle_log.entries))
	var initial: Dictionary = main.initial_scenario.duplicate(true)
	check(ActionCodec.validate(events, initial).is_empty(), "Serialized action deltas validate")
	var actions: Array = events.filter(func(event: Dictionary): return event.kind == "execute")
	check(actions[0].payload.has("actor") and actions[0].payload.has("affected_objects"), "Structured action actor/object identifiers")
	var save_path := "user://validation_game.json"
	check(SaveService.save_game(main, main.manager, main.battle_log, main.combat, save_path).begins_with("Saved"), "Versioned game save writes")
	var save_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(save_data.format_version == 2 and save_data.initial_scenario.id == initial.id, "Save explicitly versions scenario and current state")
	var bad_version := save_data.duplicate(true)
	bad_version.format_version = 999
	check(not SaveService.validate_document(bad_version).is_empty(), "Incompatible save version rejected")
	var replay := ReplayController.new()
	replay.game = main
	main.add_child(replay)
	check(replay.open({"initial_scenario": initial, "events": events}).is_empty(), "Replay opens structured history")
	replay.seek(events.size())
	var replayed := WorldState.capture(main)
	check(replayed.models == final_state.models, "Replay reproduces movement, wounds, casualties")
	check(replayed.objectives == final_state.objectives, "Replay reproduces objective movement including undo/redo")
	check(replayed.turn == final_state.turn, "Replay reproduces phase/player changes")
	check(main.combat.current.result.hit_rolls == recorded_rolls, "Replay uses identical recorded dice")
	check(replayed.combat == final_state.combat, "Replay restores pending damage and combat state exactly")
	replay.seek(0)
	check(main.battlefield.units.get_child(1).models[0].wounds == 2 and not main.battlefield.units.get_child(1).models[0].removed, "Seeking zero reconstructs original scenario")
	for i in events.size(): replay.step_forward(false)
	check(WorldState.capture(main) == final_state, "Stepped replay matches original complete state")
	replay.seek(3)
	replay.seek(events.size())
	check(WorldState.capture(main) == final_state, "Timeline jumping is deterministic")
	var corrupt := events.duplicate(true)
	corrupt[0].payload.changes[0].property = "script"
	check(not ActionCodec.validate(corrupt, initial).is_empty(), "Corrupt replay cannot set arbitrary object properties")
	main.replay_mode = false
	main.interaction.read_only = false
	check(SaveService.load_game(main, main.manager, main.battle_log, main.combat, save_path).begins_with("Loaded"), "Versioned save loads")
	check(WorldState.capture(main) == final_state, "Save/load restores exact current state")
	DirAccess.remove_absolute(save_path)
	main.apply_scenario(demo.data)
	var legacy := WorldState.capture(main)
	legacy["version"] = 1
	legacy["battle_log"] = []
	var legacy_file := FileAccess.open("user://validation_legacy.json", FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	main.apply_scenario(empty.data)
	check(SaveService.load_game(main, main.manager, main.battle_log, main.combat, "user://validation_legacy.json").begins_with("Loaded") and main.battlefield.units.get_child_count() == 2, "Legacy saves restore the original demo from any current scenario")
	SaveService.save_game(main, main.manager, main.battle_log, main.combat, save_path)
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(SaveService.validate_document(migrated).is_empty() and not migrated.replay_supported, "Legacy game can migrate to a loadable versioned save")
	check(ReplayController.read(save_path).has("error"), "Incomplete legacy history gives a clear replay error")
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute("user://validation_legacy.json")
	var config := AppSettings.new()
	config.precision = 3
	config.autosave = false
	check(config.save_settings().begins_with("Settings"), "Settings persist locally")
	var restored := AppSettings.new()
	restored.load_settings()
	check(restored.precision == 3 and not restored.autosave, "Settings load without external services")
	print("GRIMTABLE SCENARIOS/REPLAY: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
