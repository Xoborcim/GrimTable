class_name MultiplayerMenu
extends RefCounted

var app: Node
var session: NetworkSession
var transport: MultiplayerTransport
var room_label: Label
var code_field: LineEdit
var name_field: LineEdit
var server_field: LineEdit
var scenario_choice: OptionButton
var scenarios: Array[Dictionary] = []

func _init(application: Node) -> void:
	app = application

func show_menu() -> void:
	app.clear_menu("Multiplayer · Online")
	AppUI.label(app.column, "Create a private room and share its code with one friend.", 16)
	AppUI.button(app.column, "Create Online Game", func(): form(true))
	AppUI.button(app.column, "Join Online Game", func(): form(false))
	AppUI.button(app.column, "Network Server Settings", settings)
	AppUI.label(app.column, "Advanced", 14)
	AppUI.button(app.column, "LAN / Direct IP", lan_form)
	AppUI.button(app.column, "Back", app.show_main)

func field(title: String, value: String) -> LineEdit:
	AppUI.label(app.column, title, 15)
	var control := LineEdit.new()
	control.text = value
	app.column.add_child(control)
	return control

func settings() -> void:
	app.clear_menu("Network · Custom / community signaling server")
	AppUI.label(app.column, "No hosted default service is provisioned. Use your community server's WSS URL. The local development default is below.", 16).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	server_field = field("Signaling URL (WSS; WS allowed on localhost)", app.settings.signaling_url)
	AppUI.button(app.column, "Save", func():
		if not OnlineTransport.valid_url(server_field.text.strip_edges()): app.status.text = "Use wss:// for remote servers, or ws://localhost:8080 locally."; return
		app.settings.signaling_url = server_field.text.strip_edges()
		app.status.text = app.settings.save_settings())
	AppUI.button(app.column, "Back", show_menu)

func choose_scenario() -> void:
	scenarios = ScenarioLibrary.list_scenarios().filter(func(item: Dictionary): return item.has("data"))
	AppUI.label(app.column, "Scenario", 15)
	scenario_choice = OptionButton.new()
	for item in scenarios: scenario_choice.add_item(item.data.name)
	app.column.add_child(scenario_choice)

func form(hosting: bool) -> void:
	app.clear_menu("Create Online Game" if hosting else "Join Online Game")
	name_field = field("Player Name", app.settings.player_name)
	if hosting: choose_scenario()
	else:
		code_field = field("Room Code", "")
		code_field.max_length = 6
	AppUI.label(app.column, "Server: " + app.settings.signaling_url, 14)
	AppUI.button(app.column, "Create Room" if hosting else "Join", func():
		var display := name_field.text.strip_edges()
		var code := "" if hosting else code_field.text.strip_edges().to_upper()
		if display.is_empty() or (not hosting and code.length() != 6): app.status.text = "Enter your name and a six-character room code."; return
		app.settings.player_name = display
		app.settings.save_settings()
		var online := OnlineTransport.new()
		app.add_child(online)
		var error := online.open(hosting, app.settings.signaling_url, display, code)
		if error != OK: online.queue_free(); app.status.text = "Unable to start connection: " + error_string(error); return
		begin(online, scenarios[scenario_choice.selected] if hosting else ScenarioLibrary.read(ScenarioLibrary.BUILTINS[0])))
	AppUI.button(app.column, "Server Settings", settings)
	AppUI.button(app.column, "Back", show_menu)

func lan_form() -> void:
	app.clear_menu("Advanced · LAN / Direct IP")
	var address := field("Host Address", "127.0.0.1")
	var port := field("UDP Port", "7777")
	choose_scenario()
	for hosting in [true, false]:
		AppUI.button(app.column, "Host LAN Game" if hosting else "Connect to Host", func():
			if not port.text.is_valid_int() or int(port.text) < 1024 or int(port.text) > 65535: app.status.text = "Port must be 1024–65535"; return
			var enet := ENetTransport.new()
			app.add_child(enet)
			var error := enet.open(hosting, address.text.strip_edges(), int(port.text))
			if error != OK: enet.queue_free(); app.status.text = "Connection could not start: " + error_string(error); return
			begin(enet, scenarios[scenario_choice.selected]))
	AppUI.label(app.column, "Internet Direct IP requires a reachable host UDP port. Online room codes use WebRTC instead.", 14).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	AppUI.button(app.column, "Back", show_menu)

func begin(next_transport: MultiplayerTransport, item: Dictionary) -> void:
	if not app.launch_scenario(item): next_transport.close(); next_transport.queue_free(); return
	transport = next_transport
	session = NetworkSession.new()
	app.add_child(session)
	session.open(transport, app.game)
	session.status_changed.connect(func(text: String):
		if is_instance_valid(app.game): app.game.hud.set_status(text)
		if is_instance_valid(room_label): room_label.text = text)
	session.disconnected.connect(lost)
	session.opponent_connected.connect(func():
		app.game.hud.show()
		app.menu.hide(); app.backdrop.hide())
	transport.status_changed.connect(func(text: String):
		if is_instance_valid(room_label): room_label.text = text)
	transport.room_created.connect(func(code: String):
		if is_instance_valid(room_label): room_label.text = "ROOM CODE\n" + code + "\nWaiting for opponent…")
	app.clear_menu("Online Lobby" if transport is OnlineTransport else "LAN Lobby")
	app.game.hud.hide()
	room_label = AppUI.label(app.column, "Connecting…", 25)
	AppUI.button(app.column, "Copy Code", func():
		if transport is OnlineTransport: DisplayServer.clipboard_set(transport.code))
	AppUI.button(app.column, "Cancel", func(): close(); app.show_main())

func lost(reason: String) -> void:
	if not is_instance_valid(app.game): return
	app.game.hud.hide()
	app.game.interaction.read_only = true
	app.clear_menu(reason)
	AppUI.label(app.column, "No automatic reconnect is available. Create a new room to play together again.", 16)
	if session.host:
		AppUI.button(app.column, "Continue Locally", func(): close(); app.game.interaction.read_only = false; app.resume())
	AppUI.button(app.column, "Return to Menu", func(): close(); app.show_main())

func close() -> void:
	if is_instance_valid(session): session.detach(); session.queue_free()
	if is_instance_valid(transport): transport.queue_free()
	session = null
	transport = null
	room_label = null
