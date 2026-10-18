class_name AppSettings
extends RefCounted

var fullscreen := false
var assistance := "Guided"
var quick_movement := true
var combat_resolution := "Fast"
var offer_next_phase := true
var auto_advance_phase := false
var camera_assistance := true
var hide_illegal_targets := false
var gameplay_hints := {}
var quality := "Medium"
var movement_speed := "Normal"
var ai_speed := "Normal"
var combat_speed := "Normal"
var cinematic_dice := "Quick"
var dice_style := "Ivory"
var dice_volume := .35
var combat_camera := false
var particles := true
var phase_warnings := true
var combat_summary := true
var automatic_scoring := true
var ui_scale := 1.0
var reduce_motion := false
var resolution := Vector2i(1440, 900)
var camera_sensitivity := 1.0
var precision := 1
var autosave := true
var auto_allocate_damage := false
var auto_remove_defeated := false
var signaling_url := "ws://127.0.0.1:8080"
var player_name := "Player"
const PATH := "user://settings.cfg"

func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK: return
	for key in ["cinematic_dice", "dice_style", "dice_volume", "movement_speed", "ai_speed", "quality", "combat_speed", "combat_camera", "particles", "phase_warnings", "combat_summary", "automatic_scoring", "ui_scale", "reduce_motion", "assistance", "quick_movement", "combat_resolution", "offer_next_phase", "auto_advance_phase", "camera_assistance", "hide_illegal_targets", "gameplay_hints"]:
		var value: Variant = file.get_value("experience", key, get(key))
		if typeof(value) == typeof(get(key)): set(key, value)
	if cinematic_dice not in ["Off", "Quick", "Full"]: cinematic_dice = "Quick"
	if dice_style not in ["Ivory", "Steel"]: dice_style = "Ivory"
	dice_volume = clampf(dice_volume,0,1)
	if movement_speed not in ["Fast","Normal","Cinematic"]: movement_speed = "Normal"
	if ai_speed not in ["Fast","Normal","Cinematic"]: ai_speed = "Normal"
	if quality not in ["Low", "Medium", "High"]: quality = "Medium"
	if combat_speed not in ["Fast", "Normal", "Detailed"]: combat_speed = "Normal"
	if assistance == "Assisted": assistance = "Standard" # Preserve existing players without restarting hints.
	if assistance not in ["Guided", "Standard", "Tabletop", "Custom"]: assistance = "Custom"
	if combat_resolution not in ["Fast", "Detailed", "Manual"]: combat_resolution = "Fast"
	ui_scale = clampf(ui_scale, 0.85, 1.4)
	fullscreen = bool(file.get_value("window", "fullscreen", false))
	var size: Variant = file.get_value("window", "resolution", Vector2i(1440, 900))
	if size is Vector2i: resolution = Vector2i(clampi(size.x, 1280, 3840), clampi(size.y, 720, 2160))
	var sensitivity: Variant = file.get_value("table", "camera_sensitivity", 1.0)
	if ScenarioDefinition.number(sensitivity, 0.2, 3): camera_sensitivity = float(sensitivity)
	var decimals: Variant = file.get_value("table", "precision", 1)
	if ScenarioDefinition.number(decimals, 0, 3): precision = int(decimals)
	autosave = bool(file.get_value("table", "autosave", true))
	auto_allocate_damage = bool(file.get_value("table", "auto_allocate_damage", false))
	auto_remove_defeated = bool(file.get_value("table", "auto_remove_defeated", false))
	var url: Variant = file.get_value("network", "signaling_url", signaling_url)
	if url is String and OnlineTransport.valid_url(url): signaling_url = url
	var display: Variant = file.get_value("network", "player_name", player_name)
	if display is String: player_name = display.left(32)

func save_settings() -> String:
	var file := ConfigFile.new()
	for key in ["cinematic_dice", "dice_style", "dice_volume", "movement_speed", "ai_speed", "quality", "combat_speed", "combat_camera", "particles", "phase_warnings", "combat_summary", "automatic_scoring", "ui_scale", "reduce_motion", "assistance", "quick_movement", "combat_resolution", "offer_next_phase", "auto_advance_phase", "camera_assistance", "hide_illegal_targets", "gameplay_hints"]: file.set_value("experience", key, get(key))
	file.set_value("window", "fullscreen", fullscreen)
	file.set_value("window", "resolution", resolution)
	file.set_value("table", "camera_sensitivity", camera_sensitivity)
	file.set_value("table", "precision", precision)
	file.set_value("table", "autosave", autosave)
	file.set_value("table", "auto_allocate_damage", auto_allocate_damage)
	file.set_value("table", "auto_remove_defeated", auto_remove_defeated)
	file.set_value("network", "signaling_url", signaling_url)
	file.set_value("network", "player_name", player_name)
	var error := file.save(PATH)
	return "Settings saved" if error == OK else "Settings save failed: " + error_string(error)

func apply_window(window: Window) -> void:
	window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if not fullscreen: window.size = resolution

func apply_assistance_preset(value: String) -> void:
	assistance = "Standard" if value == "Assisted" else value if value in ["Guided", "Standard", "Tabletop", "Custom"] else "Custom"
	if assistance == "Custom": return
	quick_movement = assistance in ["Guided", "Standard"]
	combat_resolution = "Fast" if assistance in ["Guided", "Standard"] else "Detailed"
	offer_next_phase = assistance in ["Guided", "Standard"]
	auto_advance_phase = false
	camera_assistance = assistance in ["Guided", "Standard"]
	automatic_scoring = true
	auto_allocate_damage = false
	auto_remove_defeated = false
	phase_warnings = true
	combat_summary = true
