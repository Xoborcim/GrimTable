class_name MiniatureWorkshop
extends Control

var app: Node
var initial_source := "legion_trooper"
var document: Dictionary
var saved_fingerprint := ""
var paint_snapshot_key := ""
var paint_snapshot_png := PackedByteArray()
var paint_snapshot_hash := 0
var history: Array[Dictionary]=[]
var history_index := -1
var category := "Paint"
var mode := "Region"
var region := "primary"
var paint_color := Color("c9ad65")
var brush_radius := 12.0
var brush_opacity := .85
var stroke := false
var brush := WorkshopBrush.new()
var viewport: SubViewport
var view: SubViewportContainer
var studio: Node3D
var sculpt: Node3D
var model: Node3D
var base_root: Node3D
var camera: Camera3D
var key_light: DirectionalLight3D
var plinth: MeshInstance3D
var environment: Environment
var controls: VBoxContainer
var title: LineEdit
var state_label: Label
var message: Label
var undo_button: Button
var redo_button: Button
var confirm: ConfirmationDialog
var pending: Callable
var file_dialog: FileDialog
var file_action := "import"
var collection_list: ItemList
var filter_text := ""
var filter_kind := "All"
var filter_faction := "All factions"
var filter_family := "All families"
var filter_profile := "All profiles"
var sort_kind := "Name"
var items: Array[Dictionary]=[]
var thumb_cache: Dictionary={}
var yaw := PI+.4
var pitch := .16
var distance := 3.8
var focus := Vector3(0,.95,0)
var turntable := false
var auto_focus := true
var material_image: Image
var ui_updating := false
var marking_kind := "Stripe"
var marking_size := .025
var marking_angle := 0.0
var marking_text := "07"
var selected_marking := -1
var last_paint_tick := 0
var category_buttons: Dictionary={}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);theme=AppUI.theme()
	var background:=ColorRect.new();background.color=Color("131c24");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(background)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	var main:=VBoxContainer.new();margin.add_child(main)
	var header:=AppUI.row(main)
	AppUI.label(header,"MINIATURE WORKSHOP",23).modulate=Color("d8c49a")
	title=LineEdit.new();title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	title.max_length=100;title.text_submitted.connect(func(value: String):document.name=value;checkpoint())
	title.focus_exited.connect(func():
		if not ui_updating and document.name!=title.text:document.name=title.text;checkpoint())
	state_label=AppUI.label(header,"",13)
	AppUI.button(header,"Guide",show_guide)
	AppUI.button(header,"Exit",func():guard(func():queue_free();app.show_main()))
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;main.add_child(body)
	var left:=VBoxContainer.new();left.custom_minimum_size.x=140;body.add_child(left)
	AppUI.label(left,"HOBBY BENCH",12).modulate=GrimTheme.MUTED
	for name in ["Build","Paint","Pose","Base","Collection"]:
		var button:=AppUI.button(left,name,func():category=name;refresh_controls())
		button.custom_minimum_size.y=48
		category_buttons[name]=button
	AppUI.label(left,"MODEL",12)
	var choices: Array=["Legion infantry","Heavy walker","Swarm creature"]
	var sources: Array=["legion_trooper","legion_walker","swarm_hunter"]
	for imported in MiniatureLibrary.records():choices.append(imported.name);sources.append(imported.id)
	var source_choice:=AppUI.choices(left,choices,maxi(0,sources.find(initial_source)))
	source_choice.custom_minimum_size.x=140;source_choice.clip_text=true
	source_choice.item_selected.connect(func(i: int):guard(func():new_document(sources[i])))
	AppUI.label(left,"Right-drag: orbit\nMiddle-drag: pan\nWheel: zoom",12).modulate=GrimTheme.MUTED
	var middle:=VBoxContainer.new();middle.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_child(middle)
	view=SubViewportContainer.new();view.stretch=true;view.size_flags_vertical=Control.SIZE_EXPAND_FILL;view.mouse_filter=Control.MOUSE_FILTER_STOP;middle.add_child(view)
	view.gui_input.connect(view_input)
	viewport=SubViewport.new();viewport.size=Vector2i(850,680);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.mesh_lod_threshold=0;view.add_child(viewport)
	var cursor:=WorkshopCursor.new();cursor.workshop=self;view.add_child(cursor)
	studio=Node3D.new();viewport.add_child(studio)
	BattlefieldPresentation.lighting(studio,AppSettings.new())
	key_light=studio.get_node("KeyLight");environment=studio.get_node("TableEnvironment").environment
	key_light.shadow_enabled=false
	environment.background_color=Color("343a3c");environment.ambient_light_energy=.4
	var floor_mesh:=PlaneMesh.new();floor_mesh.size=Vector2(100,100)
	var floor:=TableVisuals.mesh(studio,floor_mesh,Vector3(0,-.01,0),Color("373e40"));floor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var contact_mesh:=PlaneMesh.new();contact_mesh.size=Vector2(3.2,3.2)
	var contact:=TableVisuals.mesh(studio,contact_mesh,Vector3(0,-.006,0),Color.WHITE)
	var contact_material:=ShaderMaterial.new();contact_material.shader=preload("res://assets/workshop/studio_contact.gdshader");contact.material_override=contact_material;contact.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A quiet work surface and shallow round display plinth keep attention on paint.
	plinth=TableVisuals.cylinder(studio,.86,.05,Vector3(0,.005,0),Color("252e32"))
	sculpt=Node3D.new();sculpt.position.y=.035;studio.add_child(sculpt)
	camera=Camera3D.new();camera.fov=36;camera.near=.01;camera.far=200;studio.add_child(camera)
	var camera_row:=AppUI.row(middle)
	for pair in [["Front",PI],["Side",PI/2],["Rear",0.0]]:AppUI.button(camera_row,pair[0],func():yaw=pair[1];pitch=.14;update_camera())
	AppUI.button(camera_row,"Reset camera",reset_camera)
	var light_choice:=AppUI.choices(camera_row,["Studio","Bright","Atmospheric"])
	light_choice.item_selected.connect(set_lighting)
	var turn:=CheckBox.new();turn.text="Turntable";camera_row.add_child(turn);turn.toggled.connect(func(on: bool):turntable=on)
	AppUI.button(camera_row,"Photo",capture_photo)
	var right:=ScrollContainer.new();right.custom_minimum_size.x=295;right.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(right)
	controls=VBoxContainer.new();controls.custom_minimum_size.x=275;controls.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.add_child(controls)
	message=AppUI.label(main,"",13);message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size.y=37
	var toolbar:=AppUI.row(main)
	undo_button=AppUI.button(toolbar,"Undo  Ctrl+Z",undo);redo_button=AppUI.button(toolbar,"Redo  Ctrl+Y",redo)
	AppUI.button(toolbar,"Save  Ctrl+S",save_figure)
	AppUI.button(toolbar,"Save As New",save_as)
	AppUI.button(toolbar,"Collection",func():category="Collection";refresh_controls())
	AppUI.button(toolbar,"Preview in battle",preview_battle)
	confirm=ConfirmationDialog.new();confirm.confirmed.connect(func():pending.call());add_child(confirm)
	file_dialog=FileDialog.new();file_dialog.access=FileDialog.ACCESS_FILESYSTEM;file_dialog.filters=PackedStringArray(["*.json ; GrimTable paint scheme"])
	file_dialog.file_selected.connect(scheme_file);add_child(file_dialog)
	new_document(initial_source)
	if not FileAccess.file_exists(WorkshopStore.ROOT+"onboarding.json"):show_guide()

