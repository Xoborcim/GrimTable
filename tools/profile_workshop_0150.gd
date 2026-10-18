extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var app: Node=load("res://scenes/main/app.tscn").instantiate();root.add_child(app)
	await process_frame
	var started:=Time.get_ticks_usec()
	var workshop: MiniatureWorkshop=app.show_workshop()
	for i in 4:await process_frame
	var report:={"load_ms":(Time.get_ticks_usec()-started)/1000.0}
	for operation in ["fingerprint","checkpoint","refresh_materials"]:
		started=Time.get_ticks_usec()
		for i in 8:
			workshop.document.effects.wash=.2+i*.01
			workshop.call(operation)
		report[operation+"_ms"]=(Time.get_ticks_usec()-started)/8000.0
	print("WORKSHOP PROFILE ",JSON.stringify(report))
	app.queue_free();await process_frame;quit()
