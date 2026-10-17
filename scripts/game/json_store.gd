class_name JsonStore
extends RefCounted

static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"error": "Cannot read " + path + ": " + error_string(FileAccess.get_open_error())}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK: return {"error": "Invalid JSON at line %d: %s" % [parser.get_error_line() + 1, parser.get_error_message()]}
	return {"data": parser.data}
