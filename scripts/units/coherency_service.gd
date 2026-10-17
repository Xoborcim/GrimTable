class_name CoherencyService
extends RefCounted

static func is_unit_coherent(unit: TableUnit) -> bool:
	return get_incoherent_models(unit).is_empty()

static func get_incoherent_models(unit: TableUnit) -> Array[Miniature]:
	var remaining := unit.living_models()
	var largest: Array[Miniature] = []
	# Connectivity matters: two separate pairs are not a coherent squad.
	while not remaining.is_empty():
		var component: Array[Miniature] = [remaining.pop_front()]
		var index := 0
		while index < component.size():
			for candidate in remaining.duplicate():
				if MeasurementService.distance_between_bases(component[index], candidate) <= unit.coherency_distance + 0.001:
					remaining.erase(candidate)
					component.append(candidate)
			index += 1
		if component.size() > largest.size(): largest = component
	var invalid: Array[Miniature] = []
	for model in unit.living_models():
		if not largest.has(model): invalid.append(model)
	return invalid
