extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.start_game()
	var models := get_nodes_in_group("miniatures")
	main.selection.select(models[0])
	main.manager.next_phase()
	main.dice.roll(10)
	main.interaction.set_mode(3)
	main.interaction.target_model = models[8]
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/preview.png")
	main.interaction.set_mode(1)
	var start: Vector2 = main.camera_rig.camera.unproject_position(models[0].eye())
	var press := InputEventMouseButton.new()
	press.position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = main.camera_rig.camera.unproject_position(models[0].position + Vector3(1, 0, -3) - main.interaction.drag_offset)
	root.push_input(motion, true)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.runtime/movement.png")
	quit()
