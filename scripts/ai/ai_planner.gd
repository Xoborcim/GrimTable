class_name AIPlanner
extends RefCounted

# Utility estimates never roll gameplay dice. Exact eligibility and movement
# always go through the same services used by the human interaction controller.
var game: Node3D
var weights: Dictionary
var seed_value := 1
var diagnostics: Array[Dictionary] = []
var attempted: Dictionary = {}
var candidate_ms: Array[float] = []

func _init(battle: Node3D, difficulty: String = "Normal", seed_number: int = 1) -> void:
	game = battle
	seed_value = seed_number
	weights = JSON.parse_string(FileAccess.get_file_as_string("res://resources/ai/" + difficulty.to_lower() + ".json"))

static func probability(threshold: int) -> float:
	return clampf((7.0 - threshold) / 6.0, 0, 1)

static func charge_probability(required: float, rule: Dictionary) -> float:
	var totals := {0:1.0}
	var sides := int(rule.get("sides",6))
	for die in int(rule.get("dice",2)):
		var next := {}
		for total in totals:
			for roll in range(1,sides+1): next[total+roll] = float(next.get(total+roll,0))+float(totals[total])/sides
		totals = next
	var chance := 0.0
	for total in totals:
		if total+int(rule.get("bonus",0))>=required: chance+=totals[total]
	return chance

static func expected_damage(attacker: TableUnit, target: TableUnit, group: Dictionary) -> float:
	var weapon: Dictionary = group.weapon
	return float(group.preview.attacks) * probability(clampi(int(weapon.hit), 2, 7)) * probability(AttackResolver.wound_target(AttackResolver.strength_against(weapon,target.definition), int(target.definition.get("defense", target.definition.get("toughness", 4))))) * (1 - probability(AttackOptions.save_required(target, weapon))) * float(weapon.damage)

func enemies(unit: TableUnit) -> Array[TableUnit]:
	var found: Array[TableUnit] = []
	for other: TableUnit in game.battlefield.units.get_children():
		if other.team != unit.team and not other.living_models().is_empty(): found.append(other)
	found.sort_custom(func(a,b): return str(a.name) < str(b.name))
	return found

func states() -> Dictionary:
	return PhaseAssistant.states(game.battle_log, game.manager.round_number, int(game.initial_scenario.starting_state.round), bool(game.initial_scenario.starting_state.deployment))

func fired(unit: TableUnit, weapon: Dictionary) -> bool:
	if WeaponUse.strict(unit):
		for model in unit.living_models():
			if WeaponUse.eligible(unit,model,weapon): return false
		return true
	var round_at := int(game.initial_scenario.starting_state.round)
	for entry in game.battle_log.entries:
		if entry.kind in ["turn", "start_game"]: round_at = int(entry.payload.get("after", {}).get("round", round_at))
		if round_at == game.manager.round_number and entry.kind == "attack" and entry.payload.attacker_id == str(unit.name) and entry.payload.weapon == weapon: return true
	return false

func target_value(unit: TableUnit, target: TableUnit, group: Dictionary) -> float:
	var damage := expected_damage(unit, target, group)
	var health := 0
	for model in target.living_models(): health += model.wounds
	var score := damage * float(weights.damage)
	if damage >= health * .65: score += float(weights.kill) * minf(1, damage / maxi(1, health))
	if not game.manager.missions.is_empty():
		var role: String=target.definition.get("roster",{}).get("role","")
		for id: String in game.manager.missions.teams[str(unit.team)].active:
			var card:=MissionRules.card(id)
			if (card.condition=="destroy_heavy" and role in ["Vehicle","Walker","Creature"]) or (card.condition=="destroy_leader" and role=="Leader") or (card.condition=="destroy_fast" and role=="Fast"):
				score+=float(card.points)*float(weights.kill)*minf(1,damage/maxi(1,health))
	for objective: TableObjective in game.battlefield.objectives.get_children():
		if FormationPlanner.center(target.living_models()).distance_to(objective.global_position) < objective.radius + 2: score += float(weights.objective_holder)
	return score

func variation(key: String) -> float:
	# A local RNG seeded from the decision identity: independent of combat RNG,
	# repeatable across saves, and not sensitive to dictionary iteration order.
	var rng := RandomNumberGenerator.new()
	rng.seed = (str(seed_value) + "/" + str(game.manager.round_number) + "/" + str(game.manager.phase) + "/" + key).hash()
	return rng.randf() * float(weights.variation)

