class_name ActionHistory
extends RefCounted

signal changed
var undo_stack: Array[GameAction] = []
var redo_stack: Array[GameAction] = []
var log: BattleLog
var submit: Callable

func perform(action: GameAction) -> void:
	if submit.is_valid() and submit.call(action): return
	action.execute()
	undo_stack.append(action)
	redo_stack.clear()
	if log != null: log.append("execute", action.record())
	changed.emit()

func undo() -> void:
	if undo_stack.is_empty(): return
	var action: GameAction = undo_stack.pop_back()
	action.undo()
	redo_stack.append(action)
	if log != null: log.append("undo", action.record())
	changed.emit()

func redo() -> void:
	if redo_stack.is_empty(): return
	var action: GameAction = redo_stack.pop_back()
	action.execute()
	undo_stack.append(action)
	if log != null: log.append("redo", action.record())
	changed.emit()

func clear() -> void:
	undo_stack.clear()
	redo_stack.clear()
	changed.emit()