func fingerprint() -> String:
	cache_paint_snapshot()
	return JSON.stringify(document).sha256_text()+str(paint_snapshot_hash)

func cache_paint_snapshot() -> void:
	var key:=str(brush.get_instance_id())+":"+str(brush.revision)
	if key==paint_snapshot_key:return
	paint_snapshot_key=key
	paint_snapshot_hash=hash(brush.image.get_data())
	paint_snapshot_png=brush.image.save_png_to_buffer()

func dirty() -> bool:
	return fingerprint()!=saved_fingerprint

func update_state() -> void:
	state_label.text="Unsaved changes" if dirty() else "Saved / original"
	undo_button.disabled=history_index<=0;redo_button.disabled=history_index>=history.size()-1

func checkpoint() -> void:
	cache_paint_snapshot()
	var state:={"data":document.duplicate(true),"paint":paint_snapshot_png}
	if history_index>=0 and history[history_index].data==state.data and history[history_index].paint==state.paint:update_state();return
	history.resize(history_index+1);history.append(state)
	var bytes:=0
	for entry in history:bytes+=entry.paint.size()
	while history.size()>24 or (bytes>32000000 and history.size()>1):bytes-=history[0].paint.size();history.pop_front()
	history_index=history.size()-1;update_state()

func undo() -> void:
	if history_index<=0:return
	history_index-=1;restore_history()

func redo() -> void:
	if history_index>=history.size()-1:return
	history_index+=1;restore_history()

func restore_history() -> void:
	document=history[history_index].data.duplicate(true);brush.restore(history[history_index].paint)
	title.text=document.name;rebuild_model();refresh_controls();update_state()

func guard(action: Callable) -> void:
	finish_stroke()
	if not dirty():action.call();return
	pending=action;confirm.title="Unsaved miniature";confirm.dialog_text="Discard the unsaved changes to this miniature?";confirm.popup_centered()

func new_document(source: String) -> void:
	document=WorkshopStore.fresh(source)
	document.name={"legion_trooper":"Legion Sentinel","legion_walker":"Legion Walker","swarm_hunter":"Swarm Hunter"}.get(source,WorkshopAppearance.imported_record(source).get("name","Imported miniature"))
	load_document(document)

func load_document(data: Dictionary) -> void:
	finish_stroke();document=data.duplicate(true);ui_updating=true;title.text=document.name;ui_updating=false
	brush=WorkshopBrush.new()
	var saved:=WorkshopStore.image(document,"overlay")
	if saved!=null and saved.get_size()==Vector2i(1024,1024):brush.image=saved;brush.upload()
	history.clear();history_index=-1;auto_focus=true;rebuild_model();reset_camera();refresh_controls()
	saved_fingerprint=fingerprint();checkpoint()
	message.text="Ready. Region colors and finishing preserve the baked surface detail."

