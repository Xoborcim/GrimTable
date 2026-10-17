extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition: failures += 1; print("FAIL · ", title)

func run() -> void:
	# Port 1 is deliberately unused by the local signaling stack. This tests a
	# real socket failure, not a stubbed error-message generator.
	var transport := OnlineTransport.new()
	root.add_child(transport)
	var errors: Array[String] = []
	transport.connection_lost.connect(func(reason: String): errors.append(reason))
	var error := transport.open(true, "ws://127.0.0.1:1", "Failure test")
	check(error == OK or error == ERR_CANT_CONNECT, "connection attempt returns safely")
	var deadline := Time.get_ticks_msec() + 18000
	while errors.is_empty() and Time.get_ticks_msec() < deadline: await create_timer(0.05).timeout
	check(errors.size() == 1 and transport.failed, "unavailable signaling ends connecting state")
	check(not errors.is_empty() and "signaling server" in errors[0], "service-unavailable message is actionable")
	transport.close(); transport.queue_free()
	await process_frame
	print("GRIMTABLE NETWORK FAILURE: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
