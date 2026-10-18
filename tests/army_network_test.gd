extends SceneTree

class LocalSession extends NetworkSession:
	var packets: Array[Dictionary]=[]
	func _send(message: Dictionary) -> void:packets.append(JSON.parse_string(JSON.stringify(message)))

var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+label)
func run() -> void:
	var lists:=ArmyRoster.records();var armies: Array=[]
	for faction in ["legion","swarm"]:armies.append(lists.filter(func(a):return a.faction==faction and a.points_limit==500)[0])
	var rules:={"points":500,"primary":"control","tactical":true,"homebrew":false,"seed":15015}
	var map: Dictionary=ScenarioLibrary.read("res://resources/scenarios/hollow_basilica.json").data
	map.board.environment_art=false
	var built:=ArmyAgreement.build(map,armies,rules)
	check(built.has("data"),"Online army proposal validates")
	var wire: Dictionary=JSON.parse_string(JSON.stringify(built))
	var rebuilt:=ArmyAgreement.build(wire.data,wire.data.army_lists,JSON.parse_string(JSON.stringify(rules)))
	check(rebuilt.agreement_hash==built.agreement_hash,"Agreement hash survives wire serialization and independent reconstruction")
	var changed: Dictionary=armies[1].duplicate(true);changed.points_limit=1000
	check(not ArmyAgreement.proposal_error(changed,rules).is_empty(),"Host rejects mismatched budgets")
	changed=armies[1].duplicate(true);changed.units[0].upgrades={"tank_cannon":5}
	check(not ArmyAgreement.proposal_error(changed,rules).is_empty(),"Host rejects illegal loadouts")
	var host_game: Node3D=load("res://scenes/main/main.tscn").instantiate();host_game.scenario=map.duplicate(true);host_game.settings=AppSettings.new();host_game.settings.autosave=false;root.add_child(host_game)
	var guest_game: Node3D=load("res://scenes/main/main.tscn").instantiate();guest_game.scenario=map.duplicate(true);guest_game.settings=AppSettings.new();guest_game.settings.autosave=false;root.add_child(guest_game)
	var host_session:=LocalSession.new();host_session.game=host_game;host_session.host=true;host_session.army_offer=armies[0];host_session.army_rules=rules;root.add_child(host_session)
	var guest:=LocalSession.new();guest.game=guest_game;guest.army_offer=armies[1];root.add_child(guest)
	host_session.transport=MultiplayerTransport.new();guest.transport=MultiplayerTransport.new()
	root.add_child(host_session.transport);root.add_child(guest.transport)
	host_session._accepted();guest._accepted()
	check(not host_session.army_match_ready,"Battle waits for agreement")
	host_session._receive(guest.packets.back())
	check(host_session.army_pending.has("data"),"Host constructs canonical scenario from offered army")
	guest._receive(host_session.packets.back())
	check(guest.army_pending.has("data"),"Client validates host proposal and its own unchanged army")
	host_session.accept_armies()
	check(not host_session.army_match_ready,"One player's consent cannot start the battle")
	guest.accept_armies();host_session._receive(guest.packets.back())
	check(host_session.army_match_ready,"Both explicit accepts establish the match")
	guest._receive(host_session.packets.back())
	check(guest.army_match_ready and guest.started,"Guest applies agreed roster snapshot")
	check(host_game.initial_scenario.armies.size()==guest_game.initial_scenario.armies.size(),"Same authoritative squad composition")
	check(NetworkSession.state_hash(WorldState.capture(host_game))==NetworkSession.state_hash(WorldState.capture(guest_game)),"Host and client canonical state hashes agree")
	check(host_game.manager.missions==guest_game.manager.missions,"Mission draw pile identical on both peers")
	host_session.transport.queue_free();guest.transport.queue_free();host_session.queue_free();guest.queue_free();host_game.queue_free();guest_game.queue_free();await process_frame
	print("GRIMTABLE ARMY NETWORK ",checks," checks / ",failures," failures")
	quit(0 if failures==0 else 1)
