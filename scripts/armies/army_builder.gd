class_name ArmyBuilder
extends Control

var app: Node
var army: Dictionary
var selected := -1
var collection: VBoxContainer
var squads: VBoxContainer
var detail: VBoxContainer
var summary: Label
var notice: Label
var confirm: ConfirmationDialog
var files: FileDialog
var exporting := false
var dirty := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background:=ColorRect.new();background.color=Color("111a24");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,22)
	add_child(margin)
	var body:=VBoxContainer.new();margin.add_child(body)
	var toolbar:=AppUI.row(body)
	AppUI.label(toolbar,"ARMY BUILDER",28).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	AppUI.button(toolbar,"Battle setup",func():guard(func():queue_free();app.show_army_battle()))
	AppUI.button(toolbar,"Main menu",func():guard(func():queue_free();app.show_main()))
	var columns:=HBoxContainer.new();columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(columns)
	collection=panel(columns,240);squads=panel(columns,330);detail=panel(columns,410)
	summary=AppUI.label(body,"",18)
	notice=AppUI.label(body,"",14);notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.y=62
	confirm=ConfirmationDialog.new();add_child(confirm)
	files=FileDialog.new();files.access=FileDialog.ACCESS_FILESYSTEM;files.filters=PackedStringArray(["*.json ; GrimTable army list"]);add_child(files)
	files.file_selected.connect(func(path: String):
		if exporting:
			notice.text="Exported army list (cosmetic references only)." if WorkshopStore.atomic_json(path,army) else "Export failed."
		else:
			var result:=ArmyRoster.import_file(path)
			if result.has("error"):notice.text=result.error
			else:army=result.data;selected=-1;dirty=true;refresh())
	army=ArmyRoster.fresh();refresh()

func panel(parent: Node, minimum: float) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=minimum;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(box);return box

func clear(box: Node) -> void:
	for child in box.get_children():box.remove_child(child);child.queue_free()

func guard(action: Callable) -> void:
	if not dirty:action.call();return
	confirm.title="Unsaved army";confirm.dialog_text="Discard changes to this army?"
	for connection in confirm.confirmed.get_connections():confirm.confirmed.disconnect(connection.callable)
	confirm.confirmed.connect(action,CONNECT_ONE_SHOT);confirm.popup_centered()

func changed() -> void:
	dirty=true;validate_army()

func validate_army() -> void:
	var cost:=ArmyRoster.total(army)
	summary.text=army.name+" — "+str(cost)+" / "+str(int(army.points_limit))+" points · "+str(int(army.points_limit)-cost)+" remaining"+(" · UNSAVED" if dirty else "")
	var issues:=ArmyRoster.errors(army)
	notice.text="Legal army — ready for battle." if issues.is_empty() else "\n".join(issues)

