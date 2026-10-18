class_name WorkshopCursor
extends Control

var workshop: MiniatureWorkshop
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
	if workshop==null or workshop.category!="Paint" or workshop.mode not in ["Brush","Eraser"]:return
	var at:=get_local_mouse_position()
	if not Rect2(Vector2.ZERO,size).has_point(at):return
	draw_arc(at,workshop.brush_radius,0,TAU,48,Color(1,.9,.65,.9),1.2,true)
	draw_line(at-Vector2(3,0),at+Vector2(3,0),Color(1,.9,.65,.9),1,true)
	draw_line(at-Vector2(0,3),at+Vector2(0,3),Color(1,.9,.65,.9),1,true)
