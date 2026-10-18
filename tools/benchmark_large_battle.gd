extends SceneTree

var results: Array = []
var label := "baseline"
var samples := 90
var counts := [25, 50, 100, 200, 300]

func _initialize() -> void:
	call_deferred("run")

func setup(count: int) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/scenarios/empty.json"))
	data.board = {"width": 120, "depth": 120}
	data.starting_state.deployment = false
	data.armies = []
	var ids := ["legion_trooper", "synthetic_drone", "horde_gunner", "swarm_hunter", "legion_heavy"]
	for index in ceili(count / 5.0):
		var models := []
		var row := index / 10
		var column := index % 10
		for j in mini(5, count - index * 5): models.append({"id": "m_%d_%d" % [index, j], "position": [-45 + column * 10 + (j - 2) * 1.9, 0, -40 + row * 14], "rotation": 0})
		data.armies.append({"id": "squad_" + str(index), "name": "Benchmark Squad", "team": index % 2, "unit_id": ids[index % ids.size()], "models": models})
	data.terrain = [{"id": "wall", "title": "Benchmark Barrier", "kind": "box", "size": [6, 3, 1], "position": [0, 0, 45], "rotation": 0, "blocks_movement": true, "blocks_los": true}]
	data.objectives = []
	for i in 3: data.objectives.append({"id": "objective_" + str(i), "name": "Marker", "number": i + 1, "radius": 3, "position": [(i - 1) * 20, 0, 0]})
	return data

func measure_frames() -> float:
	for i in 12: await process_frame
	var started := Time.get_ticks_usec()
	for i in samples: await process_frame
	return (Time.get_ticks_usec() - started) / float(samples) / 1000.0

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--counts="):
			counts = []
			for count in arg.trim_prefix("--counts=").split(","): counts.append(clampi(int(count), 1, 300))
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1280, 800)
	for count in counts:
		var started := Time.get_ticks_usec()
		var game: Node3D = load("res://scenes/main/main.tscn").instantiate()
		game.settings = AppSettings.new()
		game.settings.autosave = false
		game.settings.camera_assistance = false
		game.settings.combat_camera = false
		game.scenario = setup(count)
		root.add_child(game)
		game.hud.dice_panel.hide()
		game.camera_rig.distance = 95
		game.camera_rig.destination = Vector3(0, 0, -10)
		game.camera_rig._update_camera(1)
		await physics_frame
		var load_ms := (Time.get_ticks_usec() - started) / 1000.0
		var idle_ms: float = await measure_frames()
		var unit: TableUnit = game.battlefield.units.get_child(0)
		var target: TableUnit = game.battlefield.units.get_child(1)
		started = Time.get_ticks_usec()
		for i in 100:
			game.selection.select_unit(unit)
			game.interaction.pick(game.camera_rig.camera.unproject_position(unit.models[0].eye()))
		var selection_ms := (Time.get_ticks_usec() - started) / 100.0 / 1000.0
		started = Time.get_ticks_usec()
		for i in 100: AttackResolver.preview(unit, target, game.get_world_3d(), unit.weapon_profiles[0])
		var attack_ms := (Time.get_ticks_usec() - started) / 100.0 / 1000.0
		game.interaction.set_mode(1)
		var movement_ms: float = await measure_frames()
		started = Time.get_ticks_usec()
		for i in 30: game.interaction.session.validation_error()
		var validation_ms := (Time.get_ticks_usec() - started) / 30.0 / 1000.0
		game.interaction.cancel()
		game.interaction.set_mode(3)
		game.interaction.target_model = target.models[0]
		game.hud.combat_panel.show()
		var targeting_ms: float = await measure_frames()
		var item := {"models": count, "load_ms": load_ms, "idle_frame_ms": idle_ms, "fps": 1000.0 / idle_ms, "movement_frame_ms": movement_ms, "targeting_frame_ms": targeting_ms, "selection_ms": selection_ms, "move_validation_ms": validation_ms, "attack_preview_ms": attack_ms, "static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
		results.append(item)
		print("BENCHMARK ", JSON.stringify(item))
		game.queue_free()
		for i in 4: await process_frame
	var report := {"label": label, "godot": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "logical_cpus": OS.get_processor_count(), "gpu": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(), "resolution": [1280, 800], "vsync": false, "frames_per_mode": samples, "results": results}
	if label == "visual_0110":
		var tray := DiceTray.new()
		tray.settings=AppSettings.new(); tray.settings.cinematic_dice="Full"; tray.settings.dice_volume=0
		root.add_child(tray)
		tray.enqueue("BENCHMARK",[1,2,3,4,5,6,6,5,4,3,2,1],4)
		var dice_ms: float=await measure_frames()
		report.dice={"bodies":12,"average_frame_ms":dice_ms,"fps":1000.0/dice_ms,"context":"tray alone; 90-frame sample during one Full roll"}
		tray.queue_free()
	DirAccess.make_dir_recursive_absolute("res://docs/benchmarks")
	var file := FileAccess.open("res://docs/benchmarks/" + label + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true, true))
	file.close()
	quit()
