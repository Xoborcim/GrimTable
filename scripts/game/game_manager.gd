class_name GameManager
extends Node

signal changed
signal transitioned(before: Dictionary, after: Dictionary)
const PHASES := ["Command", "Movement", "Shooting", "Charge", "Fight", "End"]
var round_number := 1
var phase := 0
var active_team := 0
var deployment := true
var score_provider: Callable
var scores := {"0": 0, "1": 0}
var scored_rounds: Array = []
var submit: Callable
var charges: Dictionary = {}
var ready_teams: Dictionary = {}
var objective_owners: Dictionary = {}
var cover_overrides: Dictionary = {}
var missions: Dictionary = {}
var transition_hook: Callable

func next_phase() -> void:
	if submit.is_valid() and submit.call("next_phase"): return
	if missions.get("finished",false):return
	if deployment: return
	var before := snapshot()
	if phase == PHASES.size() - 1:
		phase = 0
		active_team = 1 - active_team
		if active_team == 0: round_number += 1
	else: phase += 1
	if phase == 5 and active_team == 1 and not scored_rounds.has(round_number) and score_provider.is_valid():
		var earned: Dictionary = score_provider.call()
		for team in ["0", "1"]: scores[team] += int(earned.get(team, 0))
		scored_rounds.append(round_number)
	if transition_hook.is_valid(): transition_hook.call()
	changed.emit()
	transitioned.emit(before, snapshot())

func previous_phase() -> void:
	if submit.is_valid() and submit.call("previous_phase"): return
	if deployment: return
	var before := snapshot()
	if phase > 0: phase -= 1
	elif active_team == 1:
		active_team = 0
		phase = PHASES.size() - 1
	elif round_number > 1:
		round_number -= 1
		active_team = 1
		phase = PHASES.size() - 1
	changed.emit()
	transitioned.emit(before, snapshot())

func next_round() -> void:
	if submit.is_valid() and submit.call("next_round"): return
	if deployment: return
	var before := snapshot()
	round_number += 1
	phase = 0
	active_team = 0
	if transition_hook.is_valid(): transition_hook.call()
	changed.emit()
	transitioned.emit(before, snapshot())

func snapshot() -> Dictionary:
	var data := {"round": round_number, "phase": phase, "team": active_team, "deployment": deployment, "scores": scores.duplicate(), "scored_rounds": scored_rounds.duplicate(), "charges": charges.duplicate(true), "ready_teams": ready_teams.duplicate(), "objective_owners": objective_owners.duplicate(), "cover_overrides": cover_overrides.duplicate()}
	if not missions.is_empty(): data["missions"] = missions.duplicate(true)
	return data

func restore(data: Dictionary) -> void:
	missions = MissionRules.normalized(data.get("missions",{}))
	charges = data.get("charges", {}).duplicate(true)
	for id in charges:
		for key in ["round", "team", "distance"]: charges[id][key] = int(charges[id][key])
		charges[id].required = snappedf(float(charges[id].required), .001)
		var rolls: Array[int] = []
		for value in charges[id].rolls: rolls.append(int(value))
		charges[id].rolls = rolls
	ready_teams = data.get("ready_teams", {}).duplicate()
	objective_owners = data.get("objective_owners", {}).duplicate()
	cover_overrides = data.get("cover_overrides", {}).duplicate()
	for id in objective_owners: objective_owners[id] = int(objective_owners[id])
	for id in cover_overrides: cover_overrides[id] = int(cover_overrides[id])
	scores = {"0": int(data.get("scores", {}).get("0", 0)), "1": int(data.get("scores", {}).get("1", 0))}
	scored_rounds = []
	for value in data.get("scored_rounds", []): scored_rounds.append(int(value))
	deployment = bool(data.get("deployment", false))
	round_number = maxi(1, int(data.get("round", 1)))
	phase = clampi(int(data.get("phase", 0)), 0, PHASES.size() - 1)
	active_team = clampi(int(data.get("team", 0)), 0, 1)
	changed.emit()
