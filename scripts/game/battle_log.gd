class_name BattleLog
extends RefCounted

signal changed
var entries: Array[Dictionary] = []
var sequence := 0

func append(kind: String, payload: Dictionary) -> int:
	sequence += 1
	entries.append({"sequence": sequence, "kind": kind, "payload": payload.duplicate(true)})
	changed.emit()
	return sequence

func restore(records: Array) -> void:
	entries.clear()
	sequence = 0
	for record: Dictionary in records:
		entries.append(record.duplicate(true))
		sequence = maxi(sequence, int(record.get("sequence", 0)))
	changed.emit()
