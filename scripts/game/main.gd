extends Node3D

var battlefield: Battlefield
var camera_rig: TableCamera
var selection := SelectionManager.new()
var interaction: InteractionController
var manager: GameManager
var dice := DiceManager.new()
var hud: TableHUD
var history := ActionHistory.new()
var battle_log := BattleLog.new()
var deployment: DeploymentManager
var combat := CombatController.new()
var guidance: GuidedExperience
var assistance: TurnAssistant
var scenario: Dictionary = {}
var initial_scenario: Dictionary = {}
var scenario_path := "res://resources/scenarios/demo.json"
var replay_mode := false
var replay_supported := true
var editing := false
var settings: AppSettings
var autosave_scheduled := false
var network_session: NetworkSession
var menu_open := false
var ai: AIController
var life: BattlefieldLife
var dice_tray: DiceTray
var ai_config: Dictionary = {}
var match_overlay: CanvasLayer

func _ready() -> void:
	for issue in ContentRegistry.validate(): push_error("Content: " + issue)
	if settings == null:
		settings = AppSettings.new()
		settings.load_settings()
	if scenario.is_empty():
		var loaded := ScenarioLibrary.read(scenario_path)
		if loaded.has("error"):
			push_error(loaded.error)
			return
		scenario = loaded.data
	initial_scenario = ContentRegistry.freeze(scenario)
	BattlefieldPresentation.lighting(self, settings)
	BattlefieldPresentation.apply_theme(self,scenario.board)
	battlefield = Battlefield.new()
	battlefield.scenario = scenario
	battlefield.name = "Battlefield"
	add_child(battlefield)
	camera_rig = TableCamera.new()
	camera_rig.name = "CameraController"
	add_child(camera_rig)
	if scenario.board.get("environment_art",false):
		camera_rig.distance=60
		camera_rig.pitch=.86
		camera_rig.destination=Vector3(0,1,-2)
		camera_rig._update_camera(1)
	if scenario.id == "ashfall_station" and scenario.board.get("surface_layout","Legacy")=="Legacy":
		camera_rig.distance = 35
		camera_rig.destination = Vector3(-3, 0, -1)
		camera_rig._update_camera(1)
	if scenario.board.get("surface_layout","Legacy")!="Legacy":
		camera_rig.distance=53
		camera_rig.pitch=.92
		camera_rig.heading=.08
		camera_rig.destination=Vector3(0,.5,-2)
		camera_rig._update_camera(1)
	camera_rig.reduce_motion = settings.reduce_motion
	camera_rig.sensitivity = settings.camera_sensitivity
	camera_rig.bounds = Vector2(battlefield.width, battlefield.depth) / 2
	manager = GameManager.new()
	manager.name = "GameManager"
	add_child(manager)
	manager.restore(scenario.starting_state)
	manager.score_provider = func(): return {} if not settings.automatic_scoring else ObjectiveControl.scores(battlefield, int(scenario.get("scoring", {}).get("objective_points_per_round", 0)))
	deployment = DeploymentManager.new()
	deployment.board = battlefield
	deployment.manager = manager
	add_child(deployment)
	history.log = battle_log
	interaction = InteractionController.new()
	interaction.board = battlefield
	interaction.rig = camera_rig
	interaction.selection = selection
	interaction.history = history
	interaction.deployment = deployment
	interaction.precision = settings.precision
	add_child(interaction)
	combat.dice = dice
	combat.history = history
	combat.log = battle_log
	combat.manager = manager
	combat.interaction = interaction
	combat.settings = settings
	hud = TableHUD.new()
	hud.name = "UI"
	hud.selection = selection
	hud.interaction = interaction
	hud.manager = manager
	hud.dice = dice
	hud.history = history
	hud.combat = combat
	add_child(hud)
	if not MiniatureLibrary.warnings.is_empty(): hud.set_status("Some local miniature files are missing. Authored GrimTable models are being used.")
	dice_tray = DiceTray.new()
	dice_tray.settings = settings
	add_child(dice_tray)
	dice.rolled.connect(func(result: Dictionary): dice_tray.enqueue("MANUAL ROLL", result.values))
	var presentation := CombatPresentation.new()
	presentation.game = self
	add_child(presentation)
	assistance = TurnAssistant.new()
	assistance.game = self
	add_child(assistance)
	guidance = GuidedExperience.new()
	guidance.game = self
	add_child(guidance)
	ai = AIController.new()
	ai.game = self
	add_child(ai)
	ai.configure(ai_config)
	life = BattlefieldLife.new()
	life.game = self
	add_child(life)
	combat.message.connect(hud.set_status)
	hud.removal_requested.connect(func():
		interaction.cancel()
		var changes: Array[Dictionary] = []
		for model in selection.models:
			changes.append({"object": model, "id": model.model_id, "property": "removed", "before": model.removed, "after": true})
		history.perform(GameAction.new("Remove models", "remove", changes))
		selection.clear()
		hud.set_status("Selected miniatures removed"))
	hud.save_requested.connect(func():
		interaction.cancel()
		hud.set_status(SaveService.save_game(self, manager, battle_log, combat)))
	hud.load_requested.connect(func():
		if network_session != null:
			hud.set_status("Leave multiplayer before loading another game")
			return
		interaction.cancel()
		selection.clear()
		var message := SaveService.load_game(self, manager, battle_log, combat)
		if message.begins_with("Loaded"): history.clear()
		hud.set_status(message))
	history.changed.connect(hud.refresh_selection)
	history.changed.connect(battlefield.invalidate_spatial)
	manager.changed.connect(battlefield.invalidate_spatial)
	manager.changed.connect(interaction.cancel)
	manager.transitioned.connect(func(before: Dictionary, after: Dictionary):
		battle_log.append("turn", {"before": before, "after": after})
		if manager.phase == 1:
			interaction.set_mode(0)
			hud.set_status("Choose a squad, then Move. Click a destination and confirm.")
		elif manager.phase in [2, 4]:
			if settings.assistance == "Tabletop": hud.combat_panel.show()
			hud.dice_panel.hide())
	battle_log.changed.connect(schedule_autosave)

