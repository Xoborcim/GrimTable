extends "res://tools/benchmark_large_battle.gd"

func setup(count: int) -> Dictionary:
	var data:=super.setup(count)
	var flagship: Dictionary=ScenarioLibrary.read(ScenarioLibrary.FLAGSHIP).data
	data.terrain=flagship.terrain.duplicate(true)
	var appearance: Dictionary=flagship.board.duplicate(true)
	appearance.erase("width");appearance.erase("depth")
	data.board.merge(appearance,true)
	data.id="composition_stress_0131"
	return data

func measure_frames() -> float:
	# Match the 0.13.0 stress camera, independent of improved gameplay framing.
	var game: Node3D=root.get_child(0)
	game.camera_rig.pitch=.86;game.camera_rig.heading=0
	game.camera_rig._update_camera(1)
	return await super.measure_frames()
