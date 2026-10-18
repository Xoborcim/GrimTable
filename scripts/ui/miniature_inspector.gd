class_name MiniatureInspector
extends CanvasLayer

# A visual-only studio. It contains mesh copies, no gameplay bodies or scripts.
var game: Node3D
var model: Miniature
var panel: Control
var camera: Camera3D
var yaw := PI+.5
var pitch := .15
var distance := 4.0
var focus := Vector3.UP
var old_read_only := false
var old_menu := false
var old_interaction_input := true
var old_camera: Array[bool] = []

func _ready() -> void:
	layer=18
	old_read_only=game.interaction.read_only
	old_menu=game.menu_open
	old_interaction_input=game.interaction.is_processing_input()
	game.interaction.read_only=true
	game.menu_open=true
	old_camera=[game.camera_rig.is_processing(),game.camera_rig.is_processing_input(),game.camera_rig.is_processing_unhandled_input()]
	game.camera_rig.set_process(false)
	game.camera_rig.set_process_input(false)
	game.camera_rig.set_process_unhandled_input(false)
	game.interaction.set_process_input(false)
	panel=PanelContainer.new()
	panel.theme=AppUI.theme()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=30; panel.offset_right=-30; panel.offset_top=30; panel.offset_bottom=-30
	var column:=VBoxContainer.new()
	panel.add_child(column)
	AppUI.label(column,"INSPECT MINIATURE  /  "+model.display_name,22)
	var container:=SubViewportContainer.new()
	container.stretch=true
	container.size_flags_vertical=Control.SIZE_EXPAND_FILL
	container.mouse_filter=Control.MOUSE_FILTER_STOP
	container.gui_input.connect(orbit_input)
	column.add_child(container)
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1000,700)
	viewport.own_world_3d=true
	viewport.msaa_3d=Viewport.MSAA_4X
	container.add_child(viewport)
	var studio:=Node3D.new()
	viewport.add_child(studio)
	BattlefieldPresentation.lighting(studio,game.settings)
	viewport.msaa_3d=Viewport.MSAA_DISABLED if game.settings.quality=="Low" else Viewport.MSAA_4X
	viewport.mesh_lod_threshold=0.0
	var sculpt:=Node3D.new()
	studio.add_child(sculpt)
	for source: MeshInstance3D in model.visual_root.find_children("*","MeshInstance3D",true,false):
		var copy:=MeshInstance3D.new()
		copy.mesh=source.mesh
		copy.material_override=source.material_override
		copy.transform=model.visual_root.global_transform.affine_inverse()*source.global_transform
		sculpt.add_child(copy)
	var ground:=model.get_node_or_null("ScenicBaseGround")
	if ground!=null:
		for source: MeshInstance3D in ground.find_children("*","MeshInstance3D",true,false):
			var copy:=MeshInstance3D.new()
			copy.mesh=source.mesh
			copy.material_override=source.material_override
			copy.transform=model.global_transform.affine_inverse()*source.global_transform
			copy.position.y-=.2
			studio.add_child(copy)
	var bounds:=MiniatureLibrary.bounds(sculpt)
	focus=bounds.get_center()
	distance=maxf(2,bounds.size.length()*1.5)
	var base:=CylinderMesh.new()
	base.top_radius=model.base_radius*.91; base.bottom_radius=model.base_radius; base.height=.16
	TableVisuals.mesh(studio,base,Vector3(0,-.08,0),Color("20272b"))
	var floor_mesh:=PlaneMesh.new()
	floor_mesh.size=Vector2(40,40)
	var floor:=TableVisuals.mesh(studio,floor_mesh,Vector3(0,-.18,0),Color("303638"))
	floor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera=Camera3D.new()
	camera.fov=40; camera.near=.025
	studio.add_child(camera)
	update_camera(1)
	var row:=AppUI.row(column)
	AppUI.label(row,"Drag to orbit · Wheel to zoom · Esc to return",14).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for view in [["Front",PI,.05],["Side",PI/2,.05],["Rear",0.0,.05],["Hero",PI+.5,.2]]:
		AppUI.button(row,view[0],func(): yaw=view[1]; pitch=view[2])
	AppUI.button(row,"Return to tactical view",close)
	GrimTheme.enter(panel,game.settings.reduce_motion)

func _process(delta: float) -> void:
	if camera!=null: update_camera(1 if game.settings.reduce_motion else 1-exp(-delta*12))

func update_camera(weight: float) -> void:
	var target:=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.position=camera.position.lerp(target,weight)
	camera.look_at(focus)

func orbit_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw-=event.relative.x*.008
		pitch=clampf(pitch+event.relative.y*.008,-.25,1.45)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: distance=maxf(focus.y*1.7+.8,distance*.9)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance=minf(30,distance*1.1)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode==KEY_ESCAPE: close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if is_queued_for_deletion(): return
	if is_instance_valid(game):
		game.interaction.read_only=old_read_only
		game.interaction.set_process_input(old_interaction_input)
		game.menu_open=old_menu
		game.camera_rig.set_process(old_camera[0])
		game.camera_rig.set_process_input(old_camera[1])
		game.camera_rig.set_process_unhandled_input(old_camera[2])
	queue_free()
