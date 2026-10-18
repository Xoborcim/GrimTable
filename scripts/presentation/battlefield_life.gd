class_name BattlefieldLife
extends Node3D

var game: Node3D
var animations: Dictionary = {}
var clock := 0.0
var idle_clock := 0.0
var last_sequence := 0
var tactical := false
var overlay: Node3D
var overlay_stamp := -1
var hover: TerrainPiece
var terrain_card: PanelContainer
var terrain_text: Label
var hover_aim := Vector3.ZERO
var target_stamp: Array = []
var target_copy := ""
var terrain_visibility: Dictionary = {}

func _ready() -> void:
	overlay = Node3D.new()
	add_child(overlay)
	overlay.hide()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	terrain_card = PanelContainer.new()
	terrain_card.theme = GrimTheme.theme()
	terrain_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(terrain_card)
	terrain_text = AppUI.label(terrain_card,"",15)
	terrain_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain_card.hide()
	game.battle_log.changed.connect(events)

func ensure_models() -> void:
	var count := 0
	for unit: TableUnit in game.battlefield.units.get_children():
		for model in unit.models:
			count += 1
			if not animations.has(model.model_id) or not is_instance_valid(animations[model.model_id].model) or animations[model.model_id].model != model:
				animations[model.model_id] = UnitAnimationController.new(model)
	if count != animations.size():
		for id in animations.keys():
			if not is_instance_valid(animations[id].model): animations.erase(id)

func events() -> void:
	ensure_models()
	if game.battle_log.sequence < last_sequence: last_sequence = 0
	for entry in game.battle_log.entries:
		if int(entry.sequence) <= last_sequence: continue
		last_sequence = int(entry.sequence)
		if entry.kind == "attack":
			for id in entry.payload.eligible_models:
				if animations.has(id): animations[id].react(UnitAnimationController.State.ATTACKING)
		if entry.kind not in ["execute","redo","undo"]: continue
		for change in entry.payload.get("changes",[]):
			if not animations.has(change.id): continue
			var controller: UnitAnimationController = animations[change.id]
			if change.property == "global_position": controller.move_from(ScenarioFactory.vector(change.after if entry.kind == "undo" else change.before),game.settings.movement_speed,game.settings.reduce_motion)
			if change.property == "wounds": controller.react(UnitAnimationController.State.HIT)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_T and not event.echo:
		set_tactical(event.pressed and not game.menu_open)
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F7 and game.get("ai") != null:
		game.ai.debug_enabled = not game.ai.debug_enabled

func set_tactical(value: bool) -> void:
	if value == tactical: return
	tactical = value
	overlay.visible = value
	var ground:=game.battlefield.visuals.get_node_or_null("GroundSurface") as MeshInstance3D
	if ground!=null:(ground.material_override as ShaderMaterial).set_shader_parameter("grid_visibility",1.0 if value or game.editing else 0.0)
	if not value:
		for piece: TerrainPiece in game.battlefield.terrain.get_children(): piece.footprint_overlay.visible = terrain_visibility.get(piece.object_id,false)
		terrain_visibility.clear()
		for objective: TableObjective in game.battlefield.objectives.get_children(): objective.radius_ring.visible = objective.context_radius
	else:
		for piece: TerrainPiece in game.battlefield.terrain.get_children(): terrain_visibility[piece.object_id] = piece.footprint_overlay.visible
		rebuild_overlay()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and tactical: set_tactical(false)

func rebuild_overlay() -> void:
	for child in overlay.get_children(): overlay.remove_child(child); child.queue_free()
	for piece: TerrainPiece in game.battlefield.terrain.get_children():
		piece.footprint_overlay.show()
		var traits := PackedStringArray()
		if piece.blocks_movement: traits.append("BOUNDARY")
		if piece.blocks_los: traits.append("SIGHT BLOCK")
		if piece.cover_bonus > 0: traits.append("SHIELD +"+str(piece.cover_bonus))
		if piece.movement_penalty > 0: traits.append("SLOW +"+str(piece.movement_penalty))
		var label := TableVisuals.label(overlay," / ".join(traits),piece.global_position+Vector3.UP*(piece.size.y+.5),GrimTheme.IVORY)
		label.font_size = 22
		label.pixel_size = .012
	for objective: TableObjective in game.battlefield.objectives.get_children(): objective.radius_ring.show()
	for unit: TableUnit in game.battlefield.units.get_children():
		var models := unit.living_models()
		if models.is_empty(): continue
		var center := FormationPlanner.center(models)
		var ring := TableVisuals.ring(overlay,float(models[0].movement),GrimTheme.PLAYER if unit.team == game.manager.active_team else GrimTheme.ENEMY,.1)
		ring.position += center
		for index in range(1,models.size()): TableVisuals.line(overlay,PackedVector3Array([models[index-1].global_position+Vector3.UP*.3,models[index].global_position+Vector3.UP*.3]),GrimTheme.IVORY)
	overlay_stamp = game.battlefield.spatial_revision

