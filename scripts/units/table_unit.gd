class_name TableUnit
extends Node3D

# Squad identity and shared definitions are separate from miniature visuals.
var display_name := ""
var team := 0
var definition: Dictionary = {}
var definition_path := "res://resources/units/trooper.json"
var weapon_profiles: Array[Dictionary] = []
var models: Array[Miniature] = []
@export var coherency_distance := 2.0

func _ready() -> void:
	add_to_group("units")

func living_models() -> Array[Miniature]:
	var result: Array[Miniature] = []
	for model in models:
		if not model.removed and model.wounds > 0: result.append(model)
	return result
