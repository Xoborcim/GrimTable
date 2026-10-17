class_name InteractionController
extends Node3D

var damage_click: Callable
var last_formation: Dictionary = {}

signal status_changed(message: String)
signal mode_changed(mode_name: String)
signal target_changed(message: String)
signal movement_changed
signal target_selected(model: Miniature)

enum InteractionMode { SELECT, MOVE, MEASURE, TARGET }
var mode := InteractionMode.SELECT
var board: Battlefield
var rig: TableCamera
var selection: SelectionManager
var setup_mode := false
var dragging: Miniature
var drag_object: Node3D
var drag_origin := Vector3.ZERO
var drag_offset := Vector3.ZERO
var drag_error := ""
var measure_start: Variant = null
var measure_end := Vector3.ZERO
var measure_locked := false
var overlay: Node3D
var hover_ring: MeshInstance3D
var range_circle: MeshInstance3D
var _line_signature: Array = []
var tool_line: MeshInstance3D
var floating: Label3D
var target_model: Miniature
var objective_selected: TableObjective
var hovered_objective: TableObjective
var debug_enabled := false
var show_los := true
var pointer := Vector2.ZERO
var history: ActionHistory
var deployment: DeploymentManager
var session: SquadMoveSession
var move_preview: SquadMovePreview
var manual_override := false
var read_only := false
var editor: Node
var precision := 1
var can_control: Callable
var _target_layout: Array = []
var quick_anchor := false
var quick_layout := "Auto"
var last_problem := {}

func _ready() -> void:
	pointer = get_viewport().get_mouse_position()
	overlay = Node3D.new()
	add_child(overlay)
	floating = TableVisuals.label(overlay, "", Vector3.ZERO)
	floating.font_size = 28
	floating.pixel_size = .011
	hover_ring = TableVisuals.ring(overlay, 1, Color("91aebe"), .21)
	hover_ring.visible = false
	selection.changed.connect(func():
		cancel()
		if mode == InteractionMode.MOVE: begin_unit_move())

func set_mode(value: int) -> void:
	cancel()
	mode = value as InteractionMode
	Input.set_default_cursor_shape(Input.CURSOR_MOVE if mode == 1 else Input.CURSOR_CROSS if mode in [2,3] else Input.CURSOR_ARROW)
	mode_changed.emit(["SELECT", "MOVE", "MEASURE", "TARGET"][mode])
	if mode == InteractionMode.MOVE: begin_unit_move()
	status_changed.emit(["Choose one of your squads to begin.", "Choose a destination, then confirm. Cancel restores your squad.", "Click a start point, then an end point to measure.", "Choose a highlighted enemy. Review the attack, then confirm."][mode])

func cancel() -> void:
	board.invalidate_spatial()
	quick_anchor = false
	last_formation = {}
	last_problem = {}
	_target_layout = []
	if dragging != null:
		dragging.global_position = drag_origin
		dragging.refresh()
	if drag_object != null: drag_object.global_position = drag_origin
	dragging = null
	drag_object = null
	if session != null:
		session.cancel()
		_close_session()
	measure_start = null
	measure_locked = false
	target_model = null
	if is_instance_valid(hover_ring): hover_ring.hide()
	if is_instance_valid(range_circle): range_circle.queue_free()
	range_circle = null
	_clear_line()
	if is_instance_valid(floating): floating.text = ""
	target_changed.emit("")
	movement_changed.emit()

func begin_unit_move() -> void:
	var unit := selection.selected_unit()
	if session != null or unit == null: return
	if can_control.is_valid() and not can_control.call(unit.team):
		status_changed.emit("Select your own unit during your turn")
		return
	session = SquadMoveSession.new(unit, board, deployment)
	move_preview = SquadMovePreview.new()
	move_preview.session = session
	add_child(move_preview)
	movement_changed.emit()

func confirm_unit_move() -> bool:
	if session == null or dragging != null: return false
	var error := session.validation_error(manual_override)
	if not error.is_empty():
		status_changed.emit(error)
		return false
	if not session.charge_target.is_empty():
		var target := NetworkAuthority.unit(board.get_parent(), session.charge_target)
		if target == null or ChargeRules.required(session.unit, target, ChargeRules.reach(board.get_parent())) > .001:
			status_changed.emit("Finish within engagement range of the chosen charge target.")
			return false
	var action := session.action()
	action.metadata["coherency_override"] = manual_override
	action.metadata["coherent"] = CoherencyService.is_unit_coherent(session.unit)
	if not action.changes.is_empty() and history != null: history.perform(action)
	var was_quick := quick_anchor
	_close_session()
	if was_quick:
		quick_anchor = false
		mode = InteractionMode.SELECT
		mode_changed.emit("SELECT")
	status_changed.emit("Unit movement confirmed")
	return true

