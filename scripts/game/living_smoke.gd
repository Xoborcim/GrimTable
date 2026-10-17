class_name LivingSmoke
extends GuidedSmoke

func run(app: Node) -> void:
	app.settings.autosave = false
	app.settings.reduce_motion = false
	app.show_local_play()
	var choices: Array = app.column.find_children("*","OptionButton",true,false)
	check(choices.size() == 4 and choices[3].selected == 0,"Guided defaults to Easy local AI")
	app.pending_ai = {"teams":{"1":"Easy"},"human_team":0,"seed":77,"round_limit":2,"speed":"Fast"}
	check(app.launch_scenario(ScenarioLibrary.read("res://resources/scenarios/ashfall_station.json")),"Ashfall vs Easy starts")
	game = app.game
	game.ai.set_process(false)
	await settle()
	check(game.ai.controls(1) and not game.ai.controls(0),"Player owns Team A; computer owns Team B")
	await capture("user://living_battlefield.png")
	game.life.set_tactical(true)
	await capture("user://living_tactical.png")
	game.life.set_tactical(false)
	var ticks := 0
	var moves := 0
	var attacks := 0
	while not game.ai.finished and ticks < 300:
		if game.combat.current != null and game.combat.current.remaining > 0 and not game.ai.controls(game.combat.current.target.team):
			var recipient := AttackOptions.suggested(game.combat.current)
			if recipient != null:
				game.combat.allocate(recipient,mini(recipient.wounds,game.combat.current.remaining))
				if recipient.wounds == 0: game.combat.remove_casualty(recipient)
		elif game.ai.active():
			var sequence: int = game.battle_log.sequence
			await game.ai.runtime_step()
			for event in game.battle_log.entries:
				if event.sequence <= sequence: continue
				if event.kind == "attack": attacks += 1
				if event.kind == "execute" and event.payload.kind == "unit_move": moves += 1
			if moves == 1: await capture("user://living_ai_move.png")
		else:
			# The smoke player holds position and ends phases through the real manager.
			game.manager.next_phase()
		ticks += 1
		await get_tree().physics_frame
		if ticks == 12:
			var before := WorldState.capture(game)
			check(SaveService.save_game(game,game.manager,game.battle_log,game.combat,"user://living_smoke.json").begins_with("Saved"),"AI battle saves")
			check(SaveService.load_game(game,game.manager,game.battle_log,game.combat,"user://living_smoke.json").begins_with("Loaded") and game.ai.controls(1),"AI battle resumes on load")
			check(before == WorldState.capture(game),"Save/load preserves the exact battle")
	check(moves > 0,"Easy opponent moves without human control")
	check(attacks > 0,"Easy opponent shoots without human control")
	check(game.manager.round_number > 1 and not game.manager.scored_rounds.is_empty(),"Full round advances and scores")
	check(game.ai.finished and ticks < 300,"Easy match reaches a bounded ending")
	check(game.ai.invalid_actions == 0,"AI actions accepted by normal rules")
	await settle()
	var card: PanelContainer = game.match_overlay.get_child(0)
	check(game.get_viewport().get_visible_rect().encloses(card.get_global_rect()),"End match summary fits the window")
	check(not game.guidance.round_card.visible,"End match summary takes priority over round tutorial")
	await capture("user://living_summary.png")
	var before := WorldState.capture(game)
	var replay := ReplayController.new()
	replay.game = game
	game.add_child(replay)
	check(replay.open({"initial_scenario":game.initial_scenario,"events":game.battle_log.entries.duplicate(true)}).is_empty(),"AI replay opens")
	replay.seek(replay.events.size())
	check(before == WorldState.capture(game),"AI replay restores exact final board and score")
	var file := FileAccess.open("user://living_smoke_result.txt",FileAccess.WRITE)
	file.store_string(("PASS" if failures.is_empty() else "FAIL") + " / " + str(checks) + " checks / moves " + str(moves) + " / attacks " + str(attacks) + "\n" + "\n".join(failures))
	print("GRIMTABLE LIVING SMOKE: ",checks,"; failures: ",failures.size(),"; moves: ",moves,"; attacks: ",attacks)
	get_tree().quit(0 if failures.is_empty() else 1)
