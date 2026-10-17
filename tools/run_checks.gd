extends SceneTree

# Clone only source into a uniquely named validation project. This keeps tests
# away from the player's settings, manual save, and auto-save on every OS.
func _initialize() -> void:
	call_deferred("run")

func copy_folder(source: String, destination: String) -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	for directory in DirAccess.get_directories_at(source): copy_folder(source + "/" + directory, destination + "/" + directory)
	for file in DirAccess.get_files_at(source):
		var error := DirAccess.copy_absolute(source + "/" + file, destination + "/" + file)
		if error != OK: push_error("Validation copy failed: " + file)

func run() -> void:
	var suffix := str(Time.get_ticks_usec())
	var target := ProjectSettings.globalize_path("res://.runtime/validation_project_" + suffix)
	DirAccess.make_dir_recursive_absolute(target)
	for directory in ["scripts", "scenes", "resources", "tests", "addons", "assets", "examples", "mods"]: copy_folder("res://" + directory, target + "/" + directory)
	DirAccess.copy_absolute("res://icon.svg", target + "/icon.svg")
	var text := FileAccess.get_file_as_string("res://project.godot").replace('config/name="GrimTable"', 'config/name="GrimTable Validation ' + suffix + '"')
	var file := FileAccess.open(target + "/project.godot", FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", target, "--editor", "--quit"], output, true)
	if code != 0:
		print("\n".join(output))
		quit(1)
		return
	for suite in ["prototype_test", "squad_combat_test", "scenario_replay_test", "application_test", "network_test", "internet_readiness_test", "network_failure_test", "content_test", "mod_test", "performance_cache_test", "experience_test", "assistance_test", "guided_test", "visual_test", "living_test", "ai_test"]:
		output.clear()
		var result := OS.execute(OS.get_executable_path(), ["--headless", "--path", target, "--script", "res://tests/" + suite + ".gd"], output, true)
		for line in "\n".join(output).split("\n"):
			if "GRIMTABLE" in line or "FAIL" in line or "SCRIPT ERROR" in line: print(line)
		if result != 0:
			print("\n".join(output))
			code = 1
	print("VALIDATION ", "PASS" if code == 0 else "FAIL", " · isolated project: ", target)
	quit(code)
