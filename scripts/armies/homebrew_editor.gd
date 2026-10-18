class_name HomebrewEditor
extends Control

var app: Node
var document: Dictionary
var left: VBoxContainer
var form: VBoxContainer
var status: Label
var category:="Faction"
var selected:=0
var files: FileDialog
var exporting:=false
var dirty:=false
var confirm: ConfirmationDialog

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background:=ColorRect.new();background.color=Color("111a24");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,24)
	var body:=VBoxContainer.new();margin.add_child(body)
	var toolbar:=AppUI.row(body);AppUI.label(toolbar,"CUSTOM FACTIONS · HOMEBREW",27).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	AppUI.button(toolbar,"Save draft",save_draft)
	AppUI.button(toolbar,"Install / update pack",func():status.text=HomebrewPack.install(document);dirty=false;refresh())
	AppUI.button(toolbar,"Export rules",func():
		var issue:=HomebrewPack.validate(document)
		if not issue.is_empty():status.text=issue;return
		exporting=true;files.file_mode=FileDialog.FILE_MODE_SAVE_FILE;files.current_file=document.manifest.id+".json";files.popup_centered_ratio(.7))
	AppUI.button(toolbar,"Main menu",func():
		if not dirty:queue_free();app.show_main();return
		confirm.dialog_text="Discard unsaved faction changes?";confirm.popup_centered())
	var columns:=HBoxContainer.new();columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(columns)
	left=panel(columns,290);form=panel(columns,600)
	status=AppUI.label(body,"Creator-assigned points are not a balance guarantee. Export contains rules only, without models or scripts.",14);status.custom_minimum_size.y=48;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	confirm=ConfirmationDialog.new();confirm.confirmed.connect(func():queue_free();app.show_main());add_child(confirm)
	files=FileDialog.new();files.access=FileDialog.ACCESS_FILESYSTEM;files.filters=PackedStringArray(["*.json ; GrimTable homebrew rules pack"]);add_child(files)
	files.file_selected.connect(func(path: String):
		if exporting:status.text="Exported versioned rules pack." if WorkshopStore.atomic_json(path,document) else "Export failed."
		else:
			var data:=WorkshopStore.read_json(path,2000000);var issue:=HomebrewPack.validate(data)
			if not issue.is_empty():status.text=issue;return
			document=data;dirty=true;category="Faction";refresh())
	new_pack()

func panel(parent: Node, width: float) -> VBoxContainer:
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.x=width;scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(box);return box

func new_pack() -> void:
	document=HomebrewPack.fresh("homebrew_"+str(Time.get_ticks_msec()))
	var commander:=HomebrewPack.unit(document);commander.name="Expedition Guide";commander.roster.role="Leader";commander.roster.min_size=1;commander.roster.max_size=1;commander.roster.points_per_model=75;commander.max_wounds=5;commander.wounds=5;document.units.append(commander)
	document.units.append(HomebrewPack.unit(document));category="Faction";selected=0;dirty=false;refresh()

func edited() -> void:dirty=true

func save_draft() -> void:
	if not ModLoader.manifest_error(document.manifest).is_empty():status.text="Set valid metadata before saving.";return
	status.text="Saved local faction draft." if WorkshopStore.atomic_json(HomebrewPack.ROOT+document.manifest.id+".json",document) else "Save failed."
	dirty=false;refresh()

func clear(box: Node) -> void:
	for child in box.get_children():box.remove_child(child);child.queue_free()

func refresh() -> void:
	clear(left);clear(form)
	AppUI.label(left,"FACTION COLLECTION",20)
	AppUI.button(left,"New faction",new_pack)
	AppUI.button(left,"Import rules pack",func():exporting=false;files.file_mode=FileDialog.FILE_MODE_OPEN_FILE;files.popup_centered_ratio(.7))
	if DirAccess.dir_exists_absolute(HomebrewPack.ROOT):
		for file in DirAccess.get_files_at(HomebrewPack.ROOT):
			var saved:=WorkshopStore.read_json(HomebrewPack.ROOT+file,2000000)
			if saved.get("kind")=="grimtable_content_pack":AppUI.button(left,str(saved.manifest.name),func():document=saved.duplicate(true);category="Faction";dirty=false;refresh())
	AppUI.button(left,"Faction identity",func():category="Faction";refresh())
	AppUI.label(left,"UNIT ROSTER",18)
	for i in document.units.size():
		var index: int=i
		AppUI.button(left,str(document.units[i].name),func():category="Unit";selected=index;refresh())
	AppUI.button(left,"Add unit",func():document.units.append(HomebrewPack.unit(document));selected=document.units.size()-1;category="Unit";dirty=true;refresh())
	AppUI.label(left,"WEAPON CATALOG",18)
	for i in document.weapons.size():
		var index: int=i
		AppUI.button(left,str(document.weapons[i].name),func():category="Weapon";selected=index;refresh())
	AppUI.button(left,"Add weapon",func():document.weapons.append(HomebrewPack.weapon(document));selected=document.weapons.size()-1;category="Weapon";dirty=true;refresh())
	if category=="Faction":faction_form()
	elif category=="Unit" and selected<document.units.size():unit_form(document.units[selected])
	elif category=="Weapon" and selected<document.weapons.size():weapon_form(document.weapons[selected])
	var issue:=HomebrewPack.validate(document)
	if not issue.is_empty():status.text=issue