func refresh() -> void:
	clear(collection);clear(squads);clear(detail)
	AppUI.label(collection,"COLLECTION",20)
	AppUI.button(collection,"New army",func():guard(func():army=ArmyRoster.fresh();selected=-1;dirty=false;refresh()))
	AppUI.button(collection,"Import army JSON",func():guard(func():exporting=false;files.file_mode=FileDialog.FILE_MODE_OPEN_FILE;files.popup_centered_ratio(.7)))
	for record in ArmyRoster.records():
		var data: Dictionary=record
		AppUI.button(collection,data.name+"\n"+str(ArmyRoster.total(data))+" / "+str(int(data.points_limit)),func():guard(func():army=data.duplicate(true);selected=-1;dirty=false;refresh()))
	var name_edit:=AppUI.text(squads,"Army name",army.name);name_edit.max_length=100
	name_edit.text_changed.connect(func(value: String):army.name=value;changed())
	var factions: Array=ContentRegistry.catalog().factions.keys()
	var names: Array=[]
	for id in factions:names.append(ContentRegistry.catalog().factions[id].name)
	var faction:=AppUI.choices(squads,names,maxi(0,factions.find(army.faction)))
	faction.item_selected.connect(func(i: int):
		if factions[i]==army.faction:return
		confirm.title="Change faction";confirm.dialog_text="Change faction and remove this list's units?"
		for connection in confirm.confirmed.get_connections():confirm.confirmed.disconnect(connection.callable)
		confirm.confirmed.connect(func():army.faction=factions[i];army.homebrew=":" in army.faction;army.units=[];army.profiles={};selected=-1;dirty=true;refresh(),CONNECT_ONE_SHOT);confirm.popup_centered())
	var sizes:=AppUI.choices(squads,["500 — Skirmish","1,000 — Incursion","2,000 — Full battle","Custom"],[500,1000,2000].find(int(army.points_limit)) if int(army.points_limit) in [500,1000,2000] else 3)
	sizes.item_selected.connect(func(i: int):if i<3:army.points_limit=[500,1000,2000][i];changed();refresh())
	var budget:=AppUI.spin(squads,"Points limit",army.points_limit,100,10000,1);budget.value_changed.connect(func(value: float):army.points_limit=int(value);changed())
	var actions:=AppUI.row(squads)
	AppUI.button(actions,"Save",save_army)
	AppUI.button(actions,"Duplicate",func():army=army.duplicate(true);army.id=ArmyRoster.new_id();army.name+=" copy";dirty=true;refresh())
	AppUI.button(actions,"Export",func():exporting=true;files.file_mode=FileDialog.FILE_MODE_SAVE_FILE;files.current_file=army.id+".json";files.popup_centered_ratio(.7))
	AppUI.button(squads,"Delete saved list…",func():
		confirm.title="Delete army";confirm.dialog_text="Delete this local saved list? Built-in starters remain available."
		for connection in confirm.confirmed.get_connections():confirm.confirmed.disconnect(connection.callable)
		confirm.confirmed.connect(func():
			if ArmyRoster.remove(army.id):army=ArmyRoster.fresh();selected=-1;dirty=false;refresh()
			else:notice.text="Built-in starter lists cannot be deleted. Duplicate one to edit your own copy.",CONNECT_ONE_SHOT);confirm.popup_centered())
	AppUI.button(squads,"Accept updated profiles",func():ArmyRoster.stamp(army);dirty=true;refresh())
	AppUI.label(squads,"UNITS",20)
	for i in army.units.size():
		var index: int=i
		var item: Dictionary=army.units[i]
		AppUI.button(squads,("› " if i==selected else "")+item.name+" ×"+str(int(item.count))+" — "+str(ArmyRoster.cost(item)),func():selected=index;refresh())
	AppUI.label(squads,"ADD UNIT",18)
	var choices: Array=[];var ids: Array=[]
	for id: String in ContentRegistry.catalog().units:
		var p:=ArmyRoster.profile(id)
		if p.get("faction")!=army.faction:continue
		ids.append(id);choices.append(str(p.get("roster",{}).get("role","Uncosted"))+" · "+p.name)
	var add_choice:=AppUI.choices(squads,choices)
	AppUI.button(squads,"Add selected unit",func():
		if add_choice.selected<0:return
		army.units.append(ArmyRoster.entry(ids[add_choice.selected]));selected=army.units.size()-1;changed();refresh())
	refresh_detail();validate_army()

func save_army() -> void:
	if army.id.begins_with("army_starter_"):army.id=ArmyRoster.new_id()
	if army.profiles.is_empty():ArmyRoster.stamp(army)
	var message:=ArmyRoster.save(army)
	if message.begins_with("Saved"):dirty=false;refresh()
	notice.text=message+"\n"+("Legal army." if ArmyRoster.errors(army).is_empty() else "Saved as a draft. Resolve validation errors before battle.")

