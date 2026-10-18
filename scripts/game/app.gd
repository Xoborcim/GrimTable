extends Node

var settings := AppSettings.new()
var game: Node3D
var editor: ScenarioEditor
var editor_panel: EditorPanel
var replay: ReplayController
var replay_panel: ReplayPanel
var root: Control
var backdrop: ColorRect
var menu: PanelContainer
var column: VBoxContainer
var status: Label
var browser_items: Array[Dictionary] = []
var browser_choice: OptionButton
var edit_browser := false
var discard_dialog: ConfirmationDialog
var menu_diorama: MenuDiorama
var pending_ai: Dictionary = {}
var online_menu: MultiplayerMenu

func _ready() -> void:
	ContentRegistry.catalog()
	settings.load_settings()
	online_menu = MultiplayerMenu.new(self)
	settings.apply_window(get_window())
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = AppUI.theme()
	layer.add_child(root)
	backdrop = ColorRect.new()
	backdrop.color = Color("111a24")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	menu_diorama = MenuDiorama.new()
	menu_diorama.settings = settings
	backdrop.add_child(menu_diorama)
	var shade := ColorRect.new()
	shade.color = Color(0.015,.025,.035,.27)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(shade)
	menu = PanelContainer.new()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -330
	menu.offset_top = -350
	menu.offset_right = 330
	menu.offset_bottom = 350
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(scroll)
	column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = 590
	scroll.add_child(column)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Return to Main Menu"
	discard_dialog.dialog_text = "Discard the current session? Save the game or scenario first to keep your work."
	discard_dialog.visible = false
	discard_dialog.confirmed.connect(show_main)
	root.add_child(discard_dialog)
	show_main()
	if "--smoke-baked-0133" in OS.get_cmdline_user_args():
		var baked_smoke:=BakedVisual133Smoke.new();add_child(baked_smoke);baked_smoke.call_deferred("run",self)
	if "--smoke-composition-0131" in OS.get_cmdline_user_args():
		var composition_smoke:=Composition131Smoke.new();add_child(composition_smoke);composition_smoke.call_deferred("run",self)
	if "--smoke-environment" in OS.get_cmdline_user_args():
		var environment_smoke:=EnvironmentSmoke.new();add_child(environment_smoke);environment_smoke.call_deferred("run",self)
	if "--smoke-art" in OS.get_cmdline_user_args():
		var art_smoke:=ArtSmoke.new()
		add_child(art_smoke)
		art_smoke.call_deferred("run",self)
	if "--smoke-0110" in OS.get_cmdline_user_args():
		var smoke := Visual0110Smoke.new()
		add_child(smoke)
		smoke.call_deferred("run",self)
	if "--smoke-living" in OS.get_cmdline_user_args():
		var smoke := LivingSmoke.new()
		add_child(smoke)
		smoke.call_deferred("run",self)
	if "--smoke-visual" in OS.get_cmdline_user_args():
		var smoke := VisualSmoke.new()
		add_child(smoke)
		smoke.call_deferred("run",self)
	if "--smoke-guided" in OS.get_cmdline_user_args():
		var smoke := GuidedSmoke.new()
		add_child(smoke)
		smoke.call_deferred("run", self)
	if "--smoke-guided-damage" in OS.get_cmdline_user_args():
		var smoke := GuidedSmoke.new()
		add_child(smoke)
		smoke.call_deferred("run_damage", self)
	if "--smoke-automation" in OS.get_cmdline_user_args():
		var smoke := AutomationSmoke.new()
		add_child(smoke)
		smoke.call_deferred("run", self)
	if "--smoke-experience" in OS.get_cmdline_user_args():
		var smoke := ExperienceSmoke.new()
		add_child(smoke)
		smoke.call_deferred("run", self)
	if "--smoke-content-packs" in OS.get_cmdline_user_args(): call_deferred("_mod_export_smoke")
	if "--smoke-export" in OS.get_cmdline_user_args(): call_deferred("_export_smoke")
	if "--network-smoke-host" in OS.get_cmdline_user_args() or "--network-smoke-guest" in OS.get_cmdline_user_args(): call_deferred("_network_smoke")

