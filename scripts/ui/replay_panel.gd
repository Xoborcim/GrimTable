class_name ReplayPanel
extends CanvasLayer

signal exit_requested
var controller: ReplayController
var timeline: HSlider
var caption: Label
var details: RichTextLabel

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = AppUI.theme()
	add_child(root)
	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = -165
	panel.offset_bottom = -16
	var column := VBoxContainer.new()
	panel.add_child(column)
	caption = AppUI.label(column, "REPLAY", 18)
	timeline = HSlider.new()
	timeline.step = 1
	timeline.max_value = controller.events.size()
	timeline.value_changed.connect(func(value: float): controller.seek(int(value)))
	column.add_child(timeline)
	var row := AppUI.row(column)
	AppUI.button(row, "|< Start", func(): controller.seek(0))
	AppUI.button(row, "< Previous", func(): controller.seek(controller.index - 1))
	AppUI.button(row, "Play", controller.play)
	AppUI.button(row, "Pause", controller.pause)
	AppUI.button(row, "Next >", func():
		controller.playing = false
		if controller.busy: controller.seek(controller.index)
		controller.step_forward())
	var speed := AppUI.choices(row, ["0.5x", "1x", "2x", "4x"], 1)
	speed.item_selected.connect(func(index: int): controller.speed = [0.5, 1.0, 2.0, 4.0][index])
	AppUI.button(row, "Main Menu", func(): exit_requested.emit())
	var info := PanelContainer.new()
	root.add_child(info)
	info.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	info.offset_left = -365
	info.offset_top = 16
	info.offset_right = -16
	info.offset_bottom = -185
	details = RichTextLabel.new()
	info.add_child(details)
	controller.changed.connect(refresh)
	refresh()

func refresh() -> void:
	timeline.set_value_no_signal(controller.index)
	var description := "Initial scenario"
	if controller.index > 0:
		var event: Dictionary = controller.events[controller.index - 1]
		description = event.kind + " · " + str(event.payload.get("title", event.payload.get("attacking_unit", "")))
	caption.text = "REPLAY · Action %d / %d · %s" % [controller.index, controller.events.size(), description]
	var state: Dictionary = controller.game.manager.snapshot()
	caption.text += "\nRound %d · %s · Team %s" % [state.round, "DEPLOYMENT" if state.deployment else GameManager.PHASES[int(state.phase)], "A" if state.team == 0 else "B"]
	details.text = "Recorded dice · no rerolls\n\n" + (CombatPanel.describe(controller.last_attack) if not controller.last_attack.is_empty() else "No attack has occurred yet.")
