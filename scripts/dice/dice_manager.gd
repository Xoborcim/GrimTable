class_name DiceManager
extends RefCounted

signal rolled(result: Dictionary)
var history: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var submit: Callable

func _init() -> void:
	rng.randomize()

func roll(count: int) -> Dictionary:
	if submit.is_valid() and submit.call(count): return {}
	count = clampi(count, 1, 100)
	var values := roll_d6(count)
	var total := 0
	for value in values:
		total += value
	values.sort()
	values.reverse()
	var result := {"count": count, "values": values, "total": total}
	history.push_front(result)
	if history.size() > 8: history.pop_back()
	rolled.emit(result)
	return result

func roll_d6(count: int) -> Array[int]:
	var values: Array[int] = []
	for i in clampi(count, 0, 10000): values.append(rng.randi_range(1, 6))
	return values

static func count_successes(rolls: Array, target: int) -> int:
	var count := 0
	for value in rolls:
		if int(value) >= target: count += 1
	return count