func _close_session() -> void:
	if is_instance_valid(move_preview):
		move_preview.clear_highlights()
		remove_child(move_preview)
		move_preview.queue_free()
	move_preview = null
	session = null
	movement_changed.emit()

func record_move(object: Node3D, before: Vector3, title: String) -> void:
	if history == null or object.global_position.is_equal_approx(before): return
	var id := str(object.name)
	if object is Miniature: id = object.model_id
	if object is TableObjective: id = object.object_id
	if object is TerrainPiece: id = object.object_id
	var changes: Array[Dictionary] = [{"object": object, "id": id, "property": "global_position", "before": before, "after": object.global_position}]
	history.perform(GameAction.new(title, "move", changes))

func _clear_line() -> void:
	_line_signature = []
	if is_instance_valid(tool_line):
		remove_child(tool_line)
		tool_line.queue_free()
	tool_line = null

func _draw_line(a: Vector3, b: Vector3, color: Color) -> void:
	if is_instance_valid(tool_line) and _line_signature == [a, b, color]: return
	_clear_line()
	_line_signature = [a, b, color]
	tool_line = TableVisuals.line(self, PackedVector3Array([a, b]), color)
	for endpoint in [a, b]:
		var marker := TableVisuals.ring(tool_line, .17, color, .06)
		marker.position += endpoint

func pick(screen: Vector2, mask: int = 10) -> Node3D:
	var camera := rig.camera
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * 300, mask)
	return get_world_3d().direct_space_state.intersect_ray(query).get("collider") as Node3D

