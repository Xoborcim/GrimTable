class_name MiniatureLibraryPanel
extends Control

var app: Node
var items: Array[Dictionary] = []
var record: Dictionary = {}
var list: ItemList
var controls: VBoxContainer
var message: Label
var viewport: SubViewport
var studio: Node3D
var pivot: Node3D
var camera: Camera3D
var model: Node3D
var base: MeshInstance3D
var marker: MeshInstance3D
var yaw := .5
var pitch := .2
var distance := 7.0
var file_dialog: FileDialog
var blender_dialog: FileDialog
var importing := false
var conversion_thread: Thread
var dirty := false
var confirm: ConfirmationDialog
var pending_action: Callable

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = AppUI.theme()
	var background := ColorRect.new()
	background.color = Color("101922")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24; row.offset_top = 20; row.offset_right = -24; row.offset_bottom = -20
	add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 230
	row.add_child(left)
	AppUI.label(left,"MINIATURE LIBRARY",22)
	AppUI.label(left,"My Miniatures",16)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(list)
	list.item_selected.connect(func(index: int): guard(func(): edit(items[index])))
	AppUI.button(left,"Import Model",func(): guard(func(): file_dialog.popup_centered_ratio(.75)))
	AppUI.button(left,"Configure Blender…",func(): blender_dialog.popup_centered_ratio(.7))
	AppUI.button(left,"Delete Miniature",delete_selected)
	AppUI.button(left,"Open in Workshop",func():
		if not record.is_empty():guard(func():queue_free();app.show_workshop(str(record.id))))
	AppUI.button(left,"Back",func(): guard(func(): queue_free(); app.show_main()))
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(middle)
	var container := SubViewportContainer.new()
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(preview_input)
	middle.add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(650,650)
	viewport.own_world_3d = true
	container.add_child(viewport)
	studio = Node3D.new()
	viewport.add_child(studio)
	var settings := AppSettings.new()
	BattlefieldPresentation.lighting(studio,settings)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size=Vector2(20,20)
	TableVisuals.mesh(studio,floor_mesh,Vector3(0,-.01,0),Color("40464b"))
	base = TableVisuals.cylinder(studio,.63,.16,Vector3(0,.08,0),Color("25282c"))
	marker = TableVisuals.cylinder(studio,.04,.2,Vector3(0,1.35,0),Color("e3b866"))
	pivot = Node3D.new()
	studio.add_child(pivot)
	camera = Camera3D.new()
	studio.add_child(camera)
	update_camera()
	var views := AppUI.row(middle)
	for pair in [["Reset",.5,.2],["Front",0,0],["Side",PI/2,0],["Top",0,1.5]]:
		AppUI.button(views,pair[0],func(): yaw=pair[1]; pitch=pair[2]; distance=7; update_camera())
	message = AppUI.label(middle,"Import your own legally usable GLB / glTF; OBJ and FBX require Blender.",14)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	AppUI.label(middle,"Drag to orbit · Wheel to zoom · Alt-drag moves the cosmetic LOS marker",13)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 310
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	controls = VBoxContainer.new()
	controls.custom_minimum_size.x = 285
	scroll.add_child(controls)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.glb, *.gltf, *.obj, *.fbx ; 3D models"])
	file_dialog.file_selected.connect(import_file)
	add_child(file_dialog)
	blender_dialog = FileDialog.new()
	blender_dialog.access = FileDialog.ACCESS_FILESYSTEM
	blender_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	blender_dialog.filters = PackedStringArray(["*.exe ; Blender executable"])
	blender_dialog.file_selected.connect(func(path: String): BlenderConversion.configure(path); message.text="Blender configured. Import your OBJ/FBX again.")
	add_child(blender_dialog)
	confirm = ConfirmationDialog.new()
	confirm.confirmed.connect(func(): dirty=false; pending_action.call())
	add_child(confirm)
	refresh_list()
	if not items.is_empty(): edit(items[0])

func guard(action: Callable) -> void:
	if importing: message.text="Wait for the current conversion to finish."; return
	if not dirty: action.call(); return
	pending_action = action
	confirm.dialog_text = "Discard unsaved miniature adjustments?"
	confirm.popup_centered()

func refresh_list() -> void:
	items = MiniatureLibrary.records()
	list.clear()
	for item in items: list.add_item(str(item.name))

