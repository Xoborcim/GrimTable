extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures+=1; push_error("FAIL: "+text)

func run() -> void:
	var game: Node3D = load("res://scenes/main/main.tscn").instantiate()
	game.scenario = ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json").data
	game.settings = AppSettings.new()
	game.settings.autosave = false
	root.add_child(game)
	for i in 3: await process_frame
	game.life.ensure_models()
	var unit: TableUnit = game.battlefield.units.get_child(0)
	var model: Miniature = unit.models[0]
	var controller: UnitAnimationController = game.life.animations[model.model_id]
	var position := model.global_position
	var collision := (model.get_node("Collision") as CollisionShape3D).shape
	controller.move_from(position-Vector3(3,0,0),"Normal",false)
	controller.update(.1,.5,false,false,false)
	check(controller.state == UnitAnimationController.State.MOVING and not model.visual_root.position.is_equal_approx(controller.home),"Visual root moves independently")
	check(model.global_position == position and model.get_node("Collision").shape == collision,"Animation preserves canonical transform and collision")
	controller.update(1,1.5,false,false,false)
	check(controller.motion_left == 0 and model.global_position == position,"Movement settles without rules drift")
	model.selected = true
	controller.update(.1,2,false,false,false)
	check(controller.state == UnitAnimationController.State.SELECTED,"Selection alerts pose")
	controller.react(UnitAnimationController.State.ATTACKING)
	controller.update(.01,2.1,false,false,false)
	check(controller.state == UnitAnimationController.State.ATTACKING,"Canonical attack can trigger presentation")
	controller.react(UnitAnimationController.State.HIT)
	controller.update(.01,2.2,false,false,false)
	check(controller.state == UnitAnimationController.State.HIT,"Hit reaction state")
	controller.update(.1,2.3,true,false,false)
	check(model.visual_root.position == controller.home and model.global_position == position,"Reduced motion removes cosmetic transforms")
	model.selected = false
	var state := WorldState.capture(game)
	game.life.set_tactical(true)
	check(game.life.overlay.visible,"Hold tactical view opens")
	for terrain: TerrainPiece in game.battlefield.terrain.get_children(): check(terrain.footprint_overlay.visible,"Terrain traits visible")
	game.life.set_tactical(false)
	check(not game.life.overlay.visible and state == WorldState.capture(game),"Release tactical view cleans up without action")
	var vapor: Node=game.battlefield.visuals.get_node_or_null("EnvironmentalVapor")
	check(vapor!=null and vapor.get_child_count()>0 and game.battlefield.terrain.get_node_or_null("refinery_tower")!=null,"Showcase has authored refinery machinery and sparse steam")
	var settings := AppSettings.new()
	settings.movement_speed = "Cinematic"
	settings.ai_speed = "Fast"
	settings.save_settings()
	var loaded := AppSettings.new()
	loaded.load_settings()
	check(loaded.movement_speed == "Cinematic" and loaded.ai_speed == "Fast","Presentation speed settings persist")
	game.queue_free()
	await process_frame
	print("GRIMTABLE LIVING CHECKS: ",checks,"; failures: ",failures)
	quit(1 if failures else 0)
