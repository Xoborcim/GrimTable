extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL · ", title)

func run() -> void:
	var manifest := NetworkCompatibility.manifest()
	check(NetworkCompatibility.error_for(manifest).is_empty(), "matching build compatible")
	check(NetworkCompatibility.error_for(JSON.parse_string(JSON.stringify(manifest))).is_empty(), "compatibility survives JSON numeric conversion")
	for key in ["protocol", "game_version", "scenario_schema", "action_schema", "profiles"]:
		var bad := manifest.duplicate(true)
		bad[key] = "different"
		check(not NetworkCompatibility.error_for(bad).is_empty(), "reject incompatible " + key)
	check(not NetworkCompatibility.error_for(null).is_empty(), "reject missing compatibility")
	var ledger := RequestLedger.new()
	check(ledger.accept(1), "first request accepted")
	check(not ledger.accept(1), "duplicate rejected")
	check(not ledger.accept(0), "older request rejected")
	for index in range(2, 300): ledger.accept(index)
	check(ledger.recent.size() == RequestLedger.CAPACITY, "request ledger is bounded")
	check(not ledger.accept(1), "evicted old ID remains rejected")
	check(not ledger.accept(2.5), "fractional ID rejected")
	check(not ledger.accept("300"), "string ID rejected")
	check(ledger.accept(300), "fresh ID after duplicates accepted")
	for token in [null, "", "A".repeat(42), "A".repeat(44), "=".repeat(43), "A".repeat(42) + "\n"]:
		check(not IceConfiguration.token_valid(token), "invalid token rejected")
	check(IceConfiguration.token_valid("A".repeat(43)), "opaque token accepted")
	for url in ["stun:localhost:3478", "turn:relay.example.com:3478?transport=udp", "turns:relay.example.com:5349?transport=tcp", "turn:[::1]:3478"]:
		check(IceConfiguration.url_valid(url), "valid ICE URL")
	for url in ["turns:", "stun:", "stun://localhost", "turn:host:99999", "turn:host:0", "turn:host\n", "turn:host?transport=magic", "turn:host/path", "turn:host:abc", "turn:[]:3478", "turn:[:]:3478", "https://host"]:
		check(not IceConfiguration.url_valid(url), "invalid native ICE URL blocked")
	check(IceConfiguration.validate([]).is_empty(), "local host candidates need no ICE servers")
	check(not IceConfiguration.validate([{"urls": ["turn:localhost:3478"]}]).is_empty(), "TURN credentials mandatory")
	check(not IceConfiguration.validate([{"urls": "stun:localhost"}]).is_empty(), "URL collection type validated")
	check(not IceConfiguration.validate([{"urls": []}]).is_empty(), "empty URL group rejected")
	check(not IceConfiguration.validate([{"urls": ["turn:localhost"], "username": {}, "credential": "secret"}]).is_empty(), "credential types checked")
	var lease := TurnLease.new()
	var message := {"ice_servers": [{"urls": ["turn:localhost:3478"], "username": "1700000060:test", "credential": "fixed-test-value"}], "server_time": 1700000000, "turn_expires_at": 1700000060}
	check(lease.accept(message, 1000, true).is_empty(), "initial lease accepted")
	check(lease.expires_at_msec == 61000 and lease.renew_at_msec == 41000, "renewal uses server TTL and monotonic clock")
	check(not lease.due(40999) and lease.due(41000), "renewal starts before expiry")
	lease.refresh_pending = true
	check(not lease.due(41000), "no duplicate concurrent refresh")
	message.server_time += 40
	message.turn_expires_at += 40
	check(lease.accept(message, 41000).is_empty(), "fresh lease accepted")
	check(lease.cached_for_next_peer and lease.active_expires_at_msec == 61000 and lease.expires_at_msec == 101000, "renewal never pretends to reconfigure active peer")
	message.turn_expires_at = message.server_time
	check(not lease.accept(message, 41000).is_empty(), "expired lease rejected")
	message.erase("turn_expires_at")
	check(not lease.accept(message, 41000).is_empty(), "TURN expiry metadata required")
	for type in ["host", "srflx", "prflx", "relay"]:
		check(IceConfiguration.candidate_type("candidate:1 1 UDP 1 127.0.0.1 4000 typ " + type) == type, "candidate type recognized without exposing IP")
	check(IceConfiguration.candidate_type("garbage") == "unknown", "unknown candidate safe")
	var online := OnlineTransport.new()
	online.is_host = true
	root.add_child(online)
	check(online._setup([]), "native peer initializes")
	var rtc: WebRTCMultiplayerPeer = online.peer
	var channel: WebRTCDataChannel = rtc.get_peer(2).channels[0]
	check(channel.is_ordered(), "gameplay channel is ordered")
	# The pinned native implementation uses -1 for unspecified; browser API docs
	# use 65535. Verify the actual native channel rather than assume a default.
	check(channel.get_max_packet_life_time() == -1 and channel.get_max_retransmits() == -1, "native gameplay channel has no partial reliability limits")
	online.relay_only = true
	var filtered := online._filter_sdp("a=candidate:1 1 UDP 1 127.0.0.1 4000 typ host\r\na=candidate:2 1 UDP 1 203.0.113.1 4001 typ relay\r\n")
	check(not "typ host" in filtered and "typ relay" in filtered, "force TURN filters direct SDP candidates")
	check("TLS" in OnlineTransport.signaling_error(true) and "local service" in OnlineTransport.signaling_error(false), "actionable signaling failure messages")
	check("No relay candidate" in online.ice_failure(), "missing relay message does not invent server diagnosis")
	online.local_types.relay = true
	check("UDP port range" in online.ice_failure(), "relay timeout is actionable")
	online.close(); online.queue_free()
	var forced := OnlineTransport.new()
	forced.relay_only = true
	root.add_child(forced)
	check(not forced._setup([]) and forced.failed, "forced relay without TURN fails immediately")
	forced.close(); forced.queue_free()
	var game: Node3D = load("res://scenes/main/main.tscn").instantiate()
	game.settings = AppSettings.new(); game.settings.autosave = false
	root.add_child(game)
	var session := NetworkSession.new()
	root.add_child(session)
	var transport := MultiplayerTransport.new()
	root.add_child(transport)
	session.open(transport, game)
	var errors: Array[String] = []
	session.disconnected.connect(func(reason: String): errors.append(reason))
	session.remote_id = 1
	session.handshake_elapsed = 16
	session._process(0)
	check(errors.size() == 1 and "compatibility" in errors[0], "handshake timeout ends connecting state")
	session.disconnected_once = false
	session.compatibility_accepted = true
	session.snapshot_waiting = true
	session.snapshot_elapsed = 21
	session._process(0)
	check(errors.size() == 2 and "snapshot" in errors[1], "snapshot timeout ends synchronization state")
	session.detach(); session.queue_free(); transport.queue_free(); game.queue_free()
	await process_frame
	print("GRIMTABLE INTERNET READINESS: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