func rebuild_model() -> void:
	if model!=null:sculpt.remove_child(model);model.free()
	if base_root!=null:sculpt.remove_child(base_root);base_root.free()
	model=WorkshopAppearance.instantiate(document)
	if model==null:
		model=AuthoredArt.miniature(ContentRegistry.unit({"unit_id":"legion_trooper"}))
		message.text="This local model is missing. Showing a built-in preview; saved identity is preserved."
	sculpt.add_child(model);model.position.y+=.2
	WorkshopAppearance.apply_materials(model,document,brush.texture)
	base_root=Node3D.new();sculpt.add_child(base_root)
	var profile:=WorkshopAppearance.profile(document.source)
	var radius:=ContentRegistry.base_radius(profile) if not profile.is_empty() else .63
	WorkshopAppearance.add_base(base_root,document,radius)
	plinth.scale=Vector3((radius+.23)/.86,1,(radius+.23)/.86)
	brush.build(sculpt,WorkshopAppearance.capable(document.source).brush)
	if auto_focus:reset_camera();auto_focus=false

func refresh_materials() -> void:
	WorkshopAppearance.apply_materials(model,document,brush.texture)

func reset_camera() -> void:
	if model!=null:
		var bounds:=MiniatureLibrary.bounds(model);focus=bounds.get_center()+Vector3.UP*.035;distance=maxf(2.6,bounds.size.length()*1.45)
	yaw=PI+.4;pitch=.16;update_camera()

func update_camera() -> void:
	camera.position=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance;camera.look_at(focus)

func set_lighting(index: int) -> void:
	key_light.light_energy=[1.2,1.8,.65][index];environment.ambient_light_energy=[.4,.6,.2][index]

func _process(delta: float) -> void:
	if turntable and not stroke:yaw+=delta*.25;update_camera()

func view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				if mode in ["Brush","Eraser"] and category=="Paint" and WorkshopAppearance.capable(document.source).brush:
					stroke=true;turntable=false;brush.begin();paint_at(event.position)
				elif mode=="Marking" and category=="Paint":place_marking(event.position)
				elif mode=="Region" and category=="Paint":pick_region(event.position)
			else:finish_stroke()
		if event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP:distance=maxf(.35,distance*.9)
			if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance=minf(30,distance*1.1)
			update_camera()
	if event is InputEventMouseMotion:
		if stroke:
			if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):finish_stroke()
			elif Time.get_ticks_msec()-last_paint_tick>30:paint_at(event.position)
		elif event.button_mask&MOUSE_BUTTON_MASK_RIGHT or (event.button_mask&MOUSE_BUTTON_MASK_LEFT and (mode=="Inspect" or category!="Paint")):
			yaw-=event.relative.x*.008;pitch=clampf(pitch+event.relative.y*.008,-.2,1.45);update_camera()
		elif event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
			focus+=(-camera.global_basis.x*event.relative.x+camera.global_basis.y*event.relative.y)*distance*.0015;update_camera()

func paint_at(position: Vector2) -> void:
	last_paint_tick=Time.get_ticks_msec()
	brush.dab(camera,position,paint_color,brush_radius,brush_opacity,mode=="Eraser")
	brush.upload();message.text="%s  |  %.0f px  |  %.0f%% opacity  |  Right-drag to orbit"%[mode,brush_radius,brush_opacity*100]

func finish_stroke() -> void:
	if not stroke:return
	stroke=false
	if brush.end():checkpoint()

func pick_region(position: Vector2) -> void:
	var point:=brush.hit(camera.project_ray_origin(position),camera.project_ray_normal(position))
	if point.is_empty():return
	if not WorkshopAppearance.capable(document.source).regions:
		region="material:"+str(point.material_index);refresh_controls();message.text="Selected imported material "+str(point.material_index+1);return
	region=point.color_region if not str(point.get("color_region","")).is_empty() else WorkshopAppearance.region_at(document.source,point.uv)
	refresh_controls();message.text="Selected "+region.capitalize()+" paint."

func change(key: String, value: Variant) -> void:
	document[key]=value;rebuild_model();checkpoint()

func color_control(parent: Node, label: String, value: Color, callback: Callable) -> ColorPickerButton:
	var row:=AppUI.row(parent);AppUI.label(row,label,13).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var picker:=ColorPickerButton.new();picker.color=value;picker.edit_alpha=false;picker.custom_minimum_size=Vector2(95,30);row.add_child(picker)
	picker.color_changed.connect(callback)
	picker.popup_closed.connect(func():
		checkpoint()
		if category=="Paint":remember_color(false))
	return picker

func refresh_controls() -> void:
	for key in category_buttons:category_buttons[key].modulate=Color("e2c78f") if key==category else Color.WHITE
	for child in controls.get_children():controls.remove_child(child);child.queue_free()
	AppUI.label(controls,category.to_upper(),21).modulate=Color("d8c49a")
	match category:
		"Build":build_controls()
		"Paint":paint_controls()
		"Pose":pose_controls()
		"Base":base_controls()
		"Collection":collection_controls()

func note(text: String) -> void:
	var label:=AppUI.label(controls,text,13);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.modulate=GrimTheme.MUTED

func style_swatch(button: Button, color: Color) -> void:
	var normal:=StyleBoxFlat.new();normal.bg_color=color;normal.set_border_width_all(1);normal.border_color=color.lightened(.3);normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal",normal)
	var hover:=normal.duplicate() as StyleBoxFlat;hover.border_color=Color("eee1bd");hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover",hover);button.add_theme_stylebox_override("pressed",hover)