func apply_scenario(data: Dictionary) -> void:
	if is_instance_valid(dice_tray): dice_tray.cancel()
	if is_instance_valid(match_overlay): match_overlay.queue_free()
	replay_supported = true
	interaction.set_mode(0)
	selection.clear()
	combat.reset()
	dice.history.clear()
	history.clear()
	battle_log.restore([])
	scenario = data.duplicate(true)
	initial_scenario = ContentRegistry.freeze(scenario)
	battlefield.build(data)
	BattlefieldPresentation.apply_theme(self,data.board)
	deployment.load_zones(data)
	manager.restore(data.starting_state)
	camera_rig.bounds = Vector2(battlefield.width, battlefield.depth) / 2
	hud.refresh_selection()

func schedule_autosave() -> void:
	if autosave_scheduled or replay_mode or editing or not settings.autosave: return
	autosave_scheduled = true
	call_deferred("_autosave")

func _autosave() -> void:
	autosave_scheduled = false
	if not is_inside_tree() or is_queued_for_deletion(): return
	if replay_mode or editing or not settings.autosave or interaction.session != null or interaction.dragging != null or interaction.drag_object != null: return
	var result := SaveService.save_game(self, manager, battle_log, combat, "user://autosave.json")
	if not result.begins_with("Saved"): hud.set_status("Auto-save: " + result)

func undo_action() -> void:
	if network_session != null and not network_session.applying: network_session.request("undo"); return
	interaction.cancel()
	history.undo()
	hud.set_status("Undo complete" if not history.redo_stack.is_empty() else "Nothing to undo")

func redo_action() -> void:
	if network_session != null and not network_session.applying: network_session.request("redo"); return
	interaction.cancel()
	history.redo()
	hud.set_status("Redo complete" if not history.undo_stack.is_empty() else "Nothing to redo")