func _process(_delta: float) -> void:
	if read_only: return
	if editor != null and editor.enabled:
		editor.update_pointer(pointer)
		return
	var primary := selection.primary()
	if mode == InteractionMode.TARGET and target_model != null and primary != null:
		var layout := [primary.model_id, target_model.model_id, primary.global_position, target_model.global_position, board.spatial_revision]
		if layout != _target_layout:
			_target_layout = layout
			update_target(primary, target_model)
	var mouse := pointer
	var point: Variant = MeasurementService.tabletop_point(rig.camera, mouse)
	if point == null: return
	if dragging != null:
		var destination: Vector3 = point + drag_offset
		destination.y = 0
		if session != null: drag_error = session.preview_error(dragging, drag_origin, destination)
		elif deployment != null and deployment.manager.deployment: drag_error = deployment.placement_error(dragging, destination)
		else: drag_error = MovementService.move_error(board, dragging, drag_origin, destination)
		if not dragging.global_position.is_equal_approx(destination): board.invalidate_spatial()
		dragging.global_position = destination
		var color := Color("6aebc0") if drag_error.is_empty() else Color("ff7272")
		dragging.base_mesh.material_override = TableVisuals.material(color)
		_draw_line(drag_origin + Vector3.UP * 0.2, destination + Vector3.UP * 0.2, color)
		floating.position = destination + Vector3.UP * 3
		floating.text = '%.1f" / %.0f" · %s' % [MeasurementService.horizontal_distance(drag_origin, destination), dragging.movement, "VALID" if drag_error.is_empty() else drag_error]
		if session != null:
			var used := session.route_cost(dragging)
			floating.text = '%.1f" left · %s' % [maxf(0, session.limit(dragging) - used), "VALID" if drag_error.is_empty() else drag_error]
			var label := move_preview.labels.get(dragging) as Label3D
			if label != null: label.visible = false
		if deployment != null and deployment.manager.deployment: floating.text = "DEPLOY · " + ("VALID" if drag_error.is_empty() else drag_error)
		movement_changed.emit()
		return
	if drag_object != null:
		var destination: Vector3 = point + drag_offset
		var margin := 1.0
		if drag_object is TableObjective: margin = drag_object.radius
		if drag_object is TerrainPiece: margin = maxf(drag_object.size.x, drag_object.size.z) / 2
		board.invalidate_spatial()
		drag_object.position = Vector3(clampf(destination.x, -board.width / 2 + margin, board.width / 2 - margin), 0, clampf(destination.z, -board.depth / 2 + margin, board.depth / 2 - margin))
		return
	if mode == InteractionMode.MEASURE and measure_start != null:
		if not measure_locked: measure_end = _clamp_to_board(point)
		_draw_line(measure_start + Vector3.UP * 0.25, measure_end + Vector3.UP * 0.25, Color("f4dc8a"))
		floating.position = (measure_start + measure_end) / 2 + Vector3.UP * 1.2
		floating.text = '%.1f"%s' % [MeasurementService.horizontal_distance(measure_start, measure_end), " · LOCKED" if measure_locked else ""]
		floating.text = String.num(MeasurementService.horizontal_distance(measure_start, measure_end), precision) + '"' + (" · LOCKED" if measure_locked else "")
		return
	var over_ui := get_viewport().gui_get_hovered_control() != null
	if session != null and quick_anchor:
		hover_ring.visible = not over_ui
		hover_ring.position = point + Vector3.UP * .1
		hover_ring.scale = Vector3.ONE
		floating.position = point + Vector3.UP * 1.6
		var center := Vector3.ZERO
		for origin: Vector3 in session.origins.values(): center += origin
		center /= maxi(1, session.origins.size())
		floating.text = 'Move here · %.1f" / %.0f"\nClick to preview' % [MeasurementService.horizontal_distance(center, point), session.limit(session.unit.models[0])]
		if over_ui: floating.text = ""
		return
	var hovered := null if over_ui else pick(mouse)
	if hovered_objective != null and hovered_objective != objective_selected: hovered_objective.radius_ring.visible = hovered_objective.context_radius
	hovered_objective = hovered as TableObjective
	if hovered_objective != null:
		hovered_objective.radius_ring.visible = true
		var control := board.control_for(hovered_objective)
		floating.position = hovered_objective.global_position + Vector3.UP * 4.6
		floating.text = 'Objective %d\n%s\nMove units here to score points.' % [hovered_objective.number, "Neutral" if control.owner < 0 else "Your team" if control.owner == 0 else "Enemy"]
		status_changed.emit('OBJECTIVE %d | %s: %d | %s: %d | %s' % [hovered_objective.number, ObjectiveControl.team_name(board.units.get_children(), 0), control.counts["0"], ObjectiveControl.team_name(board.units.get_children(), 1), control.counts["1"], "Contested / neutral" if control.owner < 0 else "Controlled by " + ObjectiveControl.team_name(board.units.get_children(), control.owner)])
	hover_ring.visible = hovered is Miniature
	if hovered is Miniature:
		hover_ring.position = hovered.global_position
		hover_ring.scale = Vector3(hovered.base_radius + .1, 1, hovered.base_radius + .1)
		var unit := hovered.get_parent() as TableUnit
		floating.text = "%s\n%d %s · %s" % [unit.display_name, unit.living_models().size(), hovered.display_name, "Your team" if hovered.team == (0 if board.get_parent().network_session == null or board.get_parent().network_session.host else 1) else "Enemy"]
		if hovered.damage_recipient: floating.text = hovered.display_name + "\nClick to give this model damage."
		if mode == InteractionMode.TARGET and not hovered.target_hint.is_empty(): floating.text += "\n" + hovered.target_hint
		elif hovered.phase_ready: floating.text += " · Ready to act"
		floating.position = hovered.global_position + Vector3.UP * (float(hovered.profile.get("gameplay_height", 1.9)) + 0.8)
	elif hovered_objective == null: floating.text = ""

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer = event.position
	if read_only: return
	if editor != null and editor.enabled:
		editor.handle_release(event)
		return
	# Finish drag even when the release occurs over the HUD.
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if dragging != null or drag_object != null: _process(0)
		if dragging != null:
			if not drag_error.is_empty(): dragging.global_position = drag_origin
			elif session != null: session.stage(dragging, drag_origin)
			else: record_move(dragging, drag_origin, "Move " + dragging.model_id)
			if move_preview != null:
				var label := move_preview.labels.get(dragging) as Label3D
				if label != null: label.visible = true
			status_changed.emit("Move placed" if drag_error.is_empty() else "Move rejected: " + drag_error)
			dragging.refresh()
			dragging = null
			_clear_line()
			floating.text = ""
			if is_instance_valid(range_circle): range_circle.queue_free()
			range_circle = null
			movement_changed.emit()
		if drag_object != null:
			var error := ""
			if drag_object is TerrainPiece:
				for model: Miniature in get_tree().get_nodes_in_group("miniatures"):
					if not model.removed and drag_object.overlaps_base(model.global_position, model.base_radius): error = "Terrain overlaps a model"
			if not error.is_empty(): drag_object.position = drag_origin
			else: record_move(drag_object, drag_origin, "Reposition " + str(drag_object.name))
			status_changed.emit("Setup placement saved" if error.is_empty() else error)
			drag_object = null

