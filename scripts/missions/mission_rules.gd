class_name MissionRules
extends RefCounted
static var _catalog: Dictionary={}

static func catalog() -> Dictionary:
	if _catalog.is_empty():_catalog=ContentRegistry.read_json("res://resources/missions/tactical.json")
	return _catalog

static func normalized(value: Dictionary) -> Dictionary:
	var data:=value.duplicate(true)
	if data.is_empty():return data
	for key in ["version","seed","round"]:data[key]=int(data[key])
	for i in data.scored.size():data.scored[i]=int(data.scored[i])
	for id in data.previous_owners:data.previous_owners[id]=int(data.previous_owners[id])
	for team in ["0","1"]:
		for key in ["primary_score","secondary_score"]:data.teams[team][key]=int(data.teams[team][key])
	for award in data.ledger:
		for key in ["points","round"]:award[key]=int(award[key])
	if data.has("outcome"):data.outcome.winner=int(data.outcome.winner)
	return data

static func card(id: String) -> Dictionary:
	for item: Dictionary in catalog().cards:
		if item.id==id:return item
	return {}

static func initial(primary: String, tactical: bool, seed_number: int) -> Dictionary:
	var data:={"version":1,"primary":primary,"tactical":tactical,"seed":seed_number,"round":0,"scored":[],"teams":{},"ledger":[],"previous_owners":{},"finished":false}
	for team in ["0","1"]:
		var deck: Array=[]
		if tactical:
			for item in catalog().cards:deck.append(item.id)
		var rng:=RandomNumberGenerator.new();rng.seed=seed_number+int(team)*7919
		for i in range(deck.size()-1,0,-1):
			var j:=rng.randi_range(0,i);var swap: Variant=deck[i];deck[i]=deck[j];deck[j]=swap
		data.teams[team]={"draw":deck,"discard":[],"active":[],"completed":[],"primary_score":0,"secondary_score":0,"alive_at_draw":[]}
	return data

static func error(value: Variant) -> String:
	if not value is Dictionary:return "Invalid mission state."
	if value.is_empty():return ""
	if value.get("version")!=1 or value.get("primary") not in ["control","convergence","domination"] or not value.get("tactical") is bool or not value.get("finished") is bool:return "Unsupported mission rules."
	if value.has("outcome"):
		if not value.outcome is Dictionary or not ScenarioDefinition.integer(value.outcome.get("winner"),-1,1) or not value.outcome.get("reason") is String or value.outcome.reason.length()>512:return "Invalid battle outcome."
	if not ScenarioDefinition.integer(value.get("seed"),0,2147483647) or not ScenarioDefinition.integer(value.get("round"),0,100) or not value.get("scored") is Array or value.scored.size()>100:return "Invalid mission round or seed."
	var seen:={}
	for round_number in value.scored:
		if not ScenarioDefinition.integer(round_number,1,100) or seen.has(int(round_number)):return "Invalid mission scoring history."
		seen[int(round_number)]=true
	if not value.get("teams") is Dictionary or value.teams.size()!=2 or not value.get("previous_owners") is Dictionary or value.previous_owners.size()>200:return "Invalid mission teams."
	for key in value.previous_owners:
		if not key is String or not ScenarioDefinition.integer(value.previous_owners[key],-1,1):return "Invalid mission ownership."
	for team in ["0","1"]:
		if not value.teams.get(team) is Dictionary:return "Missing mission team."
		var data: Dictionary=value.teams[team]
		for key in ["primary_score","secondary_score"]:
			if not ScenarioDefinition.integer(data.get(key),0,100000):return "Invalid mission score."
		for key in ["draw","discard","active","completed","alive_at_draw"]:
			if not data.get(key) is Array or data[key].size()>300:return "Invalid mission pile."
			for id in data[key]:
				if not id is String or id.length()>120 or (key!="alive_at_draw" and card(id).is_empty()):return "Unknown mission card."
		if data.active.size()>2:return "Too many active missions."
	if not value.get("ledger") is Array or value.ledger.size()>600:return "Invalid mission ledger."
	var awards:={}
	for award in value.ledger:
		if not award is Dictionary or not award.get("id") is String or awards.has(award.id) or award.get("team") not in ["0","1"] or not ScenarioDefinition.integer(award.get("round"),1,100) or not ScenarioDefinition.integer(award.get("points"),0,100) or not award.get("title") is String or award.title.length()>120:return "Invalid mission award."
		awards[award.id]=true
	return ""

static func ownership(game: Node) -> Dictionary:
	var owners:={}
	for objective: TableObjective in game.battlefield.objectives.get_children():owners[objective.object_id]=ObjectiveControl.evaluate(objective,game.battlefield.units.get_children()).owner
	return owners

static func central(game: Node) -> TableObjective:
	var result: TableObjective
	for objective: TableObjective in game.battlefield.objectives.get_children():
		if result==null or objective.position.length_squared()<result.position.length_squared():result=objective
	return result

