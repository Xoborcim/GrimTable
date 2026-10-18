class_name ArmyBattleSetup
extends RefCounted

static func show_menu(app: Node) -> void:
	app.clear_menu("Battle setup — saved armies")
	var box: VBoxContainer=app.column
	var lists:=ArmyRoster.records()
	if lists.is_empty():AppUI.label(box,"Create an army first.");AppUI.button(box,"Army Builder",app.show_army_builder);return
	var labels: Array=[]
	for army in lists:labels.append(army.name+" · "+str(ArmyRoster.total(army))+" pts")
	AppUI.label(box,"Battle size")
	var size:=AppUI.choices(box,["500 — Skirmish","1,000 — Incursion","2,000 — Full battle","Custom"])
	var budget:=AppUI.spin(box,"Agreed points limit",500,100,10000)
	size.item_selected.connect(func(i: int):if i<3:budget.value=[500,1000,2000][i])
	AppUI.label(box,"Team A army")
	var team_a:=AppUI.choices(box,labels)
	AppUI.label(box,"Team B / AI army")
	var team_b:=AppUI.choices(box,labels)
	var update_choices:=func():
		for i in lists.size():
			if lists[i].points_limit==int(budget.value) and lists[i].faction=="legion":team_a.select(i)
			if lists[i].points_limit==int(budget.value) and lists[i].faction=="swarm":team_b.select(i)
	budget.value_changed.connect(func(_value: float):update_choices.call())
	update_choices.call()
	AppUI.label(box,"Opponent")
	var opponent:=AppUI.choices(box,["Human (A) vs local AI (B)","Local two player","AI vs AI — spectate"])
	var difficulty:=AppUI.choices(box,["Easy","Normal","Hard"],1)
	var maps:=ScenarioLibrary.list_scenarios().filter(func(item):return item.has("data"))
	var names: Array=[]
	for item in maps:names.append(item.data.name)
	AppUI.label(box,"Battlefield")
	var map_choice:=AppUI.choices(box,names)
	AppUI.label(box,"Primary mission")
	var primary:=AppUI.choices(box,["Secure the Field","Convergence","Network Superiority"])
	var tactical:=CheckBox.new();tactical.text="Tactical mission cards — two per team each round";tactical.button_pressed=true;box.add_child(tactical)
	var seed_input:=AppUI.spin(box,"Battle / mission seed",15150,0,2147483647)
	var boards:=AppUI.choices(box,['60" × 44"','90" × 44"','Custom'])
	var width:=AppUI.spin(box,"Width (inches)",60,60,120)
	var depth:=AppUI.spin(box,"Depth (inches)",44,44,120)
	boards.item_selected.connect(func(i: int):if i<2:width.value=[60,90][i];depth.value=44)
	var preset_name:=AppUI.text(box,"Save this setup as","Legion vs Swarm")
	AppUI.button(box,"Save battle preset",func():app.status.text=BattlePreset.save({"kind":"grimtable_battle_preset","version":1,"name":preset_name.text,"army_a":lists[team_a.selected].id,"army_b":lists[team_b.selected].id,"scenario":maps[map_choice.selected].data.id,"points":int(budget.value),"width":int(width.value),"depth":int(depth.value),"opponent":opponent.selected,"difficulty":difficulty.selected,"primary":primary.selected,"tactical":tactical.button_pressed,"seed":int(seed_input.value)}))
	for preset in BattlePreset.records():
		AppUI.button(box,"Load setup: "+str(preset.name),func():
			var a:=-1;var b:=-1;var scenario_index:=-1
			for i in lists.size():
				if lists[i].id==preset.army_a:a=i
				if lists[i].id==preset.army_b:b=i
			for i in maps.size():
				if maps[i].data.id==preset.scenario:scenario_index=i
			if a<0 or b<0 or scenario_index<0:app.status.text="A saved army or scenario is missing. Restore it or select a replacement explicitly.";return
			budget.value=preset.points;team_a.select(a);team_b.select(b);map_choice.select(scenario_index);width.value=preset.width;depth.value=preset.depth;opponent.select(preset.opponent);difficulty.select(preset.difficulty);primary.select(preset.primary);tactical.button_pressed=preset.tactical;seed_input.value=preset.seed;preset_name.text=preset.name;app.status.text="Loaded setup. Army legality is checked before starting.")
	AppUI.label(box,"Both lists are validated at the agreed budget. Gameplay profiles are separate from cosmetics.",14).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	AppUI.button(box,"Start battle",func():
		var armies: Array=[lists[team_a.selected].duplicate(true),lists[team_b.selected].duplicate(true)]
		for army in armies:army.points_limit=int(budget.value)
		var result:=ArmyRoster.scenario(maps[map_choice.selected].data,armies,width.value,depth.value)
		if result.has("error"):app.status.text=result.error;return
		result.data.starting_state["missions"]=MissionRules.initial(["control","convergence","domination"][primary.selected],tactical.button_pressed,int(seed_input.value))
		var teams: Dictionary={}
		if opponent.selected!=1:teams["1"]=["Easy","Normal","Hard"][difficulty.selected]
		if opponent.selected==2:teams["0"]=["Easy","Normal","Hard"][difficulty.selected]
		app.pending_ai={"teams":teams,"human_team":0,"seed":int(seed_input.value),"round_limit":6,"speed":app.settings.ai_speed}
		app.launch_with_transition(result))
	AppUI.button(box,"Army Builder",app.show_army_builder)
	AppUI.button(box,"Quick Play — existing preset forces",app.show_local_play)
	AppUI.button(box,"Back",app.show_main)
