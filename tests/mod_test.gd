extends SceneTree

var checks := 0
var failures := 0
const PACK := "user://mods/grimtable_mod_test"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + reason)

func copy_folder(source: String, target: String) -> void:
	DirAccess.make_dir_recursive_absolute(target)
	for name in DirAccess.get_directories_at(source): copy_folder(source + "/" + name, target + "/" + name)
	for name in DirAccess.get_files_at(source): DirAccess.copy_absolute(source + "/" + name, target + "/" + name)

func write(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func cleanup(path: String = PACK) -> void:
	if not path.begins_with(PACK): return
	for name in DirAccess.get_directories_at(path): cleanup(path + "/" + name)
	for name in DirAccess.get_files_at(path): DirAccess.remove_absolute(path + "/" + name)
	DirAccess.remove_absolute(path)

func run() -> void:
	check(not DirAccess.dir_exists_absolute(PACK), "Test pack path is unused")
	if DirAccess.dir_exists_absolute(PACK): quit(1); return
	copy_folder("res://examples/mods/example_army", PACK)
	ModLoader.set_enabled("example_army", true)
	ContentRegistry.reload_content()
	check(ModLoader.loaded.has("example_army"), "Valid self-contained external mod loads: " + str(ModLoader.entries))
	if not ModLoader.loaded.has("example_army"): cleanup(); quit(1); return
	check(ContentRegistry.catalog().units.has("example_army:infantry"), "Namespaced unit registered")
	check(ContentRegistry.catalog().factions.has("example_army:expedition"), "Namespaced faction registered")
	check(ContentRegistry.catalog().weapons.has("example_army:cannon"), "Namespaced weapon registered")
	check(ContentRegistry.path_for("grimtable:legion_trooper") == ContentRegistry.path_for("legion_trooper"), "Built-in alias preserves old IDs")
	check(ContentRegistry.validate().is_empty(), "Combined registry validates")
	check(ScenarioEditor.profile_palette().has(PACK + "/units/infantry.json"), "Editor palette sees modded units")
	check(ScenarioLibrary.list_scenarios().any(func(item: Dictionary): return item.get("path") == PACK + "/scenarios/outpost.json"), "Browser discovers mod scenario")
	for path in ["../outside", "models/../../secret", "/absolute", "C:/windows/file", "models\\evil.glb", "models/file.gd:stream", "models/./unit.glb"]:
		check(ModLoader.safe_path(PACK, path).is_empty(), "Traversal/unsafe path rejected: " + path)
	check(not ModLoader.safe_path(PACK, "models/infantry.glb").is_empty(), "Contained GLB path accepted")
	check(not ModLoader.manifest_error({}).is_empty(), "Manifest required fields are enforced")
	check(ModLoader.safe_path(PACK, "models/CON.png").is_empty(), "Windows device filename rejected")
	check(not SafeModVisual.check_node(0, [{"children": [0]}], {}, {}).is_empty(), "Cyclic model graph rejected before native loading")
	check(not ModLoader.supports(">=99.0.0") and not ModLoader.supports("*") and ModLoader.supports(">=0.4.0"), "Bounded version requirements validated")
	check(not ModLoader.own_id("example_army:infantry", "other"), "Foreign namespace rejected")
	check(not SafeModVisual.check_value({"images": [{"uri": "../../secret.png"}]}).is_empty(), "External GLB texture URI rejected")
	check(not SafeModVisual.check_value({"extras": {"script": "evil.gd"}}).is_empty(), "Script metadata rejected")
	check(not SafeModVisual.check_value({"extensionsUsed": ["custom"]}).is_empty(), "Custom GLB extensions rejected")
	DirAccess.make_dir_recursive_absolute(PACK + "/models")
	DirAccess.copy_absolute("res://tests/fixtures/mod_triangle.glb", PACK + "/models/scout.glb")
	check(SafeModVisual.validate_glb(PACK + "/models/scout.glb").is_empty(), "Bounded embedded GLB validates")
	var visual_unit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK + "/units/infantry.json"))
	visual_unit.visual = "models/scout.glb"
	write(PACK + "/units/infantry.json", visual_unit)
	ContentRegistry.reload_content()
	var external := SafeModVisual.instantiate(PACK + "/models/scout.glb")
	check(external != null and external.get_child_count() > 0, "External GLB loads at runtime without editor imports")
	if external != null: external.free()
	visual_unit.erase("visual")
	write(PACK + "/units/infantry.json", visual_unit)
	ContentRegistry.reload_content()
	var unit := ContentRegistry.unit({"unit_id": "example_army:infantry"})
	check(unit.max_wounds == 2 and ContentRegistry.weapons(unit)[0].id == "example_army:rifle", "Normalized stats and loadout")
	check(unit.model_scene.begins_with("res://assets/grimtable/models/"), "Only trusted fallback scenes are used")
	var manifest := NetworkCompatibility.manifest()
	check(NetworkCompatibility.error_for(manifest).is_empty(), "Matching mods accepted by compatibility gate")
	var changed := manifest.duplicate(true)
	changed.packs[0].version = "2.0.0"
	check(NetworkCompatibility.error_for(changed).contains("differs"), "Mod version mismatch rejected")
	changed = manifest.duplicate(true)
	changed.packs[0].gameplay_hash = "different"
	check(NetworkCompatibility.error_for(changed).contains("differs"), "Gameplay hash mismatch rejected")
	var scenario := ScenarioLibrary.read(PACK + "/scenarios/outpost.json")
	check(scenario.has("data"), "Sample scenario validates")
	var game: Node3D = load("res://scenes/main/main.tscn").instantiate()
	game.scenario = scenario.data
	game.settings = AppSettings.new()
	game.settings.autosave = false
	root.add_child(game)
	await process_frame
	check(game.battlefield.units.get_child(0).definition.id == "example_army:infantry", "Mod scenario starts actual tabletop")
	var frozen: Dictionary = game.initial_scenario.duplicate(true)
	check(frozen.required_content.size() == 1 and frozen.required_content[0].version == "1.0.0", "Initial scenario records required pack")
	check(SaveService.save_game(game, game.manager, game.battle_log, game.combat, "user://mod_test_save.json").begins_with("Saved"), "Mod save written")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://mod_test_save.json"))
	check(saved.required_content[0].id == "example_army", "Save required_content is explicit")
	check(SaveService.validate_document(saved).is_empty(), "Modded save validates while pack installed")
	game.queue_free()
	await process_frame
	# Every invalid update rolls back the entire pack, including its factions/weapons.
	var app: Node = load("res://scenes/main/app.tscn").instantiate()
	root.add_child(app)
	app.show_mods()
	check(app.game == null and app.column.get_child_count() >= 6, "Mods manager shows installed status and controls")
	app.settings.autosave = false
	app.launch_scenario(scenario)
	var active: Node = app.game
	app.reload_mods()
	check(app.game == active, "Reload is refused during an active battle")
	app.queue_free()
	await process_frame
	# A separate broken pack must leave the valid pack usable.
	var other := PACK + "_other"
	copy_folder("res://examples/mods/example_army", other)
	var other_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(other + "/manifest.json"))
	other_manifest.id = "other_army"
	write(other + "/manifest.json", other_manifest)
	write(other + "/units/infantry.json", [])
	ContentRegistry.reload_content()
	check(ModLoader.loaded.has("example_army") and not ModLoader.loaded.has("other_army"), "Broken pack isolated from healthy pack")
	other_manifest.dependencies = ["missing_pack"]
	write(other + "/manifest.json", other_manifest)
	ContentRegistry.reload_content()
	check(str(ModLoader.entries[1].error).contains("dependency"), "Missing dependency reports a clean error")
	other_manifest.id = "example_army"
	write(other + "/manifest.json", other_manifest)
	ContentRegistry.reload_content()
	check(not ModLoader.loaded.has("example_army") and str(ModLoader.entries[0].error).contains("Duplicate pack"), "Duplicate pack namespaces rejected without overriding")
	cleanup(other)
	ContentRegistry.reload_content()
	var original := FileAccess.get_file_as_string(PACK + "/units/infantry.json")
	write(PACK + "/units/duplicate.json", JSON.parse_string(original))
	ContentRegistry.reload_content()
	check(not ModLoader.loaded.has("example_army") and str(ModLoader.entries[0].error).contains("Duplicate"), "Duplicate IDs reject pack transactionally")
	check(not ContentRegistry.catalog().weapons.has("example_army:rifle"), "Failed pack leaves no partial registrations")
	DirAccess.remove_absolute(PACK + "/units/duplicate.json")
	var malformed: Dictionary = JSON.parse_string(original)
	malformed.visual = "../../evil.tscn"
	write(PACK + "/units/infantry.json", malformed)
	ContentRegistry.reload_content()
	check(not ModLoader.loaded.has("example_army"), "Traversal visual rejects pack")
	malformed.erase("visual")
	malformed.weapons = ["example_army:heavy_laser"]
	write(PACK + "/units/infantry.json", malformed)
	ContentRegistry.reload_content()
	check(str(ModLoader.entries[0].error).contains("weapon"), "Missing weapon error is clear")
	write(PACK + "/units/infantry.json", [])
	ContentRegistry.reload_content()
	check(not ModLoader.loaded.has("example_army") and ContentRegistry.catalog().units.size() == 16, "Malformed pack does not prevent built-in startup")
	write(PACK + "/units/infantry.json", JSON.parse_string(original))
	ModLoader.set_enabled("example_army", false)
	ContentRegistry.reload_content()
	check(not ModLoader.enabled("example_army") and not ModLoader.loaded.has("example_army"), "Disable selection persists and unloads pack")
	check(SaveService.validate_document(saved).contains("Missing content pack: example_army"), "Missing mod gives clear live-save error")
	check(NetworkCompatibility.error_for(manifest).contains("Missing content pack"), "Missing mod rejected before multiplayer")
	game = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new()
	game.settings.autosave = false
	root.add_child(game)
	var replay := ReplayController.new()
	replay.game = game
	game.add_child(replay)
	check(replay.open({"initial_scenario": frozen, "events": []}).is_empty(), "Missing-mod replay uses frozen gameplay profiles")
	check(game.battlefield.units.get_child(0).models[0].visual_root.get_child_count() > 0, "Replay retains original fallback art without mod")
	game.queue_free()
	await process_frame
	ModLoader.set_enabled("example_army", true)
	ContentRegistry.reload_content()
	check(ModLoader.enabled("example_army") and ModLoader.loaded.has("example_army"), "Enable selection persists and restores pack")
	cleanup()
	ContentRegistry.reload_content()
	DirAccess.remove_absolute("user://mod_test_save.json")
	print("GRIMTABLE MODS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