static func progress(game: Node, team: int, condition: String) -> int:
	var units: Array=game.battlefield.units.get_children()
	var ours:=0;var theirs:=0;var enemy_objectives:=0;var home:=0
	for objective: TableObjective in game.battlefield.objectives.get_children():
		var owner: int=ObjectiveControl.evaluate(objective,units).owner
		if owner==team:
			ours+=1
			if objective.position.z*(1 if team==0 else -1)<0:enemy_objectives+=1
			else:home+=1
		elif owner>=0:theirs+=1
	if condition=="control":return ours
	if condition=="central":
		var objective:=central(game)
		return 1 if objective!=null and ObjectiveControl.evaluate(objective,units).owner==team else 0
	if condition=="enemy_objective":return enemy_objectives
	if condition=="sabotage":return 1 if ours>theirs and enemy_objectives>0 else 0
	var result:=0
	var baseline: Array=game.manager.missions.teams[str(team)].alive_at_draw
	for unit: TableUnit in units:
		if condition.begins_with("destroy_"):
			if unit.team==team or not baseline.has(str(unit.name)) or not unit.living_models().is_empty():continue
			var role: String=unit.definition.get("roster",{}).get("role","")
			if (condition=="destroy_fast" and role=="Fast") or (condition=="destroy_leader" and role=="Leader") or (condition=="destroy_heavy" and role in ["Vehicle","Walker","Creature"]):result+=1
		elif unit.team==team and not unit.living_models().is_empty():
			var center:=FormationPlanner.center(unit.living_models())
			if condition=="center" and Vector2(center.x,center.z).length()<=4:result+=1
			if condition=="advance" and center.z*(1 if team==0 else -1)<0:result+=1
			if condition=="behind" and center.z*(1 if team==0 else -1)<-game.battlefield.depth/2+10:result+=1
	if condition=="defend":
		for unit: TableUnit in units:
			if unit.team==team and baseline.has(str(unit.name)) and unit.living_models().is_empty():return 0
		return 1 if home>0 else 0
	return result

static func award(game: Node, team: String, points: int, title: String, category: String) -> void:
	var data: Dictionary=game.manager.missions
	var id:=str(game.manager.round_number)+":"+team+":"+category
	for previous in data.ledger:
		if previous.id==id:return
	data.ledger.append({"id":id,"round":game.manager.round_number,"team":team,"points":points,"title":title})
	data.teams[team]["primary_score" if category=="primary" else "secondary_score"]+=points
	game.manager.scores[team]+=points

static func update(game: Node) -> void:
	var manager: GameManager=game.manager
	if manager.missions.is_empty() or manager.deployment or game.replay_mode:return
	var data: Dictionary=manager.missions
	if manager.round_number>int(data.round) and not data.finished:
		data.round=manager.round_number
		for team in ["0","1"]:
			var state: Dictionary=data.teams[team]
			state.alive_at_draw=[]
			for unit: TableUnit in game.battlefield.units.get_children():
				if not unit.living_models().is_empty():state.alive_at_draw.append(str(unit.name))
			state.discard.append_array(state.active);state.active=[]
			if data.tactical:
				for i in 2:
					if state.draw.is_empty():state.draw=state.discard.duplicate();state.discard=[]
					if not state.draw.is_empty():state.active.append(state.draw.pop_front())
	if manager.phase==5 and manager.active_team==1 and not data.scored.has(manager.round_number):
		var owners:=ownership(game)
		for team in ["0","1"]:
			var controlled:=0;var enemy:=0
			for id in owners:
				if owners[id]==int(team):controlled+=1
				elif owners[id]>=0:enemy+=1
			var points:=mini(6,controlled*2)
			if data.primary=="convergence":points=mini(6,controlled+progress(game,int(team),"central")*3)
			if data.primary=="domination":points=5 if controlled>enemy else 2 if controlled>0 else 0
			award(game,team,points,"Primary: "+data.primary,"primary")
			var state: Dictionary=data.teams[team]
			for id: String in state.active:
				var mission:=card(id)
				if progress(game,int(team),mission.condition)>=int(mission.count):
					award(game,team,int(mission.points),mission.title,id);state.completed.append(id)
		data.previous_owners=owners
		data.scored.append(manager.round_number)
		if manager.round_number>=6:data.finished=true
		if data.finished:data["outcome"]={"reason":"Six rounds completed.","winner":0 if manager.scores["0"]>manager.scores["1"] else 1 if manager.scores["1"]>manager.scores["0"] else -1}

static func finish_elimination(game: Node) -> void:
	if game.manager.missions.is_empty() or game.manager.missions.finished or game.manager.deployment or game.replay_mode:return
	if game.network_session!=null and not game.network_session.host:return
	if game.combat.current!=null and game.combat.current.remaining>0:return
	var alive:=[0,0]
	for unit: TableUnit in game.battlefield.units.get_children():alive[unit.team]+=unit.living_models().size()
	if alive[0]>0 and alive[1]>0:return
	var before: Dictionary=game.manager.snapshot()
	game.manager.missions.finished=true
	game.manager.missions["outcome"]={"reason":"Opposing force defeated.","winner":0 if alive[0]>0 else 1 if alive[1]>0 else -1}
	game.manager.changed.emit();game.manager.transitioned.emit(before,game.manager.snapshot())

static func position_bonus(game: Node, unit: TableUnit, point: Vector3) -> float:
	if game.manager.missions.is_empty():return 0
	var bonus:=0.0
	for id: String in game.manager.missions.teams[str(unit.team)].active:
		var mission:=card(id)
		var factor:=float(mission.points)
		match mission.condition:
			"center":bonus+=factor*maxf(0,1-Vector2(point.x,point.z).length()/15)
			"advance","behind":bonus+=factor*clampf(-point.z*(1 if unit.team==0 else -1)/game.battlefield.depth+.5,0,1)
			"control","central","enemy_objective","sabotage","defend":
				for objective: TableObjective in game.battlefield.objectives.get_children():
					if mission.condition=="central" and objective!=central(game):continue
					if mission.condition=="enemy_objective" and objective.position.z*(1 if unit.team==0 else -1)>=0:continue
					if mission.condition=="defend" and objective.position.z*(1 if unit.team==0 else -1)<0:continue
					bonus+=factor*maxf(0,1-point.distance_to(objective.position)/18)
	return bonus