func choose() -> Dictionary:
	diagnostics.clear()
	var state := states()
	var best: Dictionary = {}
	var evaluated_units := 0
	var units: Array = game.battlefield.units.get_children()
	units.sort_custom(func(a,b): return str(a.name) < str(b.name))
	for unit: TableUnit in units:
		if unit.team != game.manager.active_team or unit.living_models().is_empty(): continue
		var id := str(unit.name)
		if attempted.has(id): continue
		var flags: Dictionary = state.get(id, {})
		if game.manager.phase == 1 and int(flags.get("moved", 0)) == 0:
			if evaluated_units >= int(weights.get("planning_units",2)): break
			evaluated_units += 1
			var move := movement(unit)
			if not move.is_empty(): best = better(best, move)
		elif game.manager.phase in [2,4]:
			for enemy in enemies(unit):
				for group in AttackOptions.groups(unit, enemy, game.get_world_3d(), game.manager.phase):
					if fired(unit, group.weapon): continue
					var value := target_value(unit, enemy, group) + variation(id + str(enemy.name) + str(group.index))
					best = better(best, {"kind":"attack", "unit":id, "target":str(enemy.name), "weapon":group.index, "score":value})
		elif game.manager.phase == 3 and int(flags.get("charge_rolled",0)) == 0:
			for enemy in enemies(unit):
				if not ChargeRules.error_for(game,unit,enemy,unit.team).is_empty(): continue
				var required := ChargeRules.required(unit,enemy,ChargeRules.reach(game))
				if required <= .01 or required > float(weights.charge_distance): continue
				var melee := 0.0
				for weapon in unit.weapon_profiles:
					if weapon.get("type","ranged") == "melee": melee += float(weapon.attacks) * float(weapon.damage) * unit.living_models().size()
				if melee <= 0: continue
				var value := melee * float(weights.charge) * charge_probability(required,game.scenario.get("rules",{}).get("charge",{})) / maxf(1,required)
				for objective: TableObjective in game.battlefield.objectives.get_children():
					if game.battlefield.control_for(objective).owner == unit.team and FormationPlanner.center(unit.living_models()).distance_to(objective.global_position)<objective.radius and ChargeRules.anchor(unit,enemy,ChargeRules.reach(game)).distance_to(objective.global_position)>objective.radius: value -= float(weights.objective)*.06
				if value<=0: continue
				best = better(best,{"kind":"charge","unit":id,"target":str(enemy.name),"score":value})
	return best if not best.is_empty() else {"kind":"end_phase"}

func better(current: Dictionary, candidate: Dictionary) -> Dictionary:
	diagnostics.append({"unit":candidate.unit,"kind":candidate.kind,"score":candidate.score,"target":candidate.get("target","")})
	return candidate if current.is_empty() or float(candidate.score) > float(current.score) else current

func position_value(unit: TableUnit, point: Vector3) -> float:
	var score := 0.0
	var nearest := INF
	for objective: TableObjective in game.battlefield.objectives.get_children():
		var distance := point.distance_to(objective.global_position)
		var control: Dictionary = game.battlefield.control_for(objective)
		var need := 1.0 if control.owner != unit.team else .3
		var value := float(weights.objective) * need / (1 + maxf(0, distance - objective.radius))
		if distance < objective.radius: value += float(weights.objective) * need * .35
		score += value
	var shooting := 0.0
	var melee := 0.0
	for weapon in unit.weapon_profiles:
		if weapon.get("type","ranged") == "melee": melee = maxf(melee,float(weapon.attacks)*float(weapon.damage))
		else: shooting = maxf(shooting,float(weapon.range))
	for enemy in enemies(unit):
		var distance := point.distance_to(FormationPlanner.center(enemy.living_models()))
		nearest = minf(nearest,distance)
		if shooting > 0 and distance < shooting: score += float(weights.firing) * minf(1,distance / 5)
		if distance < 8 and shooting > 5: score -= float(weights.threat) / maxf(1,distance)
	if melee > 0 and is_finite(nearest): score += float(weights.melee) / (1 + nearest)
	for piece: TerrainPiece in game.battlefield.terrain.get_children():
		if piece.cover_bonus > 0 and piece.overlaps_base(point,0): score += float(weights.cover)
	return score + MissionRules.position_bonus(game,unit,point)*float(weights.objective)*.12

