class_name UnitCard
extends VBoxContainer

signal inspect_requested

var scale_factor := 1.0
var heading: Label
var subtitle: Label
var count: Label
var values: Array[Label] = []
var weapons: Label
var state: Label

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	var row := AppUI.row(self)
	heading = make_label(row, "", GrimTheme.HEADING)
	heading.add_theme_font_override("font", preload("res://assets/third_party/fonts/barlow/barlow_semibold.ttf"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	count = make_label(row, "", 18)
	subtitle = make_label(self, "", 13)
	subtitle.modulate = GrimTheme.MUTED
	add_child(HSeparator.new())
	var stats := AppUI.row(self)
	for title in ["MOVE", "HEALTH", "ARMOR"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(column)
		make_label(column, title, 11).modulate = GrimTheme.MUTED
		values.append(make_label(column, "", 25))
	add_child(HSeparator.new())
	weapons = make_label(self, "", 14)
	weapons.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state = make_label(self, "", 12)
	state.modulate = GrimTheme.PLAYER
	AppUI.button(self,"Inspect Miniature",func(): inspect_requested.emit())

func show_unit(unit: TableUnit, actions: Dictionary) -> void:
	if unit == null: hide(); return
	show()
	heading.text = unit.display_name
	subtitle.text = str(unit.definition.get("name", "Squad"))
	count.text = "%d / %d" % [unit.living_models().size(), unit.models.size()]
	values[0].text = str(unit.definition.get("movement", 6)).trim_suffix(".0") + '"'
	values[1].text = str(int(unit.definition.get("max_wounds", unit.definition.get("wounds", 1))))
	values[1].tooltip_text = "Health per model. Damaged models are marked on the board."
	values[2].text = str(int(unit.definition.get("save", 3))) + "+"
	values[2].tooltip_text = "Armor: save characteristic. We calculate penetration and cover for you."
	var lines := PackedStringArray()
	for weapon in unit.weapon_profiles:
		lines.append('%s\n%s"  ·  A%d  ·  Accuracy %d+' % [weapon.name, str(weapon.range).trim_suffix(".0"), weapon.attacks, weapon.hit])
	weapons.text = "\n\n".join(lines)
	state.text = ("✓ Moved" if int(actions.get("moved",0)) > 0 else "○ Ready to move") + "    " + ("✓ Attacked" if int(actions.get("ranged",0))+int(actions.get("melee",0)) > 0 else "")


func make_label(parent: Node, caption: String, size: int) -> Label:
	return AppUI.label(parent,caption,roundi(size*scale_factor))