func start_game() -> bool:
	if network_session != null and not network_session.applying: return network_session.request("start_game")
	if not manager.deployment: return false
	if interaction.session != null or interaction.dragging != null:
		hud.set_status("Confirm or cancel movement before starting")
		return false
	var error := deployment.validation_error()
	if not error.is_empty():
		hud.set_status(error)
		return false
	var before := manager.snapshot()
	manager.deployment = false
	manager.changed.emit()
	history.clear()
	battle_log.append("start_game", {"scenario": scenario.id, "before": before, "after": manager.snapshot()})
	hud.set_status("Battle started. Deployment complete.")
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if replay_mode or editing or menu_open: return
	if ai != null and (ai.active() or ai.finished): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode in [KEY_Z, KEY_Y]:
			if event.keycode == KEY_Z: undo_action()
			else: redo_action()
			get_viewport().set_input_as_handled()
		if event.keycode == KEY_F3:
			interaction.debug_enabled = not interaction.debug_enabled
			for model: Miniature in get_tree().get_nodes_in_group("miniatures"):
				model.debug_ring.visible = interaction.debug_enabled
			for piece: TerrainPiece in get_tree().get_nodes_in_group("terrain"):
				piece.debug_shape.visible = interaction.debug_enabled
			hud.set_status("Debug base radii / terrain collision: " + str(interaction.debug_enabled))
		if event.keycode == KEY_F4:
			interaction.show_los = not interaction.show_los
			hud.set_status("LOS ray display: " + str(interaction.show_los))

func show_match_summary() -> void:
	if ai.summary_shown: return
	ai.summary_shown = true
	var layer := CanvasLayer.new()
	layer.layer = 18
	add_child(layer)
	match_overlay = layer
	var card := PanelContainer.new()
	card.theme = GrimTheme.theme()
	card.position = get_viewport().get_visible_rect().size / 2 - Vector2(230,210)
	card.custom_minimum_size = Vector2(460,420)
	layer.add_child(card)
	guidance.round_card.hide()
	guidance.hint_card.hide()
	guidance.toast.hide()
	var rows := VBoxContainer.new()
	card.add_child(rows)
	var us := int(ai.config.get("human_team",0))
	var ours := int(manager.scores[str(us)])
	var theirs := int(manager.scores[str(1-us)])
	var alive := [0,0]
	for unit: TableUnit in battlefield.units.get_children(): alive[unit.team] += unit.living_models().size()
	var won: bool = (alive[1-us] == 0 and alive[us] > 0) or (alive[us]>0 and ours>theirs)
	var surrendered := ai.reason == "You ended this battle."
	AppUI.label(rows,"Defeat" if surrendered else "Victory" if won else "Draw" if ours == theirs and alive[0]>0 and alive[1]>0 else "Defeat",32)
	AppUI.label(rows,ai.reason,15)
	AppUI.label(rows,"You %d  -  %d Enemy" % [ours,theirs],26)
	var remaining := 0
	var damage := 0
	var defeated := 0
	var objectives := 0
	for unit: TableUnit in battlefield.units.get_children():
		if unit.team == us: remaining += unit.living_models().size()
		else:
			for model in unit.models:
				if model.wounds == 0: defeated += 1
	for entry in battle_log.entries:
		if entry.kind != "execute" or entry.payload.kind != "damage": continue
		var attack_id := int(entry.payload.metadata.get("attack_id",-1))
		for attack in battle_log.entries:
			if attack.sequence == attack_id and attack.kind == "attack":
				var attacker := NetworkAuthority.unit(self,attack.payload.attacker_id)
				if attacker != null and attacker.team == us: damage += int(entry.payload.metadata.damage)
	for objective: TableObjective in battlefield.objectives.get_children():
		if battlefield.control_for(objective).owner == us: objectives += 1
	AppUI.label(rows,"Objectives: %d\nModels remaining: %d\nEnemy models defeated: %d\nDamage dealt: %d" % [objectives,remaining,defeated,damage],17)
	AppUI.button(rows,"Save Replay",func(): hud.set_status(ReplayController.save(self)))
	AppUI.button(rows,"Play Again",func():
		layer.queue_free()
		apply_scenario(initial_scenario)
		var fresh := ai_config.duplicate(true)
		fresh.erase("finished")
		fresh.erase("reason")
		ai.configure(fresh)
		interaction.read_only = false)
	AppUI.button(rows,"Main Menu",func(): get_parent().show_main())