func movement_candidates(unit: TableUnit) -> Array[Vector3]:
	var models := unit.living_models()
	var origin := FormationPlanner.center(models)
	var allowance := INF
	for model in models: allowance = minf(allowance,model.movement)
	var goals: Array[Vector3] = []
	if not game.manager.missions.is_empty():
		for id: String in game.manager.missions.teams[str(unit.team)].active:
			var condition: String=MissionRules.card(id).condition
			if condition=="center":goals.append(Vector3.ZERO)
			if condition in ["advance","behind"]:goals.append(Vector3(origin.x,0,(-1 if unit.team==0 else 1)*(game.battlefield.depth/2-5)))
	for objective: TableObjective in game.battlefield.objectives.get_children(): goals.append(objective.global_position)
	for enemy in enemies(unit): goals.append(FormationPlanner.center(enemy.living_models()))
	var candidates: Array[Vector3] = []
	for goal in goals:
		var delta := goal - origin
		for fraction in [1.0,.65]: candidates.append(origin + delta.normalized() * minf(delta.length(),maxf(0,allowance-.2)*fraction))
	for i in 8: candidates.append(origin + Vector3(cos(i*TAU/8),0,sin(i*TAU/8))*maxf(0,allowance-.2))
	return candidates.slice(0,int(weights.candidates))

func evaluate_anchor(unit: TableUnit, anchor: Vector3, index: int, base_score: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var session := SquadMoveSession.new(unit,game.battlefield,game.deployment)
	var result := FormationPlanner.propose(session,anchor,"Auto",false)
	var found: Dictionary = {}
	if result.ok:
		var value := position_value(unit,FormationPlanner.center(unit.living_models())) - base_score + variation(str(unit.name)+str(index)) * .1
		if value > .001: found = {"kind":"move","unit":str(unit.name),"anchor":ScenarioFactory.array(anchor),"score":value}
	session.cancel()
	game.battlefield.invalidate_spatial()
	candidate_ms.append((Time.get_ticks_usec()-started)/1000.0)
	return found

func movement(unit: TableUnit) -> Dictionary:
	var best: Dictionary = {}
	var base_score := position_value(unit,FormationPlanner.center(unit.living_models()))
	var candidates := movement_candidates(unit)
	for index in candidates.size():
		var value := evaluate_anchor(unit,candidates[index],index+1,base_score)
		if not value.is_empty() and (best.is_empty() or value.score>best.score): best=value
	return best

func choose_incremental() -> Dictionary:
	if game.manager.phase != 1: return choose()
	diagnostics.clear()
	var state := states()
	var best: Dictionary = {}
	var units: Array = game.battlefield.units.get_children()
	units.sort_custom(func(a,b): return str(a.name)<str(b.name))
	var count := 0
	var identity: Dictionary = game.manager.snapshot()
	var generation: int = game.ai.generation
	var sequence: int = game.battle_log.sequence
	var started := Time.get_ticks_msec()
	for unit: TableUnit in units:
		if unit.team != game.manager.active_team or unit.living_models().is_empty() or attempted.has(str(unit.name)) or int(state.get(str(unit.name),{}).get("moved",0))>0: continue
		if count >= int(weights.get("planning_units",2)): break
		count += 1
		var base_score := position_value(unit,FormationPlanner.center(unit.living_models()))
		var candidates := movement_candidates(unit)
		for index in candidates.size():
			var value := evaluate_anchor(unit,candidates[index],index+1,base_score)
			if not value.is_empty(): best = better(best,value)
			# Temporary positions have been restored before this yield.
			await game.get_tree().process_frame
			if not is_instance_valid(game) or not game.is_inside_tree(): return {"kind":"cancelled"}
			if game.menu_open or game.replay_mode or game.editing or game.network_session != null or game.ai.finished or not game.ai.enabled or game.ai.generation != generation or game.battle_log.sequence != sequence or game.manager.snapshot()!=identity: return {"kind":"cancelled"}
			if Time.get_ticks_msec()-started > 3000:
				# Keep the best legal candidate found within the bounded planning budget.
				return best if not best.is_empty() else {"kind":"end_phase"}
	return best if not best.is_empty() else {"kind":"end_phase"}
