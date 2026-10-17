class_name GameAction
extends RefCounted

var title: String
var kind: String
var changes: Array[Dictionary]
var metadata: Dictionary

func _init(label: String = "Action", action_kind: String = "state", properties: Array[Dictionary] = [], details: Dictionary = {}) -> void:
	title = label
	kind = action_kind
	changes = properties
	metadata = details.duplicate(true)

func execute() -> void:
	_apply("after")

func undo() -> void:
	_apply("before")

func _apply(field: String) -> void:
	for change in changes:
		var subject: Object = change.object.get_ref() if change.object is WeakRef else change.object
		if is_instance_valid(subject):
			subject.set(change.property, change[field])
			if subject is Miniature: subject.refresh()

func record() -> Dictionary:
	var properties: Array[Dictionary] = []
	var actor := str(metadata.get("unit", ""))
	var affected: Array[String] = []
	for change in changes:
		var subject: Object = change.object.get_ref() if change.object is WeakRef else change.object
		if actor.is_empty() and subject is Miniature: actor = str(subject.get_parent().name)
		affected.append(change.get("id", ""))
		properties.append({"id": change.get("id", ""), "property": change.property, "before": _serial(change.before), "after": _serial(change.after)})
	return {"title": title, "kind": kind, "type": kind, "actor": actor, "affected_objects": affected, "changes": properties, "metadata": metadata.duplicate(true)}

static func _serial(value: Variant) -> Variant:
	if value is Vector3: return [value.x, value.y, value.z]
	if value is AttackResolution: return value.snapshot()
	return value