func _unhandled_input(event: InputEvent) -> void:
	if read_only: return
	if editor != null and editor.enabled:
		editor.handle_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: set_mode(0)
			KEY_2: set_mode(1)
			KEY_3, KEY_M: set_mode(2)
			KEY_4: set_mode(3)
			KEY_ESCAPE: cancel(); set_mode(0)
			KEY_F:
				if selection.primary() != null: rig.focus(selection.primary().global_position)
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	get_viewport().gui_release_focus()
	var point: Variant = MeasurementService.tabletop_point(rig.camera, event.position)
	if point == null: return
	if quick_anchor and session != null:
		preview_destination(point)
		return
	var hit := pick(event.position, 14 if setup_mode else 10)
	if setup_mode and (hit is TableObjective or hit is TerrainPiece):
		if session != null:
			status_changed.emit("Confirm or cancel unit movement first")
			return
		drag_object = hit
		drag_origin = hit.global_position
		drag_offset = drag_origin - point
		if hit is TableObjective: _select_objective(hit)
		return
	if mode == InteractionMode.MEASURE:
		if measure_start == null or measure_locked:
			measure_start = _clamp_to_board(point)
			measure_end = measure_start
			measure_locked = false
		else:
			measure_end = _clamp_to_board(point)
			measure_locked = true
		return
	if hit is TableObjective:
		_select_objective(hit)
		return
	if objective_selected != null:
		objective_selected.radius_ring.visible = false
		objective_selected = null
	var model := hit as Miniature
	if model != null and damage_click.is_valid() and damage_click.call(model): return
	if mode == InteractionMode.TARGET:
		var primary := selection.primary()
		if model != null and primary != null and model.team != primary.team:
			target_model = model
			update_target(primary, model)
			target_selected.emit(model)
		elif model != null: selection.select_from_click(model, false, event.alt_pressed)
		return
	if mode == InteractionMode.MOVE:
		if model == null: return
		if can_control.is_valid() and not can_control.call(model.team):
			status_changed.emit("Select your own model during your turn")
			return
		if session != null and not session.origins.has(model):
			status_changed.emit("Confirm or cancel this unit's movement first")
			return
		if session == null and not selection.models.has(model): selection.select_from_click(model, false, event.alt_pressed)
		if session == null and selection.selected_unit() != null: begin_unit_move()
		if model.wounds == 0:
			status_changed.emit("Defeated models cannot move. Restore wounds first.")
			return
		dragging = model
		drag_origin = model.global_position
		drag_offset = drag_origin - point
		drag_error = ""
		range_circle = TableVisuals.ring(self, model.movement, Color("78d8c5"))
		range_circle.position = drag_origin
		range_circle.visible = deployment == null or not deployment.manager.deployment
		return
	selection.select_from_click(model, event.shift_pressed, event.alt_pressed)

func _select_objective(objective: TableObjective) -> void:
	if objective_selected != null: objective_selected.radius_ring.visible = false
	objective_selected = objective
	objective.radius_ring.visible = true
	status_changed.emit('Objective %d • Control radius %.0f"' % [objective.number, objective.radius])

func _clamp_to_board(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, -board.width / 2, board.width / 2), 0, clampf(point.z, -board.depth / 2, board.depth / 2))

func update_target(attacker: Miniature, target: Miniature) -> void:
	if target.removed:
		cancel()
		return
	var result := MeasurementService.line_of_sight(get_world_3d(), attacker, target)
	var distance := MeasurementService.distance_between_bases(attacker, target)
	var obstruction := ""
	if not result.clear: obstruction = "\nObstruction: " + result.obstacle.title
	target_changed.emit('TARGET  %s\n%s\nBase distance  %.1f"\nLOS  %s%s\n\n%s · %.0f"\n%s' % [target.model_id, target.unit_name, distance, "CLEAR" if result.clear else "BLOCKED", obstruction, attacker.weapon.get("name", "Weapon"), attacker.weapon.get("range", 0), "IN RANGE" if distance <= float(attacker.weapon.get("range", 0)) else "OUT OF RANGE"])
	if show_los:
		_draw_line(attacker.eye(), target.eye(), Color("78e7bd") if result.clear else Color("ff7878"))
	else: _clear_line()

