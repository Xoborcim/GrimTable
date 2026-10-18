class_name ArmyLobbyPanel
extends CanvasLayer

var session: NetworkSession
var caption: Label
var agree: Button
func _ready() -> void:
	layer=17
	var shade:=ColorRect.new();shade.color=Color(0.02,.03,.04,.88);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shade)
	var panel:=PanelContainer.new();panel.theme=GrimTheme.theme();panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER);panel.offset_left=-300;panel.offset_right=300;panel.offset_top=-225;panel.offset_bottom=225;shade.add_child(panel)
	var rows:=VBoxContainer.new();panel.add_child(rows)
	AppUI.label(rows,"ARMY & MISSION AGREEMENT",24)
	caption=AppUI.label(rows,"Waiting for the other player's army…",16);caption.custom_minimum_size=Vector2(560,200);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	agree=AppUI.button(rows,"Accept these armies and battle rules",func():session.accept_armies())
	agree.disabled=true
	AppUI.button(rows,"Leave and change selection",func():session.game.get_parent().show_main())
	session.status_changed.connect(func(text: String):caption.text=text;refresh())
	refresh()

func refresh() -> void:
	visible=not session.army_match_ready
	if session.army_pending.is_empty():return
	var data: Dictionary=session.army_pending.data
	var text: String=data.name+"\n\n"+str(session.army_rules.points)+" points · "+str(session.army_rules.primary).capitalize()+"\nTactical cards: "+("On" if session.army_rules.tactical else "Off")+" · Homebrew: "+("Allowed" if session.army_rules.homebrew else "Disabled")+"\nSeed: "+str(session.army_rules.seed)+"\nContent: matching gameplay pack versions and fingerprints\n\n"
	for army in data.army_lists:text+=str(army.name)+" · "+str(ArmyRoster.total(army))+" points · "+str(army.units.size())+" squads\n"
	caption.text=text+("\nYou accepted; waiting for the other player." if session.army_accepted.get("0" if session.host else "1",false) else "\nReview the armies and rules before accepting.")
	agree.disabled=session.army_accepted.get("0" if session.host else "1",false)
