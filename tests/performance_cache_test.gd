extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + reason)

func sync() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func run() -> void:
	var game: Node3D = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new()
	game.settings.autosave = false
	game.scenario = ScenarioLibrary.read("res://resources/scenarios/legion_vs_swarm.json").data
	game.scenario.terrain = []
	root.add_child(game)
	await sync()
	var unit: TableUnit = game.battlefield.units.get_child(0)
	var target: TableUnit = game.battlefield.units.get_child(3)
	var objective: TableObjective = game.battlefield.objectives.get_child(0)
	objective.global_position = unit.models[2].global_position
	game.battlefield.invalidate_spatial()
	var control: Dictionary = game.battlefield.control_for(objective)
	check(control.counts["0"] == 5, "Cached objective initial count")
	var revision: int = game.battlefield.spatial_revision
	var model := unit.models[0]
	game.history.perform(GameAction.new("Defeat test model", "wounds", [{"object": model, "id": model.model_id, "property": "wounds", "before": model.wounds, "after": 0}]))
	check(game.battlefield.spatial_revision > revision, "Damage action invalidates spatial caches")
	check(game.battlefield.control_for(objective).counts["0"] == 4, "Objective cache excludes new casualty")
	game.history.undo()
	check(game.battlefield.control_for(objective).counts["0"] == 5, "Undo refreshes objective control")
	game.selection.select_unit(unit)
	game.interaction.set_mode(3)
	game.interaction.target_model = target.models[0]
	var panel: CombatPanel = game.hud.combat_panel
	panel.show()
	panel.update_preview()
	check(panel.eligibility.text.contains("10 dice"), "Initial range/LOS preview")
	var wall := TerrainPiece.new()
	wall.size = Vector3(50, 5, 1)
	game.battlefield.terrain.add_child(wall)
	game.battlefield.invalidate_spatial()
	await sync()
	panel.update_preview()
	check(panel.eligibility.text.contains("0 dice"), "Terrain change invalidates LOS preview")
	wall.queue_free()
	game.battlefield.invalidate_spatial()
	await sync()
	panel.update_preview()
	check(panel.eligibility.text.contains("10 dice"), "Terrain removal refreshes eligible shooters")
	var snapshot := WorldState.capture(game)
	model.wounds = 0
	WorldState.apply(game, snapshot)
	check(game.battlefield.control_for(objective).counts["0"] == 5, "World restore invalidates objective caches")
	panel.hide()
	game.interaction.set_mode(1)
	await process_frame
	var preview: SquadMovePreview = game.interaction.move_preview
	preview._process(0)
	var link := preview.links.get_child(0)
	preview._process(0)
	check(preview.links.get_child(0) == link, "Idle coherency preview reuses links")
	model.global_position += Vector3(0, 0, 0.1)
	preview._process(0)
	check(preview.links.get_child(0) != link, "Changed formation refreshes coherency links")
	game.interaction.cancel()
	game.queue_free()
	await process_frame
	print("GRIMTABLE PERFORMANCE CACHES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
