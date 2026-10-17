class_name ReplayController
extends Node

signal changed
signal error(message: String)
var game: Node3D
var initial: Dictionary = {}
var events: Array = []
var index := 0
var playing := false
var speed := 1.0
var elapsed := 0.0
var resolutions: Dictionary = {}
var last_attack: Dictionary = {}
var animation: Tween
var busy := false

func play() -> void:
	playing = true
	if busy and animation != null: animation.play()
	changed.emit()

func pause() -> void:
	playing = false
	if busy and animation != null: animation.pause()
	changed.emit()

func open(data: Dictionary) -> String:
	var source: Variant = data.get("initial_scenario")
	var issue := ScenarioDefinition.validate(source)
	if not issue.is_empty(): return "Replay scenario: " + issue
	var records: Variant = data.get("events", data.get("battle_log"))
	issue = ActionCodec.validate(records, source)
	if not issue.is_empty(): return "Corrupt replay: " + issue
	initial = source.duplicate(true)
	events = records.duplicate(true)
	game.replay_mode = true
	game.interaction.read_only = true
	game.hud.hide()
	seek(0)
	return ""

func seek(value: int) -> void:
	if animation != null: animation.kill()
	busy = false
	playing = false
	game.apply_scenario(initial)
	resolutions.clear()
	last_attack = {}
	index = 0
	for i in clampi(value, 0, events.size()): _apply_next()
	game.battle_log.restore(events.slice(0, index))
	changed.emit()

func _apply_next() -> void:
	var event: Dictionary = events[index]
	if event.kind == "attack": last_attack = AttackResolver.normalize_result(event.payload)
	ActionCodec.apply(event, game, resolutions)
	index += 1

func step_forward(animate: bool = true) -> void:
	if index >= events.size() or busy:
		if index >= events.size(): playing = false
		return
	var objects := WorldState.registry(game)
	var before := {}
	for id: String in objects:
		if objects[id] is Node3D: before[id] = objects[id].global_position
	_apply_next()
	if animate:
		animation = create_tween().set_parallel(true)
		var count := 0
		for id: String in before:
			var object: Node3D = objects[id]
			var destination := object.global_position
			if not destination.is_equal_approx(before[id]):
				object.global_position = before[id]
				animation.tween_property(object, "global_position", destination, 0.35 / speed)
				count += 1
		if count == 0: animation.kill()
		else:
			busy = true
			animation.finished.connect(func(): busy = false)
	game.battle_log.restore(events.slice(0, index))
	changed.emit()

func _process(delta: float) -> void:
	if not playing or busy: return
	elapsed += delta * speed
	if elapsed >= 0.8:
		elapsed = 0
		step_forward()

static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"error": "Replay/save file not found"}
	var parsed := JsonStore.read(path)
	if parsed.has("error"): return parsed
	var data: Variant = parsed.data
	if not data is Dictionary: return {"error": "Replay contains invalid JSON"}
	if data.get("replay_supported", true) == false: return {"error": "This legacy save predates complete action recording and cannot be replayed. Start a new scenario to record a replay."}
	if (data.get("format_version") != 1 and data.get("format_version") != 2) or not data.has("initial_scenario"): return {"error": "Unsupported replay/save version or missing initial scenario"}
	var issue := ScenarioDefinition.validate(data.initial_scenario)
	if issue.is_empty(): issue = ActionCodec.validate(data.get("events", data.get("battle_log")), data.initial_scenario)
	return {"error": issue} if not issue.is_empty() else {"data": data}

static func save(game: Node3D) -> String:
	if not game.replay_supported: return "Legacy history cannot be replayed; start a new scenario to record complete actions."
	var issue := ActionCodec.validate(game.battle_log.entries, game.initial_scenario)
	if not issue.is_empty(): return "Replay save failed: " + issue
	var folder := "user://replays/"
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder + ScenarioLibrary.new_id("replay") + ".json"
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return "Replay save failed: " + error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify({"format_version": 1, "local_opponents": game.ai.snapshot() if game.get("ai") != null else {}, "required_content": game.initial_scenario.get("required_content", []), "initial_scenario": game.initial_scenario, "events": game.battle_log.entries}, "\t", true, true))
	var code := file.get_error()
	file.close()
	if code != OK: return "Replay save failed: " + error_string(code)
	code = DirAccess.rename_absolute(path + ".tmp", path)
	if code != OK: return "Replay save failed: " + error_string(code)
	return "Saved replay: " + path
