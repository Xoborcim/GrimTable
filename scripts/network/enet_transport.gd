class_name ENetTransport
extends MultiplayerTransport

var elapsed := 0.0
var failed := false

func _process(delta: float) -> void:
	if is_host or connected or failed or peer == null: return
	elapsed += delta
	if elapsed > 30:
		failed = true
		connection_lost.emit("Connection attempt timed out. Check host address, port and firewall.")

func open(hosting: bool, address := "127.0.0.1", port := 7777) -> Error:
	is_host = hosting
	label = "LAN / Direct IP"
	var enet := ENetMultiplayerPeer.new()
	var error := enet.create_server(port, 1) if hosting else enet.create_client(address, port)
	if error != OK: return error
	peer = enet
	status_changed.emit("Waiting for opponent…" if hosting else "Connecting…")
	return OK