func text_field(caption: String, object: Dictionary, key: String, limit: int=100) -> void:
	var control:=AppUI.text(form,caption,str(object.get(key,"")));control.max_length=limit
	control.text_changed.connect(func(value: String):object[key]=value;edited())

func number(caption: String, object: Dictionary, key: String, lo: float, hi: float, step: float=1) -> void:
	var control:=AppUI.spin(form,caption,float(object.get(key,lo)),lo,hi,step)
	control.value_changed.connect(func(value: float):object[key]=int(value) if step==1 else value;edited())

func faction_form() -> void:
	AppUI.label(form,"Original faction identity",24)
	AppUI.label(form,"Pack ID: "+str(document.manifest.id)+" · all profiles are marked Homebrew.",14)
	text_field("Faction name",document.factions[0],"name")
	text_field("Pack title",document.manifest,"name")
	text_field("Author",document.manifest,"author")
	text_field("Version (increase this when sharing updates)",document.manifest,"version",24)
	text_field("Description",document.factions[0],"description",2000)
	for key in ["color","accent"]:
		AppUI.label(form,str(key).capitalize(),15)
		var picker:=ColorPickerButton.new();picker.color=Color(document.factions[0][key]);form.add_child(picker)
		picker.color_changed.connect(func(value: Color):document.factions[0][key]="#"+value.to_html(false);edited())
	var emblems: Array=["Diamond","Circle","Chevron","Cross"]
	var emblem:=AppUI.choices(form,emblems,emblems.find(document.factions[0].emblem))
	var symbol:=AppUI.label(form,str({"Diamond":"◇","Circle":"○","Chevron":"⌃","Cross":"+"}[document.factions[0].emblem]),48)
	emblem.item_selected.connect(func(i: int):document.factions[0].emblem=emblems[i];symbol.text=str({"Diamond":"◇","Circle":"○","Chevron":"⌃","Cross":"+"}[emblems[i]]);edited())
	AppUI.label(form,"Supported abilities are explicit weapon traits. No scripts or arbitrary faction effects are executed. Assign painted/imported miniatures to the installed units in Army Builder.",15).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func unit_form(unit: Dictionary) -> void:
	AppUI.label(form,"Unit profile",24);AppUI.label(form,unit.id,13)
	text_field("Name",unit,"name")
	var roles:=AppUI.choices(form,ArmyRoster.ROLES,ArmyRoster.ROLES.find(unit.roster.role));roles.item_selected.connect(func(i: int):unit.roster.role=ArmyRoster.ROLES[i];edited())
	for entry in [["Movement", "movement",1,24],["Defense", "defense",1,20],["Save threshold", "save",2,7],["Health per model", "max_wounds",1,100],["Base diameter (mm)", "base_mm",10,200]]:number(entry[0],unit,entry[1],entry[2],entry[3])
	for entry in [["Minimum squad size","min_size",1,100],["Maximum squad size","max_size",1,100],["Maximum units in army","max_units",1,100],["Points per model","points_per_model",1,10000],["Fixed squad cost","base_points",0,10000]]:number(entry[0],unit.roster,entry[1],entry[2],entry[3])
	AppUI.label(form,"Weapons — every model equips the selected baseline weapons",18)
	var weapons: Dictionary=ContentRegistry._builtin.weapons.duplicate()
	for w in document.weapons:weapons[w.id]=w
	for id: String in weapons:
		var toggle:=CheckBox.new();toggle.text=id;toggle.button_pressed=unit.weapons.has(id);form.add_child(toggle)
		toggle.toggled.connect(func(on: bool):
			if on and not unit.weapons.has(id):unit.weapons.append(id)
			elif not on:unit.weapons.erase(id)
			edited())
	AppUI.label(form,"Army battles allow one weapon per model in each combat phase. Multiple equipped ranged weapons are alternatives.",14).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var ids: Array=ContentRegistry._builtin.units.keys();var visual:=AppUI.choices(form,ids,maxi(0,ids.find(unit.fallback_visual)))
	visual.item_selected.connect(func(i: int):unit.fallback_visual=ids[i];edited())
	AppUI.button(form,"Remove unit",func():document.units.remove_at(selected);category="Faction";dirty=true;refresh())

func weapon_form(weapon: Dictionary) -> void:
	AppUI.label(form,"Weapon profile",24);AppUI.label(form,weapon.id,13)
	text_field("Name",weapon,"name")
	var types: Array=["ranged","melee"];var type:=AppUI.choices(form,types,types.find(weapon.type));type.item_selected.connect(func(i: int):weapon.type=types[i];edited())
	for entry in [["Range (inches)","range",0,120],["Attacks per equipped model","attacks",1,20],["Hit threshold","hit",2,7],["Strength","strength",1,30],["Armor penetration penalty","ap",0,10],["Damage per failed defense","damage",1,20]]:number(entry[0],weapon,entry[1],entry[2],entry[3])
	for ability in [["anti_heavy","Anti-heavy: +2 Strength against Vehicles, Walkers and Creatures"],["anti_infantry","Anti-infantry: +1 Strength against Infantry, Specialists and Leaders"]]:
		var toggle:=CheckBox.new();toggle.text=ability[1];toggle.button_pressed=weapon.tags.has(ability[0]);form.add_child(toggle)
		toggle.toggled.connect(func(on: bool):
			if on and not weapon.tags.has(ability[0]):weapon.tags.append(ability[0])
			elif not on:weapon.tags.erase(ability[0])
			edited())
	AppUI.button(form,"Remove weapon",func():document.weapons.remove_at(selected);category="Faction";dirty=true;refresh())
