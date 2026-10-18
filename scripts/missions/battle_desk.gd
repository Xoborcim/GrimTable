class_name BattleDesk
extends Node

var game: Node3D
var panel: PanelContainer
var rows: VBoxContainer
var mode := "Missions"
var last_draw := ""
var reveal: PanelContainer
var clock := 0.0
var roster_filter := ""
var roster_state := 0
var bar: HBoxContainer

func _ready() -> void:
	if not game.scenario.get("strict_armies",false):return
	var layer:=CanvasLayer.new();layer.layer=9;add_child(layer)
	var header: Node=game.hud.top_panel.get_child(0)
	if header is VBoxContainer:header=header.get_child(0)
	bar=HBoxContainer.new();bar.theme=GrimTheme.theme();header.add_child(bar)
	AppUI.button(bar,"Missions",func():toggle("Missions"))
	AppUI.button(bar,"Army roster",func():toggle("Roster"))
	panel=PanelContainer.new();panel.position=Vector2(420,132);panel.custom_minimum_size=Vector2(420,200);panel.theme=GrimTheme.theme();layer.add_child(panel)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(420,350);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	rows=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(rows);panel.hide()
	game.manager.changed.connect(refresh)
	refresh()

func toggle(category: String) -> void:
	panel.visible=not panel.visible or mode!=category;mode=category;refresh()

func _process(delta: float) -> void:
	if panel==null:return
	MissionRules.finish_elimination(game)
	clock+=delta
	if clock>.5:
		clock=0
		if mode=="Missions":refresh()
	if not game.replay_mode and not game.manager.deployment and not game.manager.missions.is_empty() and game.manager.missions.finished and not game.ai.summary_shown:
		game.ai.finished=true;game.ai.reason=game.manager.missions.get("outcome",{}).get("reason","Battle completed.");game.interaction.read_only=true;game.call_deferred("show_match_summary")

func refresh() -> void:
	if rows==null or not is_inside_tree() or is_queued_for_deletion():return
	if panel.visible:
		for child in rows.get_children():rows.remove_child(child);child.queue_free()
		if mode=="Missions":mission_view()
		else:roster_view()
	var data: Dictionary=game.manager.missions
	if data.is_empty() or game.manager.deployment or game.replay_mode:return
	var team:=str(game.manager.active_team)
	var key:=str(data.round)+":"+team
	if key==last_draw:return
	last_draw=key
	if is_instance_valid(reveal):reveal.queue_free()
	reveal=PanelContainer.new();reveal.theme=GrimTheme.theme();reveal.position=Vector2(890,140);get_child(0).add_child(reveal)
	var box:=VBoxContainer.new();reveal.add_child(box)
	AppUI.label(box,"ROUND "+str(data.round)+" · TEAM "+team+" TACTICAL ORDERS",16)
	for id: String in data.teams[team].active:AppUI.label(box,str(MissionRules.card(id).title),20)
	if not game.settings.reduce_motion:
		reveal.modulate.a=0;create_tween().tween_property(reveal,"modulate:a",1.0,.25)
	var card_panel:=reveal
	get_tree().create_timer(3).timeout.connect(func():if is_instance_valid(card_panel):card_panel.queue_free())

func _exit_tree() -> void:
	if is_instance_valid(bar):bar.queue_free()

func mission_view() -> void:
	var data: Dictionary=game.manager.missions
	if data.is_empty():AppUI.label(rows,"Scenario objective scoring.");return
	AppUI.label(rows,"PRIMARY · "+str(data.primary).capitalize(),20)
	for primary: Dictionary in MissionRules.catalog().primaries:
		if primary.id==data.primary:AppUI.label(rows,primary.text,14).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for team in ["0","1"]:
		var state: Dictionary=data.teams[team]
		AppUI.label(rows,"Team "+team+" · Primary "+str(state.primary_score)+" / Tactical "+str(state.secondary_score),17)
		for id: String in state.active:
			var mission:=MissionRules.card(id)
			var progress:=MissionRules.progress(game,int(team),mission.condition)
			AppUI.label(rows,mission.title+" · "+str(progress)+" / "+str(int(mission.count))+" · "+str(int(mission.points))+" VP",17)
			AppUI.label(rows,mission.text+" Scores at round end; then expires.",13).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	AppUI.label(rows,"SCORING HISTORY",17)
	for award: Dictionary in data.ledger:
		AppUI.label(rows,"R"+str(award.round)+" · Team "+award.team+" · "+award.title+" +"+str(award.points),13)

func roster_view() -> void:
	AppUI.label(rows,"ARMY ROSTER · select and focus",20)
	var filter_text:=AppUI.text(rows,"Search squad name",roster_filter)
	var filter_state:=AppUI.choices(rows,["All units","Ready to move","Already moved","Destroyed"],roster_state)
	AppUI.button(rows,"Apply filter",func():roster_filter=filter_text.text;roster_state=filter_state.selected;refresh())
	if game.manager.deployment:
		for angle in [-15,15]:
			AppUI.button(rows,"Rotate selected formation "+str(angle)+"°",func():
				var model: Miniature=game.selection.primary()
				game.hud.set_status(ArmyDeployment.rotate(game,model.get_parent() as TableUnit if model!=null else null,angle)))
	var state:=PhaseAssistant.states(game.battle_log,game.manager.round_number,1,true)
	for unit: TableUnit in game.battlefield.units.get_children():
		var alive:=unit.living_models()
		var ready:=int(state.get(str(unit.name),{}).get("moved",0))==0
		if not roster_filter.is_empty() and not unit.display_name.to_lower().contains(roster_filter.to_lower()):continue
		if roster_state==1 and (not ready or alive.is_empty()):continue
		if roster_state==2 and (ready or alive.is_empty()):continue
		if roster_state==3 and not alive.is_empty():continue
		var button:=AppUI.button(rows,"T"+str(unit.team)+" · "+unit.display_name+" · "+str(alive.size())+" / "+str(unit.models.size())+(" · Ready" if ready else " · Moved"),func():
			game.selection.select_unit(unit)
			if not unit.living_models().is_empty():game.camera_rig.destination=FormationPlanner.center(unit.living_models()))
		button.disabled=alive.is_empty()
