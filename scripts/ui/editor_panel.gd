class_name EditorPanel
extends CanvasLayer

signal exit_requested
signal play_requested
var editor: ScenarioEditor
var root: Control
var title: Label
var status: Label
var scenario_name: LineEdit
var notes: TextEdit
var board_width: SpinBox
var board_depth: SpinBox
var starting_round: SpinBox
var starting_phase: OptionButton
var starting_team: OptionButton
var start_deployment: CheckBox
var properties: VBoxContainer
var fields: Dictionary = {}
var save_dialog: ConfirmationDialog
var save_name: LineEdit
var placement_count: SpinBox

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = AppUI.theme()
	add_child(root)
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 350
	panel.offset_bottom = -65
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = 280
	scroll.add_child(column)
	title = AppUI.label(column, "SCENARIO EDITOR", 20)
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	for i in 6:
		AppUI.button(grid, ["Select / Move", "Place Terrain", "Place Objective", "Place Unit", "Deployment Zone", "Delete"][i], func(): editor.set_tool(i))
	AppUI.label(column, "TERRAIN PALETTE", 13)
	var terrain := AppUI.choices(column, ["Wall", "Ruin", "Crates", "Barricade", "Block"])
	terrain.item_selected.connect(func(index: int): editor.terrain_index = index; editor.set_tool(1))
	AppUI.label(column, "UNIT PALETTE", 13)
	var labels: Array[String] = []
	for path in ScenarioEditor.PROFILES:
		var definition: Dictionary = ContentRegistry.read_json(path)
		labels.append((str(definition.get("id", "grimtable")).get_slice(":", 0) if ":" in str(definition.get("id", "")) else "GRIMTABLE") + " / " + str(definition.get("faction", "generic")).to_upper() + " / " + str(definition.name))
	var units := AppUI.choices(column, labels)
	units.item_selected.connect(func(index: int):
		editor.profile_index = index
		placement_count.value = 1 if float(ContentRegistry.unit({"profile": ScenarioEditor.PROFILES[index]}).get("max_wounds", 2)) >= 5 else 5
		editor.unit_count = int(placement_count.value)
		editor.set_tool(3))
	placement_count = AppUI.spin(column, "Models to place", 5, 1, 20)
	placement_count.value_changed.connect(func(value: float): editor.unit_count = int(value); editor._build_preview())
	var teams := AppUI.choices(column, ["Place as Team A", "Place as Team B"])
	teams.item_selected.connect(func(index: int): editor.team = index)
	AppUI.button(column, "R / Shift+Wheel: rotate 15°", func(): editor.rotate_selection(15))
	AppUI.button(column, "Delete Selected", editor.delete_selected)
	properties = VBoxContainer.new()
	column.add_child(properties)
	column.add_child(HSeparator.new())
	scenario_name = AppUI.text(column, "SCENARIO NAME", editor.document.name)
	AppUI.label(column, "Notes", 13)
	notes = TextEdit.new()
	notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notes.custom_minimum_size.y = 75
	notes.text = editor.document.get("notes", "")
	column.add_child(notes)
	board_width = AppUI.spin(column, "Board width (in)", editor.document.board.width, 12, 120)
	board_depth = AppUI.spin(column, "Board depth (in)", editor.document.board.depth, 12, 120)
	starting_round = AppUI.spin(column, "Starting round", editor.document.starting_state.round, 1, 10000)
	starting_phase = AppUI.choices(column, GameManager.PHASES, int(editor.document.starting_state.phase))
	starting_team = AppUI.choices(column, ["Start: Team A", "Start: Team B"], int(editor.document.starting_state.team))
	start_deployment = CheckBox.new()
	start_deployment.text = "Start in deployment"
	start_deployment.button_pressed = editor.document.starting_state.deployment
	column.add_child(start_deployment)
	AppUI.button(column, "Apply Scenario Properties", apply_metadata)
	var toolbar := PanelContainer.new()
	root.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_left = 365
	toolbar.offset_top = 16
	toolbar.offset_right = -16
	toolbar.offset_bottom = 86
	var actions := AppUI.row(toolbar)
	AppUI.button(actions, "Save Scenario", func():
		if apply_metadata():
			if editor.path.begins_with("user://"): editor.save_scenario()
			else: _save_as())
	AppUI.button(actions, "Save As", _save_as)
	AppUI.button(actions, "Play Scenario", func():
		if apply_metadata(): play_requested.emit())
	AppUI.button(actions, "Main Menu", func(): exit_requested.emit())
	status = AppUI.label(root, "Editor: choose a tool, then click on the table. Esc cancels.", 15)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_left = 20
	status.offset_top = -50
	status.offset_right = -20
	status.offset_bottom = -15
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_dialog = ConfirmationDialog.new()
	save_dialog.title = "Save Scenario As"
	save_dialog.visible = false
	save_name = LineEdit.new()
	save_name.custom_minimum_size = Vector2(380, 40)
	save_dialog.add_child(save_name)
	save_dialog.confirmed.connect(func():
		if apply_metadata():
			var result := editor.save_scenario(save_name.text)
			if result.begins_with("Saved"): scenario_name.text = editor.document.name)
	root.add_child(save_dialog)
	editor.message.connect(func(text: String): status.text = text)
	editor.changed.connect(refresh)
	refresh()