func build_controls() -> void:
	if WorkshopAppearance.capable(document.source).assembly:
		var parts: Dictionary=ContentRegistry.read_json("res://resources/workshop/legion_parts.json").slots
		for slot in WorkshopStore.PARTS:
			AppUI.label(controls,slot.capitalize(),14)
			var choice:=AppUI.choices(controls,parts[slot],int(document.parts[slot]))
			choice.item_selected.connect(func(i: int):document.parts[slot]=i;rebuild_model();checkpoint();message.text=slot.capitalize()+" fitted. Cosmetic appearance only.")
		var profile:=WorkshopAppearance.profile(document.source)
		var weapons:=ContentRegistry.weapons(profile)
		note("Battle equipment: "+", ".join(weapons.map(func(w: Dictionary):return str(w.get("name","Weapon"))))+". Cosmetic weapon appearances never change these rules.")
	else:note("This model has no compatible assembly sockets. Its original mesh is preserved.")
	AppUI.label(controls,"Display placement",16)
	for entry in [["Scale","scale",.01,100,.01],["Facing","rotation",-180,180,1],["Ground offset","offset",-10,10,.01]]:
		var spin:=AppUI.spin(controls,entry[0],float(document[entry[1]]),entry[2],entry[3],entry[4])
		spin.value_changed.connect(func(v: float):change(entry[1],v))

func paint_controls() -> void:
	var capabilities:=WorkshopAppearance.capable(document.source)
	var modes: Array=["Inspect","Region"]
	if capabilities.brush:modes.append_array(["Brush","Eraser","Marking"])
	if mode not in modes:mode="Region"
	var tools:=AppUI.choices(controls,modes,modes.find(mode));tools.item_selected.connect(func(i: int):finish_stroke();mode=modes[i];refresh_controls())
	if not capabilities.brush:note("Freehand and surface markings require prepared unique UVs. This model supports "+("region colors and finishing." if capabilities.regions else "original-material tints and base editing."))
	if capabilities.regions:
		var regions: Array=["body"] if document.source=="swarm_hunter" else ["primary","secondary","trim","cloth","weapon","metal","glow"]
		if document.source=="legion_walker":regions.erase("cloth")
		if region not in regions:region=regions[0]
		var selector:=AppUI.choices(controls,regions,regions.find(region));selector.item_selected.connect(func(i: int):region=regions[i];refresh_controls())
		color_control(controls,region.capitalize(),Color(document.colors[region]),func(c: Color):document.colors[region]=c.to_html(false);refresh_materials();update_state())
		var hex:=AppUI.text(controls,"Hex color",str(document.colors[region]))
		hex.max_length=7;hex.text_submitted.connect(func(value: String):
			value=value.trim_prefix("#")
			if WorkshopStore.color_valid(value):document.colors[region]=value;refresh_materials();checkpoint();refresh_controls()
			else:message.text="Use a six-digit hexadecimal color.")
		var row:=AppUI.row(controls)
		AppUI.button(row,"Copy",func():DisplayServer.clipboard_set("#"+str(document.colors[region])))
		AppUI.button(row,"Paste",func():
			var value:=DisplayServer.clipboard_get().trim_prefix("#").strip_edges()
			if WorkshopStore.color_valid(value):document.colors[region]=value;refresh_materials();checkpoint();refresh_controls())
		AppUI.button(row,"Reset",func():document.colors[region]=WorkshopStore.COLORS[region];refresh_materials();checkpoint();refresh_controls())
	else:
		var material_count:=0
		for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):material_count+=mesh.mesh.get_surface_count()
		var labels: Array=[]
		for i in mini(material_count,64):labels.append("Material "+str(i+1))
		if not labels.is_empty():
			var selected:=clampi(int(region.trim_prefix("material:")),0,labels.size()-1)
			var selector:=AppUI.choices(controls,labels,selected);selector.item_selected.connect(func(i: int):region="material:"+str(i);refresh_controls())
			color_control(controls,"Material tint",Color(document.materials.get(str(selected),"ffffff")),func(c: Color):document.materials[str(selected)]=c.to_html(false);refresh_materials();update_state())
	if mode in ["Brush","Eraser","Marking"]:
		color_control(controls,"Brush / marking",paint_color,func(c: Color):paint_color=c)
		if mode=="Marking":marking_controls()
		else:
			var radius:=AppUI.spin(controls,"Radius (screen px)",brush_radius,2,32,1);radius.value_changed.connect(func(v: float):brush_radius=v)
			var opacity:=AppUI.spin(controls,"Opacity",brush_opacity,.05,1,.05);opacity.value_changed.connect(func(v: float):brush_opacity=v)
			note("Left-drag paints the visible surface. Right-drag orbits; middle-drag pans. Each stroke is one undo step.")
	AppUI.label(controls,"Paint rack",16)
	var swatches:=GridContainer.new();swatches.columns=4;controls.add_child(swatches)
	var paints: Dictionary={"Void Slate":"343b44","Forge Blue":"315f86","Oxide Red":"8c4035","Ash Ivory":"c5bda5","Moss Field":"536c57","Old Brass":"a08d5f","Signal Ice":"62d0d3","Bone Dust":"dfcfac"}
	for name in paints:
		var color:=Color(paints[name]);var button:=AppUI.button(swatches,"   ",func():use_swatch(color))
		button.tooltip_text=name;style_swatch(button,color);button.custom_minimum_size=Vector2(53,30)
	var saved_colors: Array=WorkshopStore.read_json(WorkshopStore.ROOT+"colors.json").get("saved",[])
	var recent: Array=WorkshopStore.read_json(WorkshopStore.ROOT+"colors.json").get("recent",[])
	for pair in [["Saved",saved_colors],["Recent",recent]]:
		if pair[1].is_empty():continue
		AppUI.label(controls,pair[0],12)
		var rack:=AppUI.row(controls)
		for value in pair[1].slice(0,6):
			if not WorkshopStore.color_valid(value):continue
			var button:=AppUI.button(rack," ",func():use_swatch(Color(value)));style_swatch(button,Color(value));button.custom_minimum_size=Vector2(30,24)
	AppUI.button(controls,"Save current color",func():remember_color(true);refresh_controls())
	AppUI.label(controls,"Finish",16)
	for key in WorkshopStore.EFFECTS:
		if not capabilities.regions and key not in ["metallic","roughness"]:continue
		if key in ["glow","metallic"] and document.source=="swarm_hunter":continue
		var spin:=AppUI.spin(controls,key.capitalize(),float(document.effects[key]),-.35 if key in ["metallic","roughness"] else 0,.35 if key in ["metallic","roughness"] else 1,.05)
		spin.value_changed.connect(func(value: float):document.effects[key]=value;refresh_materials();checkpoint())
	AppUI.label(controls,"Shared schemes",16)
	var schemes: Array=WorkshopStore.PRESETS.keys();var saved:=WorkshopStore.saved_schemes()
	for scheme in saved:schemes.append(scheme.name)
	var choice:=AppUI.choices(controls,schemes)
	AppUI.button(controls,"Apply scheme",func():
		var i:=choice.selected
		if i<WorkshopStore.PRESETS.size():
			var values: Array=WorkshopStore.PRESETS[schemes[i]]
			for j in 3:document.colors[["primary","secondary","trim"][j]]=values[j]
		else:document.colors.merge(saved[i-WorkshopStore.PRESETS.size()].colors,true);document.effects.merge(saved[i-WorkshopStore.PRESETS.size()].effects,true)
		refresh_materials();checkpoint();refresh_controls())
	AppUI.button(controls,"Save scheme from miniature",func():WorkshopStore.save_scheme(WorkshopStore.scheme(document,document.name));refresh_controls();message.text="Paint scheme saved independently of parts and brush artwork.")
	var files:=AppUI.row(controls)
	AppUI.button(files,"Import JSON",func():file_action="import";file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;file_dialog.popup_centered_ratio(.7))
	AppUI.button(files,"Export JSON",func():file_action="export";file_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE;file_dialog.current_file="paint_scheme.json";file_dialog.popup_centered_ratio(.7))

