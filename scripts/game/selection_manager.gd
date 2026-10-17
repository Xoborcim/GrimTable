class_name SelectionManager
extends RefCounted

signal changed
var models: Array[Miniature] = []
var unit_mode := false

func select(model: Miniature, additive: bool = false) -> void:
	unit_mode = false
	if not additive:
		clear(false)
	if model != null:
		if models.has(model):
			models.erase(model)
			model.selected = false
		else:
			models.append(model)
			model.selected = true
		model.refresh()
	changed.emit()

func clear(emit_signal: bool = true) -> void:
	unit_mode = false
	for model in models:
		model.selected = false
		model.refresh()
	models.clear()
	if emit_signal: changed.emit()

func primary() -> Miniature:
	return models[0] if not models.is_empty() else null

func selected_unit() -> TableUnit:
	if not unit_mode or primary() == null: return null
	var unit := primary().get_parent() as TableUnit
	for model in models:
		if model.get_parent() != unit: return null
	return unit

func select_unit(unit: TableUnit, additive: bool = false) -> void:
	if not additive: clear(false)
	if unit != null:
		var remove := true
		for model in unit.models:
			if not model.removed and not models.has(model): remove = false
		for model in unit.models:
			if model.removed: continue
			if remove:
				models.erase(model)
				model.selected = false
			elif not models.has(model):
				models.append(model)
				model.selected = true
			model.refresh()
	unit_mode = true
	changed.emit()

func select_from_click(model: Miniature, additive: bool = false, individual: bool = false) -> void:
	if model == null: clear()
	elif individual: select(model, additive)
	else: select_unit(model.get_parent() as TableUnit, additive)