func import_file(path: String) -> void:
	if importing: return
	if path.get_extension().to_lower() in ["obj","fbx"]:
		var blender := BlenderConversion.detect()
		if blender.is_empty(): message.text="This FBX/OBJ needs conversion. Configure Blender, or export glTF Binary (.glb) manually."; return
		importing = true
		message.text="Converting with Blender…"
		conversion_thread = Thread.new()
		conversion_thread.start(func(): return BlenderConversion.convert(path,blender))
		return
	finish_import(MiniatureLibrary.import_model(path))

func _process(_delta: float) -> void:
	if importing and conversion_thread != null and not conversion_thread.is_alive():
		var result: Dictionary = conversion_thread.wait_to_finish()
		importing = false
		if result.has("error"): message.text=result.error
		else: finish_import(MiniatureLibrary.import_model(result.path))

func finish_import(result: Dictionary) -> void:
	if result.has("error"): message.text=result.error; return
	refresh_list()
	edit(result.record)
	message.text="Imported locally. Adjust placement and Assign to Unit, then Save Miniature."

func edit(value: Dictionary) -> void:
	record = value.duplicate(true)
	dirty = false
	for child in controls.get_children(): controls.remove_child(child); child.queue_free()
	AppUI.label(controls,"EDIT MINIATURE",20)
	var title := AppUI.text(controls,"Display name",str(record.name))
	title.text_changed.connect(func(text: String): record.name=text.left(100); dirty=true)
	add_spin("Uniform scale","scale",.00001,10000,.001)
	for axis in 3:
		var spin := AppUI.spin(controls,["X rotation","Y / facing","Z rotation"][axis],float(record.rotation[axis]),-360,360,1)
		spin.value_changed.connect(func(v: float): record.rotation[axis]=v; dirty=true; update_model())
	add_spin("Ground offset","offset",-100,100,.01)
	AppUI.label(controls,"Cosmetic base (gameplay profile unchanged)",12)
	var bases := AppUI.choices(controls,MiniatureLibrary.BASES,MiniatureLibrary.BASES.find(int(record.base_mm)))
	bases.item_selected.connect(func(i: int): record.base_mm=MiniatureLibrary.BASES[i]; dirty=true; update_model())
	add_spin("Cosmetic LOS marker","los_marker",0,20,.05)
	var styles := AppUI.choices(controls,["Industrial","Rubble","Stone","Scorched"],["Industrial","Rubble","Stone","Scorched"].find(str(record.get("base_style","Industrial"))))
	styles.item_selected.connect(func(i: int): record.base_style=["Industrial","Rubble","Stone","Scorched"][i]; dirty=true; update_model())
	var row := AppUI.row(controls)
	AppUI.button(row,"Auto Fit",func():
		if model == null: return
		var box := MiniatureLibrary.bounds(model)
		if box.size.y > .00001:
			record.scale=float(record.scale)*1.8/box.size.y
			record.offset=float(record.offset)-box.position.y*1.8/box.size.y
			dirty=true; edit_keep_dirty())
	AppUI.button(row,"Auto Orient",func(): record.rotation=[0,0,0]; dirty=true; edit_keep_dirty())
	AppUI.button(row,"Reset",func(): record.scale=1.0; record.rotation=[0,0,0]; record.offset=0.0; dirty=true; edit_keep_dirty())
	AppUI.label(controls,"Assign to Unit (cosmetic variants)",15)
	var profiles: Array = [""]
	profiles.append_array(ContentRegistry.catalog().units.keys())
	var assignment := AppUI.choices(controls,profiles,maxi(0,profiles.find(str(record.profile))))
	assignment.item_selected.connect(func(i: int): record.profile=profiles[i]; dirty=true)
	var override := CheckBox.new()
	override.text="Override materials"
	override.button_pressed=record.get("override",false)
	controls.add_child(override)
	override.toggled.connect(func(v: bool): record.override=v; dirty=true; update_model())
	for key in ["primary","secondary"]:
		var picker := ColorPickerButton.new()
		picker.text=key.capitalize(); picker.color=Color(str(record.get(key,"#aaaaaa")))
		controls.add_child(picker)
		picker.color_changed.connect(func(color: Color): record[key]="#"+color.to_html(false); dirty=true; update_model())
	for key in ["metallic","roughness","emission"]: add_spin(key.capitalize(),key,0,1,.05)
	for key in ["creator","source","license","notes"]:
		var field := AppUI.text(controls,key.capitalize(),str(record.get(key,"")))
		field.text_changed.connect(func(text: String): record[key]=text.left(1000); dirty=true)
	AppUI.label(controls,"Local import grants no redistribution rights. Private models are never included in mod exports.",12).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	AppUI.button(controls,"Save Miniature",func():
		if MiniatureLibrary.save_record(record): dirty=false; refresh_list(); message.text="Saved. Assignment applies when a battlefield is loaded. Canonical base and LOS are preserved.")
	update_model()
	var clips: Array[String] = []
	for player: AnimationPlayer in model.find_children("*","AnimationPlayer",true,false) if model != null else []:
		for clip in player.get_animation_list():
			if clip != "RESET": clips.append(clip)
		if not clips.is_empty():
			var choice := AppUI.choices(controls,clips)
			AppUI.button(controls,"Preview animation",func():
				for active: AnimationPlayer in model.find_children("*","AnimationPlayer",true,false):
					if active.has_animation(clips[choice.selected]): active.play(clips[choice.selected]))
			if not record.has("animation_map"): record.animation_map={}
			for state in ["idle","move","attack","hit","defeat"]:
				AppUI.label(controls,"Animation: "+state,12)
				var options: Array=[""]
				options.append_array(clips)
				var mapping:=AppUI.choices(controls,options,maxi(0,options.find(record.animation_map.get(state,""))))
				mapping.item_selected.connect(func(i: int): record.animation_map[state]=options[i]; dirty=true)
			break

