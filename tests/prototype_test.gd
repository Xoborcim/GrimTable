extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)

func click(tool: InteractionController, screen: Vector2, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = screen
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.shift_pressed = shift
	event.alt_pressed = true
	tool._unhandled_input(event)

func run() -> void:
	root.size = Vector2i(1440, 900)
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await process_frame
	await process_frame
	await process_frame
	main.manager.deployment = false
	main.manager.changed.emit()
	var models := get_nodes_in_group("miniatures")
	check(models.size() == 10, "Ten demo miniatures")
	check(get_nodes_in_group("terrain").size() == 12, "Demo terrain")
	check(get_nodes_in_group("objectives").size() == 3, "Three objectives")
	var a := models[0] as Miniature
	var b := models[1] as Miniature
	var enemy := models[5] as Miniature
	var origin := a.position
	check(is_equal_approx(MeasurementService.horizontal_distance(Vector3.ZERO, Vector3(3, 99, 4)), 5), "Horizontal distances ignore height")
	check(is_equal_approx(MeasurementService.distance_between_bases(a, b), 3.0 - 1.26), "Edge-to-edge base distance")
	check(MovementService.move_error(main.battlefield, a, origin, origin + Vector3(0, 0, 3)).is_empty(), "Legal move accepted")
	check(not MovementService.move_error(main.battlefield, a, origin, origin + Vector3(0, 0, -7)).is_empty(), "Movement allowance enforced")
	check(not MovementService.placement_error(main.battlefield, a, b.position).is_empty(), "Overlapping bases rejected")
	check(not MovementService.placement_error(main.battlefield, a, Vector3(30, 0, 0)).is_empty(), "Whole base must stay on board")
	a.position = Vector3(-8, 0, 12)
	check(not MovementService.move_error(main.battlefield, a, a.position, Vector3(-8, 0, 8)).is_empty(), "Swept path cannot pass through wall")
	a.position = origin
	main.selection.select(a)
	check(a.selected and main.hud.selected_info.text.contains("Alpha Squad"), "Selection updates ring and HUD")
	main.selection.select(b, true)
	check(main.selection.models.size() == 2, "Additive selection")
	main.selection.select(b, true)
	check(main.selection.models.size() == 1 and not b.selected, "Shift toggle removes selection")
	var screen: Vector2 = main.camera_rig.camera.unproject_position(a.eye())
	check(main.interaction.pick(screen) == a, "Camera ray picks miniature")
	main.selection.clear()
	var actual_click := InputEventMouseButton.new()
	actual_click.position = screen
	actual_click.button_index = MOUSE_BUTTON_LEFT
	actual_click.pressed = true
	actual_click.alt_pressed = true
	root.push_input(actual_click, true)
	check(main.selection.primary() == a, "Viewport mouse input reaches selection tool")
	actual_click.pressed = false
	root.push_input(actual_click, true)
	main.hud.tools[1].pressed.emit()
	check(main.interaction.mode == InteractionController.InteractionMode.MOVE, "Toolbar selects correct tool")
	actual_click.pressed = true
	root.push_input(actual_click, true)
	check(main.interaction.dragging == a, "Viewport input starts model drag")
	var legal_destination := origin + Vector3(0, 0, 2)
	var move_mouse := InputEventMouseMotion.new()
	move_mouse.position = main.camera_rig.camera.unproject_position(legal_destination + main.interaction.drag_offset * -1)
	root.push_input(move_mouse, true)
	main.interaction._process(0)
	check(main.interaction.drag_error.is_empty() and a.position.is_equal_approx(legal_destination), "Mouse motion previews legal placement")
	actual_click.position = move_mouse.position
	actual_click.pressed = false
	root.push_input(actual_click, true)
	check(a.position.is_equal_approx(legal_destination) and main.interaction.dragging == null, "Mouse release commits legal placement")
	a.position = origin
	actual_click.position = screen
	actual_click.pressed = true
	root.push_input(actual_click, true)
	move_mouse.position = main.camera_rig.camera.unproject_position(origin + Vector3(0, 0, -8) - main.interaction.drag_offset)
	root.push_input(move_mouse, true)
	main.interaction._process(0)
	check(not main.interaction.drag_error.is_empty() and main.interaction.floating.text.contains("Exceeds"), "Invalid drag shows reason")
	actual_click.position = move_mouse.position
	actual_click.pressed = false
	root.push_input(actual_click, true)
	check(a.position.is_equal_approx(origin), "Illegal drag release restores original placement")
	main.interaction.set_mode(1)
	click(main.interaction, screen)
	check(main.interaction.dragging == a, "Move tool starts drag")
	a.position += Vector3(0, 0, 1)
	main.interaction.cancel()
	check(a.position.is_equal_approx(origin), "Escape restores original position")
	main.interaction.set_mode(2)
	click(main.interaction, main.camera_rig.camera.unproject_position(Vector3.ZERO))
	click(main.interaction, main.camera_rig.camera.unproject_position(Vector3(5, 0, 0)))
	check(main.interaction.measure_locked, "Measurement locks on second click")
	main.interaction.cancel()
	check(main.interaction.measure_start == null, "Measurement cancels")
	main.hud._wounds(-2)
	# Compact defeat markers replace the old developer-facing DOWN caption.
	check(a.wounds == 0 and not a.removed and a.visible and a.caption.visible and a.caption.text == "× " + a.code(), "Defeated miniature remains on table with a visible defeat marker")
	main.hud._wounds(10)
	check(a.wounds == a.max_wounds, "Wounds clamp to maximum")
	for count in [1, 2, 10, 100, 0, 999]:
		var roll: Dictionary = main.dice.roll(count)
		var total := 0
		check(roll["values"].size() == clampi(count, 1, 100), "Dice count is bounded")
		for value in roll["values"]:
			check(value >= 1 and value <= 6, "D6 result within range")
			total += value
		check(total == roll.total, "Dice total matches results")
	check(main.hud.dice_result.text.contains("TOTAL"), "Dice UI receives results")
	for i in 12: main.dice.roll(2)
	check(main.dice.history.size() == 8, "Dice history bounded")
	for i in 6: main.manager.next_phase()
	check(main.manager.active_team == 1 and main.manager.phase == 0 and main.manager.round_number == 1, "End phase switches team")
	for i in 6: main.manager.next_phase()
	check(main.manager.round_number == 2 and main.manager.active_team == 0, "Both turns advance round")
	main.manager.previous_phase()
	check(main.manager.round_number == 1 and main.manager.active_team == 1 and main.manager.phase == 5, "Previous phase crosses round")
	# Put two models across a known wall, then on an unobstructed flank.
	a.position = Vector3(-8, 0, 12)
	enemy.position = Vector3(-8, 0, 8)
	await physics_frame
	await physics_frame
	var los := MeasurementService.line_of_sight(main.get_world_3d(), a, enemy)
	check(not los.clear and los.obstacle.title == "South wall", "LOS identifies blocking terrain")
	main.interaction.update_target(a, enemy)
	check(main.hud.target_info.text.contains("BLOCKED") and main.hud.target_info.text.contains("IN RANGE"), "Target UI shows LOS and weapon range")
	a.position = Vector3(-27, 0, 16)
	enemy.position = Vector3(-27, 0, -16)
	await physics_frame
	await physics_frame
	check(MeasurementService.line_of_sight(main.get_world_3d(), a, enemy).clear, "Clear flank LOS")
	main.interaction.update_target(a, enemy)
	check(main.hud.target_info.text.contains("OUT OF RANGE"), "Weapon range checked against base distance")
	a.position = origin
	main.interaction.cancel()
	var objective := get_nodes_in_group("objectives")[0] as TableObjective
	main.interaction._select_objective(objective)
	check(objective.radius_ring.visible, "Objective selection displays radius")
	main.interaction.set_mode(0)
	main.interaction.setup_mode = true
	var objective_origin := objective.position
	var objective_screen: Vector2 = main.camera_rig.camera.unproject_position(objective.position)
	click(main.interaction, objective_screen)
	check(main.interaction.drag_object == objective, "Setup picks objective for repositioning")
	main.interaction.cancel()
	check(objective.position.is_equal_approx(objective_origin), "Cancel restores setup placement")
	var piece := get_nodes_in_group("terrain")[4] as TerrainPiece
	var piece_origin := piece.position
	click(main.interaction, main.camera_rig.camera.unproject_position(piece.position + Vector3.UP))
	check(main.interaction.drag_object == piece, "Setup picks terrain")
	main.interaction.cancel()
	check(piece.position.is_equal_approx(piece_origin), "Terrain cancellation preserves location")
	main.interaction.setup_mode = false
	main.interaction.set_mode(3)
	main.selection.select(a)
	click(main.interaction, main.camera_rig.camera.unproject_position(enemy.eye()))
	check(main.interaction.target_model == enemy and main.hud.target_info.text.contains(enemy.model_id), "Target click chooses opposing miniature")
	main.interaction.cancel()
	var save_path := SaveService.PATH
	var original_save := FileAccess.get_file_as_bytes(save_path) if FileAccess.file_exists(save_path) else PackedByteArray()
	var existed := FileAccess.file_exists(save_path)
	a.wounds = 1
	b.removed = true
	b.refresh()
	objective.position.x += 2
	check(SaveService.save_game(main, main.manager).begins_with("Saved"), "Save writes JSON")
	check(SaveService.save_game(main, main.manager).begins_with("Saved"), "Save safely replaces previous file")
	a.position += Vector3(1, 0, 0)
	a.wounds = 2
	b.removed = false
	objective.position.x += 3
	main.manager.next_round()
	check(SaveService.load_game(main, main.manager).begins_with("Loaded"), "Saved game loads")
	check(a.position.is_equal_approx(origin) and a.wounds == 1 and b.removed, "Save restores model position, wounds, removal")
	check(is_equal_approx(objective.position.x, -18) and main.manager.round_number == 1, "Save restores objectives and turn")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string('{"version":1,"models":[{}]}')
	file.close()
	check(SaveService.load_game(main, main.manager).begins_with("Load failed"), "Malformed saves rejected")
	check(a.position.is_equal_approx(origin) and a.wounds == 1, "Invalid save leaves current board untouched")
	if existed:
		file = FileAccess.open(save_path, FileAccess.WRITE)
		file.store_buffer(original_save)
		file.close()
	else: DirAccess.remove_absolute(save_path)
	print("GRIMTABLE: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