# Propose a nearby regular grid only. Existing movement/coherency validation and
# confirmation still apply; rejected proposals restore the previous positions.
func auto_arrange(layout: String = "Auto", anchor: Variant = null) -> bool:
	var unit := selection.selected_unit()
	if unit == null: return false
	if can_control.is_valid() and not can_control.call(unit.team): return false
	if session == null: set_mode(1)
	if session == null: return false
	var models := unit.living_models()
	if models.is_empty(): return false
	var center := Vector3.ZERO
	var before := {}
	var radius := 0.0
	for model in models:
		center += model.global_position
		before[model] = model.global_position
		radius = maxf(radius, model.base_radius)
	center /= models.size()
	if anchor is Vector3: center = anchor
	models.sort_custom(func(a: Miniature, b: Miniature):
		if not is_equal_approx(a.global_position.x, b.global_position.x): return a.global_position.x < b.global_position.x
		return a.model_id < b.model_id)
	var issue := "No formation fits"
	# Two fixed layouts; no target selection or tactical search.
	for columns in ([ceili(sqrt(models.size())), models.size()] if layout == "Auto" else [models.size()] if layout == "Line" else [ceili(models.size() / 2.0)] if layout == "Two Rows" else [ceili(sqrt(models.size()))]):
		var rows := ceili(float(models.size()) / columns)
		for i in models.size():
			models[i].global_position = center + Vector3((i % columns - (columns - 1) / 2.0) * (radius * 2 + 0.2), 0, (floori(float(i) / columns) - (rows - 1) / 2.0) * (radius * 2 + 0.2))
		issue = session.validation_error()
		for model in models:
			if issue.is_empty(): issue = session.preview_error(model, before[model], model.global_position)
		if issue.is_empty(): break
		for model in models: model.global_position = before[model]
	if not issue.is_empty():
		status_changed.emit("No legal nearby formation: " + issue)
		return false
	for model in models: session.stage(model, before[model])
	movement_changed.emit()
	status_changed.emit("Formation proposed. Confirm Move or Cancel Move.")
	return true

func auto_place_unit() -> bool:
	var unit := selection.selected_unit()
	if unit == null or deployment == null or not deployment.manager.deployment:
		status_changed.emit("Select a squad during deployment first")
		return false
	if can_control.is_valid() and not can_control.call(unit.team): return false
	for zone in deployment.zones:
		if not zone is RectangleDeploymentZone or zone.team != unit.team: continue
		# Fixed scan order, no tactical evaluation. Keep the first legal formation.
		for z in range(ceili(zone.center.y - zone.size.y / 2 + 2), floori(zone.center.y + zone.size.y / 2 - 1), 2):
			for x in range(ceili(zone.center.x - zone.size.x / 2 + 3), floori(zone.center.x + zone.size.x / 2 - 2), 3):
				if auto_arrange("Cluster", Vector3(x, 0, z)):
					status_changed.emit("Legal deployment proposed. Confirm Move or Cancel Move.")
					return true
	status_changed.emit("No legal deployment formation fits this zone")
	return false

func begin_quick_move(layout: String = "Auto") -> void:
	set_mode(1)
	quick_layout = layout
	quick_anchor = session != null and layout != "Manual"
	if quick_anchor and move_preview != null: move_preview.set_compact()
	status_changed.emit("Click a destination for your squad. Review the preview, then Confirm." if quick_anchor else "Move models individually, then Confirm.")

func preview_destination(anchor: Vector3) -> bool:
	if session == null: return false
	var result := FormationPlanner.propose(session, anchor, quick_layout)
	last_formation = result
	last_problem = {} if result.ok else result
	if move_preview != null: move_preview.show_failure(result)
	if result.ok:
		status_changed.emit("That exact position doesn't fit. Here's the closest legal formation. Confirm to use it, or click to adjust." if result.adjusted else "Squad fits here. Confirm, or click another destination.")
	else: status_changed.emit("This squad doesn't fit here. " + str(result.error) + " Try nearby, or use formation options to place manually.")
	movement_changed.emit()
	return result.ok