func _process(delta: float) -> void:
	if game.menu_open:
		if tactical: set_tactical(false)
		terrain_card.hide()
		return
	clock += delta
	idle_clock += delta
	if idle_clock >= .10: ensure_models()
	var camera: Camera3D = game.camera_rig.camera
	var aiming: bool = game.interaction.mode == InteractionController.InteractionMode.TARGET
	for id in animations:
		var controller: UnitAnimationController = animations[id]
		var model := controller.model
		if not is_instance_valid(model) or model.removed: continue
		var active := controller.motion_left > 0 or controller.reaction > 0
		if not active and idle_clock < .10: continue
		if camera.is_position_behind(model.global_position) or camera.global_position.distance_to(model.global_position)>70:
			controller.motion_left = maxf(0,controller.motion_left-delta)
			controller.reaction = maxf(0,controller.reaction-delta)
			if controller.motion_left == 0: model.visual_root.position = controller.home
			continue
		var hovered: bool = game.interaction.hover_ring.visible and game.interaction.hover_ring.position.distance_to(model.global_position)<.2
		controller.aim = hover_aim if aiming and hover_aim != Vector3.ZERO else game.interaction.target_model.global_position if aiming and is_instance_valid(game.interaction.target_model) else Vector3.ZERO
		controller.update(delta if active else idle_clock,clock,game.settings.reduce_motion,hovered,aiming and model.selected)
	if idle_clock < .10: return
	idle_clock = 0
	for steam: CPUParticles3D in get_tree().get_nodes_in_group("ambient_steam"):
		steam.emitting = game.settings.particles and game.settings.quality != "Low" and not game.settings.reduce_motion
	if tactical and game.battlefield.spatial_revision != overlay_stamp: rebuild_overlay()
	if get_viewport().gui_get_hovered_control() != null or game.replay_mode or game.editing:
		terrain_card.hide()
		return
	hover_aim = Vector3.ZERO
	if aiming and game.selection.selected_unit() != null:
		var target := game.interaction.pick(game.interaction.pointer,26) as Miniature
		var attacker: TableUnit = game.selection.selected_unit()
		if target != null and target.team != attacker.team:
			hover_aim = target.global_position
			var defender := target.get_parent() as TableUnit
			var stamp := [str(attacker.name),str(defender.name),game.battlefield.spatial_revision,game.manager.phase]
			if stamp != target_stamp:
				target_stamp = stamp
				var groups := AttackOptions.groups(attacker,defender,game.get_world_3d(),game.manager.phase)
				target_copy = defender.display_name + "\n"
				if groups.is_empty(): target_copy += "Cannot attack: out of range or blocked by terrain."
				for group in groups:
					target_copy += "%s: %d attacks\n%d/%d in range; %d can see target\nAccuracy %d+ / Damage roll %d+ / Armor %d+\n" % [group.weapon.name,group.preview.attacks,group.preview.in_range,group.preview.living,group.preview.eligible,group.weapon.hit,AttackResolver.wound_target(int(group.weapon.strength),int(defender.definition.get("defense",4))),AttackOptions.save_required(defender,group.weapon)]
			terrain_card.show()
			terrain_text.text = target_copy
			place_card()
			return
	var objective := game.interaction.pick(game.interaction.pointer,8) as TableObjective
	if objective != null:
		var control: Dictionary = game.battlefield.control_for(objective)
		var points := int(game.scenario.get("scoring",{}).get("objective_points_per_round",0))
		terrain_text.text = "%s\n%s\n%d points at end of round\nTeam A nearby: %d / Team B nearby: %d" % [objective.display_name,"Neutral / contested" if control.owner < 0 else "Team A controls" if control.owner == 0 else "Team B controls",points,control.counts["0"],control.counts["1"]]
		terrain_card.show()
		place_card()
		return
	var found := game.interaction.pick(game.interaction.pointer,26) as TerrainPiece
	if found != hover:
		if is_instance_valid(hover) and not tactical: hover.footprint_overlay.hide()
		hover = found
		if hover != null: hover.footprint_overlay.show()
	terrain_card.visible = hover != null
	if hover != null:
		var traits := PackedStringArray([hover.title])
		if hover.blocks_movement: traits.append("Blocks movement")
		if hover.blocks_los: traits.append("Blocks line of sight")
		if hover.cover_bonus>0: traits.append("Cover: armor improves by %d" % hover.cover_bonus)
		if hover.movement_penalty>0: traits.append('Difficult ground: +%.0f" movement cost' % hover.movement_penalty)
		traits.append("Hold T: tactical view")
		terrain_text.text = "\n".join(traits)
		place_card()

func place_card() -> void:
	terrain_card.position = get_viewport().get_mouse_position()+Vector2(18,20)
	terrain_card.position = terrain_card.position.clamp(Vector2(8,130),get_viewport().get_visible_rect().size-terrain_card.size-Vector2(8,90))
