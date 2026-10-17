class_name AttackResolution
extends RefCounted

var attack_id := 0
var result: Dictionary = {}
var target: TableUnit
var remaining := 0

func snapshot() -> Dictionary:
	return {"attack_id": attack_id, "result": result.duplicate(true), "target": str(target.name), "remaining": remaining}
