class_name PhaseTimeline
extends HBoxContainer

var current := 0

func _ready() -> void:
	resized.connect(queue_redraw)
	custom_minimum_size.y = 34

func _draw() -> void:
	if get_child_count() < 5: return
	var centers: Array[Vector2] = []
	for i in 5:
		var child := get_child(i) as Control
		centers.append(Vector2(child.position.x + child.size.x / 2, 5))
	for i in 4: draw_line(centers[i], centers[i+1], GrimTheme.PLAYER.darkened(.4) if i < current else GrimTheme.LINE, 1.5, true)
	for i in 5:
		draw_circle(centers[i], 4 if i == current else 2.5, GrimTheme.PLAYER if i <= current else GrimTheme.LINE)
		if i == current: draw_arc(centers[i], 7, 0, TAU, 24, Color(.44,.8,.74,.3), 1, true)