func edit_keep_dirty() -> void:
	edit(record); dirty=true

func add_spin(label: String, key: String, low: float, high: float, step: float) -> void:
	var spin := AppUI.spin(controls,label,float(record.get(key,0)),low,high,step)
	spin.value_changed.connect(func(v: float): record[key]=v; dirty=true; update_model())

func update_model() -> void:
	if is_instance_valid(model): pivot.remove_child(model); model.queue_free()
	model = MiniatureLibrary.instantiate_record(record)
	if model != null: pivot.add_child(model)
	var radius := float(record.get("base_mm",32))/25.4/2
	base.scale = Vector3(radius/.63,1,radius/.63)
	base.material_override = TableVisuals.material({"Industrial":Color("303b42"),"Rubble":Color("5b5346"),"Stone":Color("6b6860"),"Scorched":Color("292923")}.get(record.get("base_style","Industrial"),Color.GRAY))
	marker.position.y=float(record.get("los_marker",1.35))
	if model != null: message.text="Visual height: %.1f mm · Cosmetic base: %d mm · Gameplay footprint comes from the assigned profile." % [MiniatureLibrary.bounds(model).size.y*25.4,int(record.base_mm)]

func preview_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if Input.is_key_pressed(KEY_ALT) and not record.is_empty(): record.los_marker=clampf(float(record.los_marker)-event.relative.y*.01,0,20); dirty=true; marker.position.y=record.los_marker
		else: yaw-=event.relative.x*.01; pitch=clampf(pitch+event.relative.y*.01,-.4,1.5); update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance=maxf(1,distance*.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance=minf(100,distance*1.1)
		update_camera()

func update_camera() -> void:
	camera.position=Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance+Vector3.UP
	camera.look_at(Vector3.UP)

func delete_selected() -> void:
	if record.is_empty() or importing: return
	pending_action=func():
		# Delete only this validated managed record's files; keep unrelated data.
		if not MiniatureLibrary.safe_id(str(record.id)): return
		var folder: String=MiniatureLibrary.ROOT+str(record.id)+"/"
		DirAccess.remove_absolute(folder+"miniature.json")
		MiniatureLibrary.records_loaded=false
		MiniatureLibrary.cache.erase(folder+str(record.model))
		DirAccess.remove_absolute(folder+str(record.model))
		record={}; dirty=false; refresh_list()
		if not items.is_empty(): edit(items[0])
		else:
			for child in controls.get_children(): child.queue_free()
			if is_instance_valid(model): model.queue_free()
	confirm.dialog_text="Delete this local miniature? Assignments will use the authored fallback."
	confirm.popup_centered()