func _save_as() -> void:
	save_name.text = scenario_name.text
	save_dialog.popup_centered(Vector2i(420, 140))

func apply_metadata() -> bool:
	editor.cancel_drag()
	var data := ScenarioFactory.capture(editor.game)
	data.name = scenario_name.text.strip_edges()
	data.notes = notes.text
	data.board = {"width": board_width.value, "depth": board_depth.value}
	data.starting_state = {"round": int(starting_round.value), "phase": starting_phase.selected, "team": starting_team.selected, "deployment": start_deployment.button_pressed}
	return editor.commit(data)

func refresh() -> void:
	title.text = "EDITOR · " + ["SELECT", "TERRAIN", "OBJECTIVE", "UNIT", "ZONE", "DELETE"][editor.tool] + (" *" if editor.dirty else "")
	for child in properties.get_children():
		properties.remove_child(child)
		child.queue_free()
	fields.clear()
	var data := ScenarioFactory.capture(editor.game)
	var record := ScenarioEditor.find_record(data, editor.selected_kind, editor.selected_id)
	if record.is_empty():
		AppUI.label(properties, "No selected object", 14)
		return
	AppUI.label(properties, "SELECTED " + editor.selected_kind.to_upper(), 14)
	if editor.selected_kind != "model": fields["name"] = AppUI.text(properties, "Name", record.get("title", record.get("name", "")))
	var position := Vector3.ZERO
	if editor.selected_kind == "deployment_zones": position = Vector3(float(record.center[0]), 0, float(record.center[1]))
	elif editor.selected_kind == "armies":
		for model: Dictionary in record.models: position += ScenarioFactory.vector(model.position)
		position /= maxf(1, record.models.size())
	else: position = ScenarioFactory.vector(record.position)
	fields["x"] = AppUI.spin(properties, 'X (in)', position.x, -60, 60, 0.1)
	fields["z"] = AppUI.spin(properties, 'Z (in)', position.z, -60, 60, 0.1)
	if editor.selected_kind in ["armies", "deployment_zones"]: fields["team"] = AppUI.choices(properties, ["Team A", "Team B"], int(record.team))
	if editor.selected_kind in ["terrain", "deployment_zones"]:
		fields["width"] = AppUI.spin(properties, 'Width (in)', record.size[0], 0.1, 120, 0.1)
		fields["depth"] = AppUI.spin(properties, 'Depth (in)', record.size[2] if editor.selected_kind == "terrain" else record.size[1], 0.1, 120, 0.1)
	if editor.selected_kind == "terrain":
		fields["height"] = AppUI.spin(properties, 'Height (in)', record.size[1], 0.1, 30, 0.1)
		fields["rotation"] = AppUI.spin(properties, "Rotation (degrees)", record.rotation, -36000, 36000, 15)
		for key in ["blocks_movement", "blocks_los"]:
			var check := CheckBox.new()
			check.text = key.replace("_", " ").capitalize()
			check.button_pressed = record[key]
			properties.add_child(check)
			fields[key] = check
	if editor.selected_kind == "objectives":
		fields["number"] = AppUI.spin(properties, "Number", record.number, 1, 999)
		fields["radius"] = AppUI.spin(properties, 'Radius (in)', record.radius, 0.1, 30, 0.1)
	AppUI.button(properties, "Apply Selected Properties", apply_selected)

func apply_selected() -> void:
	editor.cancel_drag()
	var data := ScenarioFactory.capture(editor.game)
	var record := ScenarioEditor.find_record(data, editor.selected_kind, editor.selected_id)
	if record.is_empty(): return
	var point := Vector3(fields.x.value, 0, fields.z.value)
	if editor.selected_kind == "deployment_zones":
		record.center = [point.x, point.z]
		record.size = [fields.width.value, fields.depth.value]
	elif editor.selected_kind == "armies":
		var center := Vector3.ZERO
		for model: Dictionary in record.models: center += ScenarioFactory.vector(model.position)
		center /= maxf(1, record.models.size())
		for model: Dictionary in record.models: model.position = ScenarioFactory.array(ScenarioFactory.vector(model.position) + point - center)
	else: record.position = ScenarioFactory.array(point)
	if fields.has("name"): record["title" if editor.selected_kind == "terrain" else "name"] = fields.name.text
	if fields.has("team"): record.team = fields.team.selected
	if editor.selected_kind == "terrain":
		record.size = [fields.width.value, fields.height.value, fields.depth.value]
		record.rotation = fields.rotation.value
		record.blocks_movement = fields.blocks_movement.button_pressed
		record.blocks_los = fields.blocks_los.button_pressed
	if editor.selected_kind == "objectives":
		record.number = int(fields.number.value)
		record.radius = fields.radius.value
	editor.commit(data)
