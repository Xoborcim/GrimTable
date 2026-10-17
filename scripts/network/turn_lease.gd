class_name TurnLease
extends RefCounted

var servers: Array = []
var expires_at := 0
var renew_at_msec := 0
var expires_at_msec := 0
var active_expires_at_msec := 0
var cached_for_next_peer := false
var refresh_pending := false
var warning_shown := false

func accept(message: Dictionary, now_msec: int, initial := false) -> String:
	var error := IceConfiguration.validate(message.get("ice_servers"))
	if not error.is_empty(): return error
	var expiry: Variant = message.get("turn_expires_at")
	if expiry == null:
		if IceConfiguration.has_turn(message.ice_servers): return "Signaling server omitted TURN expiry metadata. Update the signaling service."
		servers = message.ice_servers.duplicate(true)
		renew_at_msec = 0
		expires_at = 0
		refresh_pending = false
		return ""
	if not ScenarioDefinition.integer(message.get("server_time"), 1, 100000000000) or not ScenarioDefinition.integer(expiry, int(message.server_time) + 1, int(message.server_time) + 86400): return "Invalid TURN credential expiry"
	var lifetime := int(expiry) - int(message.server_time)
	servers = message.ice_servers.duplicate(true)
	expires_at = int(expiry)
	expires_at_msec = now_msec + lifetime * 1000
	renew_at_msec = expires_at_msec - mini(300000, int(lifetime * 1000 / 3.0))
	if initial: active_expires_at_msec = expires_at_msec
	else: cached_for_next_peer = true
	refresh_pending = false
	return ""

func due(now_msec: int) -> bool:
	return renew_at_msec > 0 and now_msec >= renew_at_msec and not refresh_pending
