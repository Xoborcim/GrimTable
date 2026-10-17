class_name MultiplayerTransport
extends Node

signal status_changed(text: String)
signal room_created(code: String)
signal peer_ready
signal connection_lost(reason: String)
var peer: MultiplayerPeer
var is_host := false
var connected := false
var label := ""

func close() -> void:
	connected = false
	if peer != null: peer.close()
	peer = null

func diagnostics() -> String:
	return label + " · " + ("Connected" if connected else "Waiting")