func refresh_detail() -> void:
	if selected<0 or selected>=army.units.size():AppUI.label(detail,"Choose a squad to configure it.",18);return
	var item: Dictionary=army.units[selected]
	var p:=ArmyRoster.profile(item.unit_id)
	AppUI.label(detail,p.get("name",item.unit_id),22)
	if p.is_empty():AppUI.label(detail,"Missing content. This entry is preserved; restore its pack or remove it.");return
	var rules: Dictionary=p.get("roster",{})
	var name_edit:=AppUI.text(detail,"Squad name",item.name);name_edit.max_length=100;name_edit.text_changed.connect(func(value: String):item.name=value;changed())
	var count:=AppUI.spin(detail,"Models",item.count,1,100)
	count.value_changed.connect(func(value: float):item.count=int(value);changed())
	AppUI.label(detail,"Legal size: "+str(int(rules.get("min_size",1)))+"–"+str(int(rules.get("max_size",1)))+" · "+str(int(rules.get("points_per_model",0)))+" points/model",14)
	AppUI.label(detail,'Move %s" · Defense %s · Save %s+ · Health %s/model' % [str(p.movement).trim_suffix(".0"),int(p.defense),int(p.save),int(p.max_wounds)],15)
	AppUI.label(detail,"EQUIPMENT",18)
	for id: String in p.weapons:weapon_label(detail,ArmyRoster.weapon(id))
	for option: Dictionary in rules.get("upgrades",[]):
		weapon_label(detail,ArmyRoster.weapon(option.weapon))
		var spin:=AppUI.spin(detail,"Replace "+option.replaces+" · +"+str(int(option.points))+" pts",item.upgrades.get(option.weapon,0),0,100)
		AppUI.label(detail,"One per "+str(int(option.per_models))+" models. Replaces the original weapon on those models.",13).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		spin.value_changed.connect(func(value: float):item.upgrades[option.weapon]=int(value);changed())
	AppUI.label(detail,"COSMETIC MINIATURE",18)
	var references: Array=[""];var labels: Array=["Default / existing library assignment"]
	for figure in WorkshopStore.records():
		if figure.source==item.unit_id or figure.source==ArmyCosmetics.family(p) or WorkshopAppearance.imported_record(figure.source).get("profile")==item.unit_id:references.append(figure.id);labels.append("Painted: "+figure.name)
	for record in MiniatureLibrary.records():
		if record.get("profile")==item.unit_id:references.append(record.id);labels.append("Imported: "+record.name)
	if not references.has(item.cosmetic):references.append(item.cosmetic);labels.append("Unavailable: "+item.cosmetic+" (fallback visuals)")
	var cosmetic:=AppUI.choices(detail,labels,references.find(item.cosmetic));cosmetic.item_selected.connect(func(i: int):item.cosmetic=references[i];changed())
	AppUI.label(detail,"Cosmetic models keep this profile's stats, equipment and base diameter.",13).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var schemes: Array=WorkshopStore.saved_schemes()
	for scheme_name in WorkshopStore.PRESETS:
		var data:=WorkshopStore.fresh();var colors: Array=WorkshopStore.PRESETS[scheme_name]
		data.colors.primary=colors[0];data.colors.secondary=colors[1];data.colors.trim=colors[2]
		schemes.append(WorkshopStore.scheme(data,scheme_name))
	var scheme_names: Array=[]
	for scheme in schemes:scheme_names.append(scheme.name)
	var scheme_choice:=AppUI.choices(detail,scheme_names)
	for scope in ["This squad","All compatible squads"]:
		AppUI.button(detail,"Apply paint scheme · "+scope,func():
			var result:=ArmyCosmetics.apply_scheme(army,schemes[scheme_choice.selected],selected if scope=="This squad" else -1)
			if result.has("error"):notice.text=result.error;return
			dirty=true;refresh();notice.text="Applied to "+str(result.applied)+" compatible squads. Parts, brush paint and bases were preserved in new local variants.")
	AppUI.button(detail,"Save reusable loadout",func():
		var value:={"kind":"grimtable_loadout","version":1,"unit_id":item.unit_id,"name":item.name,"count":item.count,"upgrades":item.upgrades.duplicate(true)}
		var issue:=ArmyRoster.loadout_error(value,item.unit_id)
		if not issue.is_empty():notice.text=issue;return
		notice.text="Saved loadout." if WorkshopStore.atomic_json("user://army_loadouts/"+item.id+".json",value) else "Save failed.")
	if DirAccess.dir_exists_absolute("user://army_loadouts"):
		for file in DirAccess.get_files_at("user://army_loadouts"):
			var preset:=WorkshopStore.read_json("user://army_loadouts/"+file)
			if preset.get("kind")=="grimtable_loadout" and ArmyRoster.loadout_error(preset,item.unit_id).is_empty():
				AppUI.button(detail,"Load: "+str(preset.name),func():item.count=preset.count;item.upgrades=preset.upgrades.duplicate(true);dirty=true;refresh())
	AppUI.button(detail,"Remove squad",func():army.units.remove_at(selected);selected=-1;dirty=true;refresh())

static func weapon_label(parent: Node, w: Dictionary) -> void:
	AppUI.label(parent,'%s · %s" · %s attacks · %s+ hit · S%s · AP%s · D%s' % [w.get("name","Missing weapon"),str(w.get("range",0)).trim_suffix(".0"),str(w.get("attacks",0)).trim_suffix(".0"),str(w.get("hit",0)).trim_suffix(".0"),str(w.get("strength",0)).trim_suffix(".0"),str(w.get("ap",0)).trim_suffix(".0"),str(w.get("damage",0)).trim_suffix(".0")],14).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
