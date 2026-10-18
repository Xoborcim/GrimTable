extends "res://tools/benchmark_visual_0110.gd"

func setup(count: int) -> Dictionary:
	var data:=super.setup(count)
	var appearance: Dictionary=ScenarioLibrary.read(ScenarioLibrary.FLAGSHIP).data.board.duplicate(true)
	# Preserve the previous 120-inch mixed-roster stress fixture and its camera.
	appearance.erase("width");appearance.erase("depth")
	data.board.merge(appearance,true)
	data.id="environment_stress_0130"
	return data
