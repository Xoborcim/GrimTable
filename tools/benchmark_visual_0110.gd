extends "res://tools/benchmark_large_battle.gd"

func setup(count: int) -> Dictionary:
	var data := super.setup(count)
	var showcase := ScenarioLibrary.read("res://resources/scenarios/ashen_basilica.json").data as Dictionary
	data.terrain = showcase.terrain.duplicate(true)
	data.board.theme = "cathedral"
	return data