func _network_smoke() -> void:
	var args := OS.get_cmdline_user_args()
	var code := ""
	for arg in args:
		if arg.begins_with("--room-code="): code = arg.trim_prefix("--room-code=")
		if arg.begins_with("--signal-url="): settings.signaling_url = arg.trim_prefix("--signal-url=")
	var smoke := NetworkSmoke.new()
	add_child(smoke)
	smoke.run(self, "--network-smoke-host" in args, code, "--lan" in args, "--relay-only" in args)

func clear_menu(title: String) -> void:
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -330
	menu.offset_right = 330
	menu.offset_top = -350
	menu.offset_bottom = 350
	column.custom_minimum_size.x = 590
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	backdrop.show()
	menu.show()
	AppUI.label(column, "GRIMTABLE", 34)
	AppUI.label(column, title, 20)
	status = AppUI.label(column, "", 15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func clear_game() -> void:
	if online_menu != null: online_menu.close()
	if is_instance_valid(game):
		if is_instance_valid(replay): replay.playing = false
		game.interaction.cancel()
		remove_child(game)
		game.queue_free()
	game = null
	editor = null
	editor_panel = null
	replay = null
	replay_panel = null

func show_main() -> void:
	clear_game()
	clear_menu("Miniature warfare. Your way.")
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	menu.offset_left = 64
	menu.offset_right = 434
	menu.offset_top = -315
	menu.offset_bottom = 315
	column.custom_minimum_size.x = 320
	column.get_child(0).add_theme_font_size_override("font_size", 42)
	AppUI.label(column,"THE HOLLOW BASILICA  /  LEGION vs SWARM",12).modulate = GrimTheme.IVORY
	var play := AppUI.button(column,"Play",show_local_play)
	play.add_theme_stylebox_override("normal",GrimTheme.primary())
	for action in [["Multiplayer",online_menu.show_menu],["Scenarios / Load",func(): show_browser(false)],["Scenario Editor",func(): show_browser(true)],["Miniature Library",show_miniature_library],["Mods",show_mods],["Replay",show_replays],["Settings",show_settings],["Quit",func(): get_tree().quit()]]:
		AppUI.button(column,action[0],action[1])
	AppUI.label(column,str(ProjectSettings.get_setting("application/config/version"))+"   /   ORIGINAL SCI-FI TABLETOP",12).modulate = GrimTheme.MUTED

func show_browser(edit: bool) -> void:
	edit_browser = edit
	clear_menu("Scenarios · " + ("Edit" if edit else "Play"))
	browser_items = ScenarioLibrary.list_scenarios()
	browser_choice = OptionButton.new()
	for item in browser_items:
		browser_choice.add_item(item.data.name if item.has("data") else "Invalid scenario · " + str(item.get("path", "")))
	column.add_child(browser_choice)
	browser_choice.item_selected.connect(func(index: int): status.text = str(browser_items[index].get("error", browser_items[index].get("data", {}).get("notes", ""))))
	AppUI.button(column, "Play", func(): launch_selected(false))
	AppUI.button(column, "Edit", func(): launch_selected(true))
	AppUI.button(column, "Load Saved Battle", show_load)
	AppUI.button(column, "New Scenario", func():
		var item := ScenarioLibrary.read(ScenarioLibrary.BUILTINS[1])
		if item.has("data"):
			item.data.id = ScenarioLibrary.new_id()
			item.data.name = "Custom Scenario"
			item.path = ""
		launch_scenario(item, true))
	AppUI.button(column, "Back", show_main)
	if not browser_items.is_empty(): status.text = str(browser_items[0].get("error", "Choose a scenario, then Play or Edit."))

func launch_selected(edit: bool) -> void:
	if browser_choice.selected < 0 or browser_choice.selected >= browser_items.size(): return
	if edit: launch_scenario(browser_items[browser_choice.selected], true)
	else: launch_with_transition(browser_items[browser_choice.selected])

func launch_scenario(item: Dictionary, edit: bool = false) -> bool:
	if item.has("error"):
		status.text = str(item.error)
		return false
	var issue := ScenarioDefinition.validate(item.get("data"))
	if not issue.is_empty():
		status.text = issue
		return false
	clear_game()
	game = preload("res://scenes/main/main.tscn").instantiate()
	game.scenario = item.data.duplicate(true)
	game.scenario_path = str(item.get("path", ""))
	game.settings = settings
	game.ai_config = pending_ai.duplicate(true) if not edit else {}
	pending_ai = {}
	game.editing = edit
	add_child(game)
	game.hud.menu_requested.connect(show_pause)
	menu.hide()
	backdrop.hide()
	if edit:
		editor = ScenarioEditor.new()
		editor.game = game
		editor.path = game.scenario_path
		game.add_child(editor)
		editor_panel = EditorPanel.new()
		editor_panel.editor = editor
		game.add_child(editor_panel)
		editor_panel.exit_requested.connect(func(): discard_dialog.popup_centered())
		editor_panel.play_requested.connect(func():
			var document := ScenarioFactory.capture(game)
			var path := editor.path
			launch_scenario({"data": document, "path": path}))
	return true

func show_pause() -> void:
	game.interaction.cancel()
	game.life.set_tactical(false)
	game.menu_open = true
	game.interaction.read_only = true
	if game.network_session == null: game.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud.hide()
	if is_instance_valid(editor_panel): editor_panel.hide()
	if is_instance_valid(replay_panel): replay_panel.hide()
	clear_menu("Session Menu")
	AppUI.button(column, "Resume", resume)
	AppUI.button(column, "Save Game", func(): status.text = SaveService.save_game(game, game.manager, game.battle_log, game.combat))
	AppUI.button(column, "Save Replay", func(): status.text = ReplayController.save(game))
	AppUI.button(column, "Settings", show_settings)
	if not game.ai.config.is_empty(): AppUI.button(column,"Surrender / Finish Battle",func():
		resume()
		game.ai.finish("You ended this battle."))
	if game.network_session != null:
		AppUI.button(column, "Network Diagnostics", func(): status.text = game.network_session.diagnostics())
	AppUI.button(column, "Main Menu", func(): discard_dialog.popup_centered())

func resume() -> void:
	if not is_instance_valid(game):
		show_main()
		return
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game.menu_open = false
	game.interaction.read_only = game.replay_mode
	if is_instance_valid(editor_panel): editor_panel.show()
	elif is_instance_valid(replay_panel): replay_panel.show()
	else: game.hud.show()
	menu.hide()
	backdrop.hide()

func show_load() -> void:
	clear_menu("Load Game")
	AppUI.button(column, "Load Manual Save", func(): load_slot(SaveService.PATH))
	AppUI.button(column, "Load Auto-save", func(): load_slot("user://autosave.json"))
	AppUI.button(column, "Back", show_main)

func load_slot(path: String) -> bool:
	if not FileAccess.file_exists(path):
		status.text = "No save found in this slot"
		return false
	var parsed := JsonStore.read(path)
	if parsed.has("error"):
		status.text = str(parsed.error)
		return false
	var data: Variant = parsed.data
	if not data is Dictionary:
		status.text = "Save contains invalid JSON"
		return false
	if data.has("format_version"):
		var issue := SaveService.validate_document(data)
		if not issue.is_empty():
			status.text = issue
			return false
		launch_scenario({"data": data.initial_scenario})
	else: launch_scenario(ScenarioLibrary.read(ScenarioLibrary.BUILTINS[0]))
	var result := SaveService.load_game(game, game.manager, game.battle_log, game.combat, path)
	if not result.begins_with("Loaded"):
		show_pause()
		status.text = result
		return false
	game.hud.set_status(result)
	return true

func show_replays() -> void:
	clear_menu("Replay · saves and recorded games")
	var paths: Array[String] = []
	for path in [SaveService.PATH, "user://autosave.json"]:
		if FileAccess.file_exists(path): paths.append(path)
	if DirAccess.dir_exists_absolute("user://replays/"):
		for file in DirAccess.get_files_at("user://replays/"):
			if file.ends_with(".json"): paths.append("user://replays/" + file)
	var choices := AppUI.choices(column, paths)
	AppUI.button(column, "Open Replay", func():
		if choices.selected >= 0 and choices.selected < paths.size(): open_replay(paths[choices.selected])
		else: status.text = "Save a game or use Menu → Save Replay first")
	AppUI.button(column, "Back", show_main)
	if paths.is_empty(): status.text = "No saved games or replays yet"

func open_replay(path: String) -> bool:
	var file := ReplayController.read(path)
	if file.has("error"):
		status.text = "Replay failed: " + str(file.error)
		return false
	launch_scenario({"data": file.data.initial_scenario})
	replay = ReplayController.new()
	replay.game = game
	game.add_child(replay)
	var issue := replay.open(file.data)
	if not issue.is_empty():
		show_pause()
		status.text = issue
		return false
	replay_panel = ReplayPanel.new()
	replay_panel.controller = replay
	game.add_child(replay_panel)
	replay_panel.exit_requested.connect(func(): show_main())
	return true

func show_settings() -> void:
	clear_menu("Settings")
	AppUI.label(column, "GAMEPLAY ASSISTANCE", 19)
	var preset := AppUI.choices(column, ["Guided", "Standard", "Tabletop", "Custom"], ["Guided", "Standard", "Tabletop", "Custom"].find(settings.assistance))
	var preset_changed := {"value": false}
	var custom_changed := {"value": false}
	preset.item_selected.connect(func(_index: int): preset_changed.value = true)
	AppUI.label(column, "Guided: learn as you play.\nStandard: automation without hints.\nTabletop: manual positioning and detailed rolls.\nCustom: keep individual choices.", 14)
	AppUI.label(column, "Combat Resolution")
	var resolution_mode := AppUI.choices(column, ["Fast", "Detailed", "Manual"], ["Fast", "Detailed", "Manual"].find(settings.combat_resolution))
	resolution_mode.item_selected.connect(func(_index: int): custom_changed.value = true)
	AppUI.button(column, "Reset Gameplay Hints", func(): settings.gameplay_hints.clear(); settings.save_settings(); status.text = "Gameplay hints reset.")
	var fullscreen := CheckBox.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = settings.fullscreen
	column.add_child(fullscreen)
	var sizes := [Vector2i(1280,720), Vector2i(1280,800), Vector2i(1440,900), Vector2i(1920,1080), Vector2i(2560,1440)]
	var resolution := AppUI.choices(column, ["1280 × 800", "1440 × 900", "1920 × 1080"], maxi(0, sizes.find(settings.resolution)))
	var sensitivity := AppUI.spin(column, "Camera sensitivity", settings.camera_sensitivity, 0.2, 3, 0.1)
	var precision := AppUI.spin(column, "Measurement decimals", settings.precision, 0, 3)
	var autosave := CheckBox.new()
	autosave.text = "Auto-save confirmed gameplay actions"
	autosave.button_pressed = settings.autosave
	column.add_child(autosave)
	var auto_damage := CheckBox.new()
	auto_damage.text = "Damage: Auto-Allocate (OFF = Ask Me; host setting online)"
	auto_damage.button_pressed = settings.auto_allocate_damage
	column.add_child(auto_damage)
	var auto_remove := CheckBox.new()
	auto_remove.text = "Casualties: Remove Automatically (OFF = Ask; host online)"
	auto_remove.button_pressed = settings.auto_remove_defeated
	column.add_child(auto_remove)
	AppUI.label(column, "PRESENTATION", 19)
	var quality := AppUI.choices(column, ["Low", "Medium", "High"], ["Low", "Medium", "High"].find(settings.quality))
	quality.tooltip_text = "Low: no shadows or MSAA. Medium: shadows + 2x MSAA. High: shadows + 4x MSAA."
	AppUI.label(column, "Cinematic Dice")
	var dice_mode := AppUI.choices(column,["Off","Quick","Full"],["Off","Quick","Full"].find(settings.cinematic_dice))
	var dice_style_choice := AppUI.choices(column,["Ivory","Steel"],["Ivory","Steel"].find(settings.dice_style))
	var dice_volume_choice := AppUI.spin(column,"Dice sound volume",settings.dice_volume,0,1,.05)
	AppUI.label(column, "Combat animation speed")
	var speed := AppUI.choices(column, ["Fast", "Normal", "Detailed"], ["Fast", "Normal", "Detailed"].find(settings.combat_speed))
	AppUI.label(column,"Movement animation speed")
	var move_speed := AppUI.choices(column,["Fast","Normal","Cinematic"],["Fast","Normal","Cinematic"].find(settings.movement_speed))
	AppUI.label(column,"AI turn speed")
	var ai_speed_choice := AppUI.choices(column,["Fast","Normal","Cinematic"],["Fast","Normal","Cinematic"].find(settings.ai_speed))
	var ui_scale := AppUI.spin(column, "UI text scale (next battlefield)", settings.ui_scale, 0.85, 1.4, 0.05)
	AppUI.label(column, "AUTOMATION / ACCESSIBILITY", 19)
	var toggles := {}
	for pair in [["quick_movement", "Quick squad movement"], ["offer_next_phase", "Offer next phase when no actions remain"], ["auto_advance_phase", "Automatically advance empty action phases (opt-in)"], ["camera_assistance", "Camera assistance"], ["hide_illegal_targets", "Hide illegal attack targets"], ["phase_warnings", "Warn before leaving unfinished phases"], ["combat_summary", "Show animated combat summary"], ["combat_camera", "Follow combat camera (manual input interrupts)"], ["automatic_scoring", "Automatic scenario scoring (host setting online)"], ["particles", "Cosmetic combat effects"], ["reduce_motion", "Reduce motion / instant camera focus"]]:
		var toggle := CheckBox.new()
		toggle.text = pair[1]
		toggle.button_pressed = settings.get(pair[0])
		column.add_child(toggle)
		toggles[pair[0]] = toggle
		toggle.toggled.connect(func(_value: bool): custom_changed.value = true)
	auto_damage.toggled.connect(func(_value: bool): custom_changed.value = true)
	auto_remove.toggled.connect(func(_value: bool): custom_changed.value = true)
	if not is_instance_valid(game): AppUI.button(column, "Network Server Settings", online_menu.settings)
	AppUI.button(column, "Apply and Save", func():
		settings.combat_resolution = ["Fast", "Detailed", "Manual"][resolution_mode.selected]
		if custom_changed.value: settings.assistance = "Custom"
		settings.cinematic_dice = ["Off","Quick","Full"][dice_mode.selected]
		settings.dice_style = ["Ivory","Steel"][dice_style_choice.selected]
		settings.dice_volume = dice_volume_choice.value
		settings.quality = ["Low", "Medium", "High"][quality.selected]
		settings.combat_speed = ["Fast", "Normal", "Detailed"][speed.selected]
		settings.movement_speed = ["Fast","Normal","Cinematic"][move_speed.selected]
		settings.ai_speed = ["Fast","Normal","Cinematic"][ai_speed_choice.selected]
		if is_instance_valid(game) and not game.ai.config.is_empty(): game.ai.config.speed = settings.ai_speed
		settings.ui_scale = ui_scale.value
		for key in toggles: settings.set(key, toggles[key].button_pressed)
		settings.fullscreen = fullscreen.button_pressed
		settings.resolution = sizes[resolution.selected]
		settings.camera_sensitivity = sensitivity.value
		settings.precision = int(precision.value)
		settings.autosave = autosave.button_pressed
		settings.auto_allocate_damage = auto_damage.button_pressed
		settings.auto_remove_defeated = auto_remove.button_pressed
		if preset_changed.value: settings.apply_assistance_preset(["Guided", "Standard", "Tabletop", "Custom"][preset.selected])
		settings.apply_window(get_window())
		if is_instance_valid(game):
			BattlefieldPresentation.apply_quality(game, settings)
			game.camera_rig.reduce_motion = settings.reduce_motion
			game.camera_rig.sensitivity = settings.camera_sensitivity
			game.interaction.precision = settings.precision
			game.hud.apply_assistance_layout()
			game.assistance.schedule_refresh()
		status.text = settings.save_settings())
	AppUI.button(column, "Back", func():
		if is_instance_valid(game): show_pause()
		else: show_main())

func _export_smoke() -> void:
	# Explicit packaged-build check; never runs during normal play.
	var test := PackagedSmoke.new()
	add_child(test)
	await test.run(self)

func show_mods() -> void:
	if is_instance_valid(game):
		status.text = "Return to the main menu before changing or reloading content packs."
		return
	clear_menu("Mods / installed content packs")
	AppUI.label(column, "Install folders containing manifest.json in user://mods/", 14)
	for entry in ModLoader.entries:
		var toggle := CheckBox.new()
		toggle.text = "%s | %s | %s" % [str(entry.name), str(entry.get("version", "?")), str(entry.get("author", "Unknown"))]
		toggle.button_pressed = entry.enabled
		toggle.disabled = not ScenarioDefinition.valid_id(entry.id)
		column.add_child(toggle)
		AppUI.label(column, str(entry.error) if not str(entry.error).is_empty() else ("Enabled" if entry.enabled else "Disabled"), 13)
		toggle.toggled.connect(func(value: bool):
			ModLoader.set_enabled(str(entry.id), value)
			call_deferred("reload_mods"))
	AppUI.button(column, "Open Mods Folder", func(): OS.shell_open(ProjectSettings.globalize_path("user://mods")))
	AppUI.button(column, "Reload Mods", reload_mods)
	AppUI.button(column, "Back", show_main)

func reload_mods() -> void:
	if is_instance_valid(game): return
	ContentRegistry.reload_content()
	show_mods()

func _mod_export_smoke() -> void:
	var smoke := ModPackagedSmoke.new()
	add_child(smoke)
	await smoke.run(self)

func launch_with_transition(item: Dictionary) -> void:
	clear_menu("Preparing your battlefield")
	AppUI.label(column,str(item.get("data",{}).get("name","Scenario")),28)
	AppUI.label(column,"Tip: keep your squads near objectives to score points.",15)
	status.text = "Loading terrain and miniatures..."
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if launch_scenario(item) and game.scenario.id == "ashfall_station":
		var intro: PanelContainer = game.hud._panel(-235,145,235,145,Control.PRESET_CENTER_TOP)
		var stack := VBoxContainer.new()
		intro.add_child(stack)
		AppUI.label(stack,"Ashfall Station",28)
		AppUI.label(stack,"Control the relays. Hold the station.",16)
		AppUI.button(stack,"Skip",intro.queue_free)
		GrimTheme.enter(intro,settings.reduce_motion)
		get_tree().create_timer(1.7).timeout.connect(func(): if is_instance_valid(intro): intro.queue_free())

func show_local_play() -> void:
	clear_menu("Play a local battle")
	var items := ScenarioLibrary.list_scenarios().filter(func(item): return item.has("data"))
	var names: Array[String] = []
	var selected := 0
	for item in items:
		if item.data.id == "ashfall_station": selected = names.size()
		names.append(item.data.name)
	AppUI.label(column,"Scenario")
	var scenario_choice := AppUI.choices(column,names,selected)
	AppUI.label(column,"Your side")
	var side := AppUI.choices(column,["Team A","Team B"],0)
	AppUI.label(column,"Opponent")
	var opponent := AppUI.choices(column,["AI","Human (hotseat)","AI vs AI (spectate)"],0)
	AppUI.label(column,"Difficulty - decision quality, no stat bonuses")
	var difficulty := AppUI.choices(column,["Easy","Normal","Hard"],0 if settings.assistance == "Guided" else 1)
	AppUI.label(column,"Six rounds. Most objective points wins. Elimination also ends the battle.",15)
	AppUI.button(column,"Start Battle",func():
		pending_ai = {}
		if opponent.selected != 1:
			var teams := {}
			teams[str(1-side.selected)] = ["Easy","Normal","Hard"][difficulty.selected]
			if opponent.selected == 2: teams[str(side.selected)] = ["Easy","Normal","Hard"][difficulty.selected]
			pending_ai = {"teams":teams,"human_team":side.selected,"seed":int(Time.get_unix_time_from_system()) % 2147483647,"round_limit":6,"speed":settings.ai_speed}
		launch_with_transition(items[scenario_choice.selected]))
	AppUI.button(column,"Back",show_main)

func show_miniature_library() -> void:
	menu.hide()
	var library := MiniatureLibraryPanel.new()
	library.app = self
	root.add_child(library)