func use_swatch(color: Color) -> void:
	paint_color=color
	if mode not in ["Brush","Eraser","Marking"] and document.colors.has(region):document.colors[region]=color.to_html(false);refresh_materials();checkpoint()
	remember_color(false);refresh_controls()

func remember_color(saved: bool) -> void:
	var data:=WorkshopStore.read_json(WorkshopStore.ROOT+"colors.json")
	var key:="saved" if saved else "recent"
	var colors: Array=data.get(key,[]);var color:=paint_color.to_html(false) if mode in ["Brush","Eraser","Marking"] else str(document.colors.get(region,paint_color.to_html(false)))
	colors.erase(color);colors.push_front(color);data[key]=colors.slice(0,12)
	WorkshopStore.atomic_json(WorkshopStore.ROOT+"colors.json",data)

func marking_controls() -> void:
	var kinds: Array=["Stripe","Diamond","Hazard","Number","Text"]
	var choice:=AppUI.choices(controls,kinds,kinds.find(marking_kind));choice.item_selected.connect(func(i: int):marking_kind=kinds[i])
	var text:=AppUI.text(controls,"Marking text / number",marking_text);text.max_length=12;text.text_changed.connect(func(value: String):marking_text=value)
	var size:=AppUI.spin(controls,"Scale",marking_size,.005,.08,.005);size.value_changed.connect(func(value: float):marking_size=value;edit_marking())
	var angle:=AppUI.spin(controls,"Rotation",marking_angle,-180,180,5);angle.value_changed.connect(func(value: float):marking_angle=value;edit_marking())
	note("Click a prepared surface to place a marking. Select a saved marking to adjust its scale or rotation.")
	var labels: Array=["New marking"]
	for i in document.decals.size():labels.append(str(i+1)+" / "+str(document.decals[i].kind))
	var selected:=AppUI.choices(controls,labels,clampi(selected_marking+1,0,labels.size()-1))
	selected.item_selected.connect(func(i: int):selected_marking=i-1)
	AppUI.button(controls,"Remove selected marking",func():
		if selected_marking>=0 and selected_marking<document.decals.size():document.decals.remove_at(selected_marking);selected_marking=-1;refresh_materials();checkpoint();refresh_controls())

func place_marking(position: Vector2) -> void:
	if not WorkshopAppearance.capable(document.source).brush:return
	var point:=brush.hit(camera.project_ray_origin(position),camera.project_ray_normal(position))
	if point.is_empty() or not point.paintable:message.text="Choose a prepared model surface.";return
	if document.decals.size()>=16:message.text="This miniature already has sixteen markings.";return
	var island:=WorkshopAppearance.island_at(point.uv)
	if island==0:message.text="Choose a point farther inside this surface.";return
	document.decals.append({"kind":marking_kind,"u":point.uv.x,"v":point.uv.y,"size":marking_size,"angle":marking_angle,"color":paint_color.to_html(false),"text":marking_text,"island":island})
	selected_marking=document.decals.size()-1;refresh_materials();checkpoint();refresh_controls()

