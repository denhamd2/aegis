extends SceneTree
## Real player/ball context; both teams must choose useful attacks without quotas.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game);await process_frame
	game.set_process(false);game.set_physics_process(false);game._set_players_physics_enabled(false)
	game.ball.freeze=true
	for team: Array[FootballPlayer] in [game._home_players,game._away_players]:
		var opposition: Array[FootballPlayer]=game._away_players if team==game._home_players else game._home_players
		var attackers: Array[FootballPlayer]=[]
		var defenders: Array[FootballPlayer]=[]
		for actor in team:
			if actor.profile.role=="outfield":attackers.append(actor)
		for actor in opposition:
			if actor.profile.role=="outfield":defenders.append(actor)
		var carrier:=attackers[0]
		var receiver:=attackers[1]
		var sx:=carrier.attack_sign
		for scenario in ["wing_cross","central_shot","cutback","progressive","open_carry"]:
			for actor in game._home_players+game._away_players:
				actor.reset_for_stoppage();actor.controlled_by_human=false;actor.position=Vector3(-40,0,30);actor.velocity=Vector3.ZERO
			carrier.ai_action_cooldown=0
			var spot:=Vector3(38*sx,0,14)
			if scenario=="central_shot":spot=Vector3(39*sx,0,0)
			if scenario=="cutback":spot=Vector3(46*sx,0,14)
			if scenario in ["progressive","open_carry"]:spot=Vector3.ZERO
			carrier.position=spot;carrier.rotation.y=-PI/2*sx
			receiver.position=Vector3(43*sx,0,2)
			if scenario in ["progressive","open_carry"]:
				receiver.position=Vector3(16*sx,0,8);receiver.velocity=Vector3(3*sx,0,0)
				if scenario=="progressive":defenders[0].position=Vector3(6.5*sx,0,0)
			game.ball.position=spot+Vector3(.6*sx,.13,0);game.ball.last_touch=carrier.team_name
			var choice: Dictionary=game._player_decisions.choose_carrier_action(carrier,team,opposition,game.ball)
			var expected: StringName={"wing_cross":&"cross","central_shot":&"shoot","cutback":&"short_pass","progressive":&"through_pass","open_carry":&"carry"}[scenario]
			print("ATTACK_CHOICE ",carrier.team_name," ",scenario," ",choice)
			assert(choice.type==expected,"Useful attacking choice failed: "+scenario)
			if scenario in ["wing_cross","cutback","progressive"]:assert(choice.receiver_id==receiver.get_instance_id())
		carrier.position=Vector3(40*sx,0,0)
		for opponent in opposition:
			if opponent.profile.role=="goalkeeper":opponent.position=Vector3(44*sx,0,0)
		assert(ShotPlanner.ai_style(carrier)==&"low","Closing goalkeeper favours a quick release")
	game.free();print("ATTACK_CHOICE PASS: crosses, central shots, cutbacks, proactive passing, open carry and closing keeper; both teams")
	quit()
