class_name AppUI
extends RefCounted

static func theme() -> Theme:
	return GrimTheme.theme()

static func label(parent: Node, text: String, size: int = 16) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	parent.add_child(item)
	return item

static func button(parent: Node, text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.focus_mode = Control.FOCUS_NONE
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

static func row(parent: Node) -> HBoxContainer:
	var item := HBoxContainer.new()
	parent.add_child(item)
	return item

static func spin(parent: Node, text: String, value: float, minimum: float, maximum: float, step: float = 1) -> SpinBox:
	var container := row(parent)
	var caption := label(container, text)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var item := SpinBox.new()
	item.min_value = minimum
	item.max_value = maximum
	item.step = step
	item.value = value
	item.custom_minimum_size.x = 115
	container.add_child(item)
	return item

static func text(parent: Node, caption: String, value: String) -> LineEdit:
	label(parent, caption, 13)
	var item := LineEdit.new()
	item.text = value
	parent.add_child(item)
	return item

static func choices(parent: Node, values: Array, selected: int = 0) -> OptionButton:
	var item := OptionButton.new()
	for value in values: item.add_item(str(value))
	item.select(selected)
	parent.add_child(item)
	return item