func edit_marking() -> void:
	if selected_marking<0 or selected_marking>=document.decals.size():return
	document.decals[selected_marking].size=marking_size;document.decals[selected_marking].angle=marking_angle
	refresh_materials();checkpoint()

func pose_controls() -> void:
	if not WorkshopAppearance.capable(document.source).pose:note("This static model has no authored pose controls. Original imported animation clips remain available in the Miniature Library.");return
	var names: Array=["Neutral","Ready","Aiming","Advancing","Heroic Display"]
	var choice:=AppUI.choices(controls,names,names.find(document.pose));choice.item_selected.connect(func(i: int):change("pose",names[i]))
	for pair in [["Head turn","head_yaw",-25,25],["Torso turn","torso_yaw",-8,8]]:
		var spin:=AppUI.spin(controls,pair[0],float(document[pair[1]]),pair[2],pair[3],1);spin.value_changed.connect(func(value: float):change(pair[1],value))
	note("Authored rigid-part posing: head orientation and a small complete upper-body turn. Arms stay attached to the weapon. Battle movement and reactions retain control of the outer model transform.")

func base_controls() -> void:
	var styles: Array=["Rubble","Industrial","Stone","Ash"]
	var choice:=AppUI.choices(controls,styles,styles.find(document.base_style));choice.item_selected.connect(func(i: int):change("base_style",styles[i]))
	color_control(controls,"Rim",Color(document.rim),func(color: Color):document.rim=color.to_html(false);rebuild_model();update_state())
	color_control(controls,"Ground accent",Color(document.ground),func(color: Color):document.ground=color.to_html(false);rebuild_model();update_state())
	var text:=AppUI.text(controls,"Base nameplate",document.nameplate);text.max_length=24;text.text_submitted.connect(func(value: String):change("nameplate",value))
	if WorkshopAppearance.capable(document.source).assembly:
		var choices: Array=["None","Masonry","Conduit","Fractured tile"]
		var decoration:=AppUI.choices(controls,choices,int(document.parts.decoration));decoration.item_selected.connect(func(i: int):document.parts.decoration=i;rebuild_model();checkpoint())
	var profile:=WorkshopAppearance.profile(document.source)
	note("Base diameter: %.0f mm, defined by the unit profile. Scenic choices change appearance only; movement, collision and LOS remain canonical."%(ContentRegistry.base_radius(profile)*50.8 if not profile.is_empty() else 32))

func collection_controls() -> void:
	var search:=AppUI.text(controls,"Find miniature",filter_text);search.text_changed.connect(func(value: String):filter_text=value;populate_collection())
	var filters: Array=["All","Customized","Defaults"]
	var kind:=AppUI.choices(controls,filters,filters.find(filter_kind));kind.item_selected.connect(func(i: int):filter_kind=filters[i];populate_collection())
	for group in [["faction",["All factions","legion","swarm"],filter_faction],["family",["All families","legion_trooper","legion_walker","swarm_hunter","Imported"],filter_family]]:
		var options: Array=group[1];var field: String=group[0]
		var choice:=AppUI.choices(controls,options,maxi(0,options.find(group[2])))
		choice.item_selected.connect(func(i: int):
			if field=="faction":filter_faction=options[i]
			else:filter_family=options[i]
			populate_collection())
	var profiles: Array=["All profiles"];profiles.append_array(ContentRegistry.catalog().units.keys())
	var profile_choice:=AppUI.choices(controls,profiles,maxi(0,profiles.find(filter_profile)));profile_choice.item_selected.connect(func(i: int):filter_profile=profiles[i];populate_collection())
	var sorts: Array=["Name","Family"];var sort_choice:=AppUI.choices(controls,sorts,sorts.find(sort_kind));sort_choice.item_selected.connect(func(i: int):sort_kind=sorts[i];populate_collection())
	collection_list=ItemList.new();collection_list.custom_minimum_size.y=230;collection_list.fixed_icon_size=Vector2i(64,64);controls.add_child(collection_list)
	collection_list.item_selected.connect(func(i: int):guard(func():load_document(items[i])))
	populate_collection()
	var row:=AppUI.row(controls)
	AppUI.button(row,"Duplicate",save_as)
	AppUI.button(row,"Rename",func():title.grab_focus();title.select_all())
	AppUI.button(row,"Delete",delete_figure)
	AppUI.button(controls,"Revert to original",func():guard(revert_original))
	AppUI.label(controls,"Use this miniature",16)
	if MiniatureLibrary.safe_id(document.source):
		var record:=WorkshopAppearance.imported_record(document.source)
		var compatible_profiles: Array=ContentRegistry.catalog().units.keys()
		AppUI.label(controls,"Imported model's compatible profile",12)
		var imported_choice:=AppUI.choices(controls,compatible_profiles,maxi(0,compatible_profiles.find(record.get("profile",""))))
		imported_choice.item_selected.connect(func(i: int):record.profile=compatible_profiles[i];MiniatureLibrary.save_record(record);message.text="Imported visual assigned to "+compatible_profiles[i]+"; that profile supplies all gameplay rules.")
	AppUI.button(controls,"Assign to compatible profile",func():assign_figure("profile"))
	AppUI.button(controls,"Assign to compatible faction",func():assign_figure("faction"))
	AppUI.label(controls,"Local squad / model ID",12)
	var target:=AppUI.text(controls,"From a saved scenario or battle","")
	var scenario_items:=ScenarioLibrary.list_scenarios()
	var target_options: Array=["Choose a scenario unit / model"]
	var target_values: Array=[""]
	for entry in scenario_items:
		if not entry.has("data"):continue
		for army: Dictionary in entry.data.get("armies",[]):
			if ContentRegistry.unit(army).get("id","")!=WorkshopAppearance.profile(document.source).get("id",""):continue
			target_options.append(str(entry.data.name)+" / "+str(army.name));target_values.append(str(army.id))
			for mini: Dictionary in army.get("models",[]):target_options.append("  "+str(army.name)+" / "+str(mini.get("label",mini.id)));target_values.append(str(mini.get("cosmetic_id",mini.id)))
	var target_choice:=AppUI.choices(controls,target_options);target_choice.clip_text=true;target_choice.item_selected.connect(func(i: int):target.text=target_values[i])
	var assignment:=AppUI.row(controls)
	AppUI.button(assignment,"Assign squad",func():assign_figure("squad",target.text))
	AppUI.button(assignment,"Assign model",func():assign_figure("model",target.text))
	AppUI.button(controls,"Apply paint scheme to assigned squad",func():apply_scheme_scope("squad",target.text))
	AppUI.button(controls,"Apply paint scheme to faction",func():apply_scheme_scope("faction",""))
	note("Assignments are local cosmetics. Missing files fall back safely. Scheme application keeps each saved figure's brushwork and parts. Profile assignment takes effect on the next battlefield load.")

