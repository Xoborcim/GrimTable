extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.runtime")
	var main: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	var units := get_nodes_in_group("units")
	main.selection.select_unit(units[0])
	await capture("res://.runtime/squad_deployment.png")
	main.start_game()
	main.interaction.set_mode(1)
	var unit := units[0] as TableUnit
	var model := unit.models[0]
	var origin := model.global_position
	model.global_position += Vector3(0, 0, 1)
	main.interaction.session.stage(model, origin)
	main.interaction.movement_changed.emit()
	await capture("res://.runtime/squad_movement.png")
	main.interaction.cancel()
	for i in 5:
		units[0].models[i].global_position = Vector3(-3 + i * 1.5, 0, 6)
		units[1].models[i].global_position = Vector3(-3 + i * 1.5, 0, -6)
	await physics_frame
	await physics_frame
	main.interaction.set_mode(3)
	main.interaction.target_model = units[1].models[0]
	main.hud.dice_panel.hide()
	main.hud.combat_panel.show()
	main.dice.rng.seed = 42
	main.combat.resolve(units[0], units[1], main.get_world_3d())
	await capture("res://.runtime/combat.png")
	main.hud.combat_panel.log_window.popup_centered(Vector2i(760, 560))
	await capture("res://.runtime/battle_log.png")
	quit()
