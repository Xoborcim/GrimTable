class_name GrimTheme
extends RefCounted

const INK := Color("10191e")
const SURFACE := Color("17242b")
const LINE := Color("3a5059")
const TEXT := Color("e5e9e7")
const MUTED := Color("92a5aa")
const PLAYER := Color("71cbbd")
const ENEMY := Color("d5ac72")
const IVORY := Color("e3ddc5")
const WARNING := Color("e6a66b")
const INVALID := Color("e3736e")
const GAP := 8
const RADIUS := 7
const ICON_SIZE := 18
const DISPLAY := 38
const HEADING := 22
const BODY := 16
const META := 12
static var cached: Theme
static var icon_cache: Dictionary = {}

static func surface(accent: Color = LINE, compact: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.038, .065, .078, .95)
	style.border_color = accent
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(RADIUS)
	style.shadow_color = Color(0, 0, 0, .34)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 12 if compact else 18
	style.content_margin_right = style.content_margin_left
	style.content_margin_top = 8 if compact else 14
	style.content_margin_bottom = style.content_margin_top
	return style

static func primary() -> StyleBoxFlat:
	var style := surface(Color("7acaba"), true)
	style.bg_color = Color("28584f")
	style.shadow_size = 0
	return style

static func theme(scale: float = 1.0) -> Theme:
	if cached == null:
		cached = Theme.new()
		cached.default_font = preload("res://assets/third_party/fonts/barlow/barlow_regular.ttf")
		cached.default_font_size = BODY
		cached.set_font("font", "Button", preload("res://assets/third_party/fonts/barlow/barlow_semibold.ttf"))
		for type in ["Label", "Button", "CheckBox", "OptionButton", "RichTextLabel", "LineEdit", "SpinBox", "PopupMenu", "TooltipLabel"]:
			cached.set_color("font_color", type, TEXT)
		cached.set_stylebox("panel", "PanelContainer", surface())
		cached.set_stylebox("panel", "TooltipPanel", surface(LINE, true))
		cached.set_color("font_color", "TooltipLabel", TEXT)
		cached.set_font_size("font_size", "TooltipLabel", 14)
		cached.set_constant("separation", "VBoxContainer", GAP)
		cached.set_constant("separation", "HBoxContainer", GAP)
		cached.set_constant("line_spacing", "Label", 2)
		for type in ["Button", "OptionButton"]:
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				var style := surface(LINE, true)
				style.shadow_size = 0
				style.bg_color = Color("24343b") if state == "normal" else Color("344c51") if state == "hover" else Color("1b2d31") if state == "pressed" else Color("162329")
				if state == "disabled": style.border_color = Color("27373c")
				if state == "focus": style.bg_color = Color.TRANSPARENT; style.border_color = PLAYER
				cached.set_stylebox(state, type, style)
			cached.set_color("font_disabled_color", type, Color("65767c"))
			cached.set_constant("icon_max_width", type, ICON_SIZE)
		cached.set_font("normal_font", "RichTextLabel", cached.default_font)
		cached.set_font("bold_font", "RichTextLabel", preload("res://assets/third_party/fonts/barlow/barlow_semibold.ttf"))
	var result := cached.duplicate() as Theme
	result.default_font_size = roundi(BODY * scale)
	return result

static func icon(id: String) -> Texture2D:
	if not icon_cache.has(id):
		var path := "res://assets/grimtable/icons/" + id + ".svg"
		if ResourceLoader.exists(path): icon_cache[id] = load(path)
	return icon_cache.get(id)

static func enter(control: Control, reduced: bool = false) -> void:
	if reduced or not control.is_inside_tree(): return
	control.modulate.a = 0
	control.create_tween().tween_property(control, "modulate:a", 1.0, .16)