func populate_collection() -> void:
	if collection_list==null:return
	items.clear();collection_list.clear()
	var candidates:=WorkshopStore.records()
	if filter_kind!="Customized":
		for source in AuthoredArt.MODELS:
			var value:=WorkshopStore.fresh(source);value.name=WorkshopAppearance.profile(source).get("name",source)+" / Default";candidates.append(value)
	if sort_kind=="Family":candidates.sort_custom(func(a: Dictionary,b: Dictionary):return str(a.source)+str(a.name)<str(b.source)+str(b.name))
	for item in candidates:
		var profile:=WorkshopAppearance.profile(item.source)
		if filter_kind=="Defaults" and not str(item.id).is_empty():continue
		if not filter_text.is_empty() and not str(item.name).to_lower().contains(filter_text.to_lower()):continue
		if filter_faction!="All factions" and profile.get("faction","")!=filter_faction:continue
		if filter_profile!="All profiles" and profile.get("id","")!=filter_profile:continue
		if filter_family!="All families" and (item.source!=filter_family if filter_family!="Imported" else not MiniatureLibrary.safe_id(item.source)):continue
		items.append(item);collection_list.add_item(item.name)
		# Only the first visible batch decodes thumbnails; scrolling loads later items.
	if not collection_list.get_v_scroll_bar().value_changed.is_connected(load_visible_thumbnails):collection_list.get_v_scroll_bar().value_changed.connect(load_visible_thumbnails)
	load_visible_thumbnails()

func load_visible_thumbnails(_value: float=0) -> void:
	if collection_list==null:return
	var first:=maxi(0,int(collection_list.get_v_scroll_bar().value/68)-2)
	for i in range(first,mini(items.size(),first+16)):
		var item:=items[i];var path: String=item.thumbnail
		if path.is_empty():continue
		if thumb_cache.size()>64:thumb_cache.clear()
		if not thumb_cache.has(path):
			var img:=WorkshopStore.image(item,"thumbnail")
			if img!=null:thumb_cache[path]=ImageTexture.create_from_image(img)
		if thumb_cache.has(path):collection_list.set_item_icon(i,thumb_cache[path])

func save_figure() -> bool:
	finish_stroke();document.name=title.text.strip_edges().left(100)
	if document.name.is_empty():document.name="Untitled miniature"
	var thumb:=viewport.get_texture().get_image()
	if thumb!=null:thumb.resize(192,192,Image.INTERPOLATE_LANCZOS)
	var result:=WorkshopStore.save(document,brush.image if WorkshopAppearance.capable(document.source).brush else null,thumb)
	if result.has("error"):message.text=result.error;return false
	document=result;saved_fingerprint=fingerprint();checkpoint();message.text="Saved to your local collection. Original model files are unchanged."
	if category=="Collection":refresh_controls()
	return true

func save_as() -> void:
	finish_stroke();document.id="";document.overlay="";document.thumbnail="";document.name=title.text+" / Copy";title.text=document.name;save_figure()

func revert_original() -> void:
	var original:=WorkshopStore.fresh(document.source);original.id=document.id;original.name=document.name
	document=original;brush=WorkshopBrush.new();rebuild_model();checkpoint();refresh_controls()
	message.text="Original appearance restored in the editor. Save to replace this variant, or undo to recover your customization."

