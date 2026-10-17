extends SceneTree

func _initialize() -> void:
	for platform in ["windows", "linux", "macos"]:
		var directory: String = "res://builds/" + platform
		if not DirAccess.dir_exists_absolute(directory): continue
		DirAccess.make_dir_recursive_absolute(directory + "/licenses")
		for notice in ["LICENSE", "THIRD_PARTY_NOTICES.md"]:
			DirAccess.copy_absolute("res://" + notice, directory + "/" + notice)
		for notice in DirAccess.get_files_at("res://addons/webrtc_native"):
			if notice.begins_with("LICENSE.") or notice == "UPSTREAM.md":
				DirAccess.copy_absolute("res://addons/webrtc_native/" + notice, directory + "/licenses/" + notice)
		var file := FileAccess.open(directory + "/GODOT_LICENSES.txt", FileAccess.WRITE)
		file.store_string(Engine.get_license_text() + "\n\n")
		var licenses: Dictionary = Engine.get_license_info()
		for name: String in licenses:
			file.store_string(name + "\n" + str(licenses[name]) + "\n\n")
		file.store_string("\nComponent notices\n" + JSON.stringify(Engine.get_copyright_info(), "\t"))
		file.close()
	var sums := FileAccess.open("res://builds/SHA256SUMS.txt", FileAccess.WRITE)
	for path: String in ["windows/GrimTable.exe", "windows/libwebrtc_native.windows.template_release.x86_64.dll", "linux/GrimTable.x86_64", "linux/libwebrtc_native.linux.template_release.x86_64.so", "macos/GrimTable.zip"]:
		if FileAccess.file_exists("res://builds/" + path): sums.store_line(FileAccess.get_sha256("res://builds/" + path) + "  " + path)
	sums.close()
	quit()
