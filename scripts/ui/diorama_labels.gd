class_name DioramaLabels
extends Control

# One screen-space layout pass for squads/objectives. Cosmetic only; no LOS rays.
var game: Node3D
var items: Dictionary = {}
var squad_labels: Dictionary = {}
var leaders: Array = []
var revision := 0
var last_stamp: Array = []
var last_rects: Array[Rect2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -1
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func badge(key: Node3D, point: Vector3, title: String, team: int, priority: int) -> Label:
	var created := not items.has(key)
	if not items.has(key):
		var plate := PanelContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(plate)
		var caption := Label.new()
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.add_theme_font_size_override("font_size", 13)
		plate.add_child(caption)
		items[key] = {"plate":plate,"caption":caption,"point":point,"title":title,"team":team,"priority":priority}
	var item: Dictionary = items[key]
	if not created and item.title == title and item.point == point and item.team == team and item.priority == priority: return item.caption
	item.point = point
	item.title = title
	item.team = team
	item.priority = priority
	var color := GrimTheme.PLAYER if team == 0 else GrimTheme.ENEMY if team == 1 else GrimTheme.IVORY
	var style := GrimTheme.surface(color.darkened(.3), true)
	style.border_width_top = 1
	style.border_width_left = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.shadow_size = 3
	item.plate.add_theme_stylebox_override("panel",style)
	item.caption.text = title
	revision += 1
	return item.caption

func update_squad(unit: TableUnit, ready: bool, selected: bool, us: int) -> Label:
	var alive := unit.living_models()
	var title := unit.display_name + " · %d   %s" % [alive.size(), "YOU" if unit.team == us else "ENEMY"]
	if game.camera_rig.distance < 28: title += "\n" + ("✓ Completed" if not ready else "○ Ready to act")
	var point := FormationPlanner.center(alive) + Vector3.UP * (float(unit.definition.get("gameplay_height",1.9)) + .5)
	var caption := badge(unit, point, title, 0 if unit.team == us else 1, 0 if selected else 1 if not alive.is_empty() and alive[0].target_candidate else 3)
	items[unit].alive = not alive.is_empty()
	squad_labels[unit] = caption
	return caption

func layout_labels() -> void:
	if not is_instance_valid(game) or not game.is_inside_tree(): return
	var camera: Camera3D = game.camera_rig.camera
	var current := [camera.global_transform, game.camera_rig.distance, revision, game.battlefield.spatial_revision, get_viewport_rect().size]
	if current == last_stamp: return
	last_stamp = current
	for key in items.keys():
		if not is_instance_valid(key):
			if is_instance_valid(items[key].plate): items[key].plate.queue_free()
			items.erase(key)
			squad_labels.erase(key)
	for objective: TableObjective in game.battlefield.objectives.get_children():
		var control: Dictionary = game.battlefield.control_for(objective)
		var owner: int = control.owner
		var us: int = game.guidance.player_team()
		var text := "◇ %d  %s" % [objective.number, "Neutral" if owner < 0 and control.counts["0"] + control.counts["1"] == 0 else "Contested" if owner < 0 else "YOU" if owner == us else "ENEMY"]
		badge(objective, objective.global_position + Vector3.UP * 2.2, text, -1 if owner < 0 else 0 if owner == us else 1, 2)
		objective.marker_label.hide()
	var sorted := items.keys()
	sorted.sort_custom(func(a,b): return int(items[a].priority) < int(items[b].priority) if items[a].priority != items[b].priority else str(a.name) < str(b.name))
	var occupied: Array[Rect2] = []
	for panel: Control in [game.hud.sidebar,game.assistance.quick_card,game.guidance.hint_card]:
		if panel.is_visible_in_tree(): occupied.append(panel.get_global_rect())
	leaders.clear()
	var area := Rect2(Vector2(24,132),get_viewport_rect().size-Vector2(48,252))
	for key in sorted:
		var item: Dictionary = items[key]
		var plate: PanelContainer = item.plate
		plate.hide()
		if not item.get("alive", true) or camera.is_position_behind(item.point): continue
		var anchor := camera.unproject_position(item.point)
		if not area.grow(100).has_point(anchor): continue
		var far: bool = game.camera_rig.distance > 64 and key is TableUnit
		item.caption.text = str(key.definition.get("faction", "SQ")).left(2).to_upper() + " · " + str(key.living_models().size()) if far else item.title
		var extent := plate.get_combined_minimum_size()
		plate.size = extent
		for offset in [Vector2(-extent.x/2,-extent.y-12),Vector2(-extent.x/2,-extent.y-40),Vector2(-extent.x-18,-extent.y),Vector2(18,-extent.y),Vector2(-extent.x/2,18),Vector2(-extent.x/2,-extent.y-72)]:
			var rect := Rect2(anchor+offset,extent)
			if not area.encloses(rect): continue
			if occupied.any(func(other): return other.grow(5).intersects(rect)): continue
			plate.position = rect.position
			plate.show()
			occupied.append(rect)
			if offset.y < -extent.y-20 or abs(offset.x+extent.x/2) > 10: leaders.append([anchor,rect.get_center()])
			break
	last_rects = []
	for item: Dictionary in items.values():
		if item.plate.visible: last_rects.append(item.plate.get_global_rect())
	queue_redraw()

func _draw() -> void:
	for leader in leaders: draw_line(leader[0],leader[1],Color(.6,.7,.71,.36),1,true)