func delete_figure() -> void:
	if str(document.id).is_empty():message.text="This miniature has not been saved yet.";return
	pending=func():
		if WorkshopStore.delete(document.id):new_document(document.source);category="Collection";refresh_controls();message.text="Miniature deleted. Missing cosmetic assignments use the built-in fallback."
	confirm.title="Delete miniature";confirm.dialog_text="Delete this saved miniature and its managed paint textures? Original models are kept.";confirm.popup_centered()

func assign_figure(scope: String, target: String="") -> void:
	if not save_figure():return
	var profile:=WorkshopAppearance.profile(document.source)
	if scope in ["profile","faction"]:target=str(profile.get("id" if scope=="profile" else "faction",""))
	if WorkshopStore.assign(scope,target,document.id):message.text="Assigned locally to "+scope+" "+target+". Gameplay equipment is unchanged."
	else:message.text="Enter a valid model or squad ID before assigning."

func apply_scheme_scope(scope: String, target: String) -> void:
	var profile:=WorkshopAppearance.profile(document.source)
	var affected:=0
	var handled_sources: Dictionary={}
	for entry in WorkshopStore.records():
		var other:=WorkshopAppearance.profile(entry.source)
		var matches: bool=other.get("faction","")==profile.get("faction","") if scope=="faction" else WorkshopStore.assignments().get("squad:"+target,"")==entry.id and not target.is_empty()
		if not matches or not WorkshopAppearance.capable(entry.source).regions:continue
		entry.colors.merge(document.colors,true);entry.effects.merge(document.effects,true)
		if not WorkshopStore.save(entry).has("error"):affected+=1;handled_sources[entry.source]=true
	# A scheme can also reach compatible units which have no saved figure yet.
	# Existing individual/model assignments keep their own assembly and overlay.
	for source in AuthoredArt.MODELS:
		if scope=="squad" and handled_sources.has(source):continue
		if scope=="faction":
			var assigned_id: String=str(WorkshopStore.assignments().get("profile:"+source,""))
			if WorkshopStore.valid_id(assigned_id):
				var assigned_data:=WorkshopStore.read_json(WorkshopStore.ROOT+"figures/"+assigned_id+".json")
				if WorkshopStore.validate(assigned_data).is_empty() and assigned_data.source==source:continue
		var compatible: bool=WorkshopAppearance.profile(source).get("faction","")==profile.get("faction","") if scope=="faction" else source==document.source and not target.is_empty()
		if not compatible:continue
		var entry:=WorkshopStore.fresh(source);entry.name=document.name+" / "+source
		entry.colors.merge(document.colors,true);entry.effects.merge(document.effects,true)
		var saved:=WorkshopStore.save(entry)
		if not saved.has("error") and WorkshopStore.assign("profile" if scope=="faction" else "squad",source if scope=="faction" else target,saved.id):affected+=1
	message.text="Scheme applied to %d saved compatible miniature(s); unique overlays and parts preserved."%affected

func scheme_file(path: String) -> void:
	if file_action=="export":
		message.text="Scheme exported." if WorkshopStore.atomic_json(path,WorkshopStore.scheme(document,document.name)) else "Scheme export failed."
	else:
		var result:=WorkshopStore.import_scheme(path)
		if result.has("error"):message.text=result.error;return
		document.colors.merge(result.colors,true);document.effects.merge(result.effects,true);WorkshopStore.save_scheme(result);refresh_materials();checkpoint();refresh_controls();message.text="Imported paint scheme; model files were not included."

func preview_battle() -> void:
	if not save_figure():return
	var profile:=WorkshopAppearance.profile(document.source)
	if not WorkshopStore.assign("profile",str(profile.get("id","")),document.id):return
	queue_free();app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/iron_reliquary.json"))

func capture_photo() -> void:
	await RenderingServer.frame_post_draw
	var path:="user://workshop_photo_"+str(Time.get_unix_time_from_system()).replace(".","_")+".png"
	viewport.get_texture().get_image().save_png(path);message.text="Clean studio photo saved: "+ProjectSettings.globalize_path(path)

func show_guide() -> void:
	var dialog:=AcceptDialog.new();dialog.title="Your first painted miniature"
	dialog.dialog_text="1. Choose Legion infantry.\n2. Paint: click armor or choose Primary, then select a paint.\n3. Adjust Wash and Highlight to bring out the sculpt.\n4. Choose Brush; left-drag paints, right-drag orbits.\n5. Build: fit a helmet and backpack.\n6. Base: choose a ground finish and rim color.\n7. Save, then Preview in battle.\n\nCtrl+Z / Ctrl+Y undo and redo. Ctrl+S saves.\nYour original models and gameplay equipment stay intact."
	add_child(dialog);dialog.confirmed.connect(func():WorkshopStore.atomic_json(WorkshopStore.ROOT+"onboarding.json",{"seen":true});dialog.queue_free())
	dialog.popup_centered()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:finish_stroke()
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.ctrl_pressed and event.keycode in [KEY_Z,KEY_Y,KEY_S]:
		match event.keycode:
			KEY_Z:redo() if event.shift_pressed else undo()
			KEY_Y:redo()
			KEY_S:save_figure()
		get_viewport().set_input_as_handled()
	elif event.keycode==KEY_ESCAPE:guard(func():queue_free();app.show_main());get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	# Mounted battlefield figures keep their own material/texture references.
	# Editing previews and histories do not stay resident after leaving the bench.
	WorkshopAppearance.material_cache.clear();WorkshopStore.texture_cache.clear()
	history.clear();thumb_cache.clear()
