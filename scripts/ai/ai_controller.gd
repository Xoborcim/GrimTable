class_name AIController
extends Node

# Local-only opponent. All writes use the existing canonical gameplay APIs.
# Replays consume the resulting records, never this planner.
var game: Node3D
var config: Dictionary = {}
var planner: AIPlanner
var phase_key := ""
var actions := 0
var invalid_actions := 0
var cooldown := .3
var accelerated := false
var enabled := true
var finished := false
var reason := ""
var planning_ms: Array[float] = []
var decisions := 0
var status := ""
var debug_enabled := false
var panel: PanelContainer
var caption: Label
var debug_label: Label
var summary_shown := false
var total_action_ms := 0.0
var busy := false
var generation := 0
var pending_planning_ms := 0.0

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(440,140)
	panel.custom_minimum_size.x = 300
	panel.theme = GrimTheme.theme()
	layer.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	caption = AppUI.label(rows,"",17)
	AppUI.button(rows,"Speed up AI",func(): accelerated = not accelerated)
	debug_label = AppUI.label(rows,"",12)
	panel.hide()

static func valid_config(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not value.get("teams") is Dictionary or value.teams.size() > 2: return false
	for team in value.teams:
		if team not in ["0","1"] or value.teams[team] not in ["Easy","Normal","Hard"]: return false
	if not ScenarioDefinition.integer(value.get("seed"),0,2147483647) or not ScenarioDefinition.integer(value.get("round_limit"),1,100): return false
	if value.get("speed","Normal") not in ["Fast","Normal","Cinematic"]: return false
	if not value.get("finished",false) is bool or not value.get("reason","") is String: return false
	if not ScenarioDefinition.integer(value.get("human_team",0),0,1) or str(value.get("reason","")).length()>512: return false
	return true

func configure(value: Dictionary) -> void:
	generation += 1
	config = value.duplicate(true) if valid_config(value) else {}
	finished = bool(config.get("finished",false))
	reason = str(config.get("reason",""))
	phase_key = ""
	summary_shown = false
	planner = null

func snapshot() -> Dictionary:
	if config.is_empty(): return {}
	var result := config.duplicate(true)
	result.finished = finished
	result.reason = reason
	return result

func controls(team: int) -> bool:
	return not config.is_empty() and config.teams.has(str(team))

func active() -> bool:
	return controls(game.manager.active_team) and not finished

func _process(delta: float) -> void:
	if game.replay_mode or game.editing or game.menu_open or game.network_session != null or config.is_empty():
		panel.hide()
		return
	panel.visible = active() or finished
	caption.text = status if not finished else reason
	debug_label.visible = debug_enabled
	if not enabled or finished or busy: return
	cooldown -= delta
	if cooldown > 0: return
	busy = true
	await runtime_step()
	busy = false
	var speed: String = config.get("speed","Normal")
	cooldown = .01 if accelerated or speed == "Fast" else .3 if speed == "Normal" else .8

func prepare_phase() -> void:
	var key := "%d/%d/%d" % [game.manager.round_number,game.manager.active_team,game.manager.phase]
	if phase_key == key: return
	phase_key = key
	actions = 0
	invalid_actions = 0
	planner = AIPlanner.new(game,config.teams[str(game.manager.active_team)],int(config.seed))

func runtime_step() -> void:
	if active() and not game.manager.deployment and game.manager.phase == 1 and (game.combat.current == null or game.combat.current.remaining == 0):
		prepare_phase()
		game.interaction.cancel()
		game.interaction.read_only = true
		status = "Enemy is planning..."
		var started := Time.get_ticks_usec()
		var choice: Dictionary = await planner.choose_incremental()
		pending_planning_ms = (Time.get_ticks_usec()-started)/1000.0
		if choice.kind != "cancelled": step(choice)
	else: step()

func step(preplanned: Dictionary = {}) -> String:
	if config.is_empty() or finished or game.replay_mode or game.editing or game.menu_open or game.network_session != null: return "paused"
	if game.combat.current != null and game.combat.current.remaining > 0:
		if controls(game.combat.current.target.team):
			var model := AttackOptions.suggested(game.combat.current)
			if model != null:
				game.combat.allocate(model,mini(model.wounds,game.combat.current.remaining))
				if model.wounds == 0: game.combat.remove_casualty(model)
				return "allocate"
		game.interaction.read_only = false
		status = "Choose which model takes the damage."
		return "waiting_for_defender"
	if check_end(): return "finished"
	if game.manager.deployment:
		for unit: TableUnit in game.battlefield.units.get_children():
			if not controls(unit.team): continue
			if game.manager.ready_teams.get(str(unit.team),false): continue
			var session := SquadMoveSession.new(unit,game.battlefield,game.deployment)
			var proposal := FormationPlanner.deploy(session)
			if proposal.ok: game.history.perform(session.action())
			else: session.cancel(); status = str(proposal.error); return "deployment_blocked"
		var before: Dictionary = game.manager.snapshot()
		for team in config.teams: game.manager.ready_teams[team] = true
		if before != game.manager.snapshot():
			game.manager.changed.emit()
			game.manager.transitioned.emit(before,game.manager.snapshot())
		if config.teams.size() == 2 and game.deployment.validation_error().is_empty(): game.start_game()
		game.interaction.read_only = false
		return "deploy"
	if not controls(game.manager.active_team):
		game.interaction.read_only = false
		return "human"
	game.interaction.read_only = true
	prepare_phase()
	if actions >= 512 or invalid_actions >= 8:
		push_warning("AI watchdog skipped phase " + phase_key)
		game.manager.next_phase()
		return "watchdog"
	var start := Time.get_ticks_usec()
	var choice := planner.choose() if preplanned.is_empty() else preplanned
	var duration := (Time.get_ticks_usec()-start)/1000.0 + pending_planning_ms
	pending_planning_ms = 0.0
	planning_ms.append(duration)
	total_action_ms += duration
	decisions += 1
	debug_label.text = "%s\n%d candidates / %.2f ms\n%s" % [phase_key,planner.diagnostics.size(),duration,str(choice)]
	actions += 1
	if choice.kind == "end_phase":
		status = "Enemy finishes " + GameManager.PHASES[game.manager.phase].to_lower() + "."
		game.manager.next_phase()
		return "end_phase"
	var unit := NetworkAuthority.unit(game,str(choice.unit))
	if unit == null or unit.team != game.manager.active_team: invalid_actions += 1; return "invalid"
	game.selection.select_unit(unit)
	var ok := false
	if choice.kind == "move":
		status = unit.display_name + " is moving."
		var session := SquadMoveSession.new(unit,game.battlefield,game.deployment)
		var proposal := FormationPlanner.propose(session,ScenarioFactory.vector(choice.anchor),"Auto",false)
		if proposal.ok and session.validation_error().is_empty():
			game.history.perform(session.action())
			ok = true
		else: session.cancel()
		planner.attempted[str(unit.name)] = true
	elif choice.kind == "attack":
		var target := NetworkAuthority.unit(game,str(choice.target))
		if target != null:
			status = unit.display_name + " attacks " + target.display_name + "."
			var available := AttackOptions.groups(unit,target,game.get_world_3d(),game.manager.phase)
			for group in available:
				if int(group.index) == int(choice.weapon) and not planner.fired(unit,group.weapon):
					ok = game.combat.resolve(unit,target,game.get_world_3d(),int(choice.weapon))
		if not ok: planner.attempted[str(unit.name)] = true
	elif choice.kind == "charge":
		var target := NetworkAuthority.unit(game,str(choice.target))
		if target != null:
			status = unit.display_name + " charges " + target.display_name + "."
			var grant := ChargeRules.roll(game,unit,target)
			ok = not grant.has("error")
			if ok and float(grant.distance) >= float(grant.required):
				var session := SquadMoveSession.new(unit,game.battlefield,game.deployment)
				session.allowance = float(grant.distance)
				session.charge_target = str(target.name)
				var proposal := FormationPlanner.propose(session,ChargeRules.anchor(unit,target,ChargeRules.reach(game)),"Auto",true)
				if proposal.ok and session.validation_error().is_empty(): game.history.perform(session.action())
				else: session.cancel()
		planner.attempted[str(unit.name)] = true
	if not ok: invalid_actions += 1
	return str(choice.kind) if ok else "invalid"

func check_end() -> bool:
	MissionRules.finish_elimination(game)
	var alive := [0,0]
	for unit: TableUnit in game.battlefield.units.get_children(): alive[unit.team] += unit.living_models().size()
	if alive[0] == 0 or alive[1] == 0: finish("Battle complete: opposing force defeated.")
	elif game.manager.round_number >= int(game.initial_scenario.starting_state.round) + int(config.round_limit): finish("Battle complete: round limit reached.")
	return finished

func finish(message: String) -> void:
	generation += 1
	finished = true
	reason = message
	game.interaction.read_only = true
	if game.has_method("show_match_summary"): game.show_match_summary()
	game.schedule_autosave()
