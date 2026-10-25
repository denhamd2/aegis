extends SceneTree
## A nearby runner at a future interception point must not steal the carrier's action.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var ball := game.get_node("Ball") as FootballBall
	ball.freeze = true
	for actor in game._home_players + game._away_players:
		actor.set_physics_process(false)
		actor.controlled_by_human = false
	for team: Array[FootballPlayer] in [game._home_players, game._away_players]:
		var attackers: Array[FootballPlayer] = []
		for actor in game._home_players + game._away_players:
			actor.global_position = Vector3(0.0, 0.0, 28.0)
			actor.velocity = Vector3.ZERO
			actor.receive_target_time = 0.0
			actor.ai_action_cooldown = 0.0
		for actor in team:
			if actor.profile.role == "outfield":
				attackers.append(actor)
		var carrier := attackers[0]
		var runner := attackers[1]
		var attack_sign := carrier.attack_sign
		carrier.global_position = Vector3(attack_sign * 35.8, 0.0, 0.0)
		runner.global_position = Vector3(attack_sign * 37.9, 0.0, 0.0)
		ball.global_position = Vector3(attack_sign * 36.5, FootballBall.RADIUS, 0.0)
		ball.linear_velocity = Vector3(attack_sign * 12.0, 0.0, 0.0)
		ball.last_touch = carrier.team_name
		ball.last_action = &"dribble"
		var ball_position := Vector2(ball.global_position.x, ball.global_position.z)
		var predicted: Vector2 = game._best_interception_position(team, ball_position)
		if game._nearest_outfielder(team, predicted) != runner or not carrier._can_kick() or runner._can_kick():
			_fail(game, "Carrier/interception fixture did not separate present contact from future interception")
			return
		game._ai_tick = 0.0
		game._next_home_ai = team == game._home_players
		game._update_ai(1.0 / 60.0)
		print("CARRIER_ID team=", carrier.team_name, " carrier_intent=", carrier.get_meta("ai_role_intent"),
			" shot_queued=", carrier._visual_shot_pending)
		if not carrier._visual_shot_pending or carrier.get_meta("ai_role_intent") != "carry":
			_fail(game, "Predictive chaser displaced the reachable ball carrier and suppressed its shot")
			return
		# Once nobody can play the travelling ball, retain the predicted runner.
		carrier.global_position = Vector3(attack_sign * 30.0, 0.0, 0.0)
		ball.last_action = &"pass"
		runner.receive_target = Vector3(predicted.x, 0, predicted.y)
		runner.receive_target_time = 1.0
		game._ai_tick = 0.0
		game._next_home_ai = team == game._home_players
		game._update_ai(1.0 / 60.0)
		if runner.get_meta("ai_role_intent") != "carry" or carrier.get_meta("ai_role_intent") == "carry":
			_fail(game, "Contact priority displaced prediction for a ball outside everyone's kicking range")
			return
	print("PASS: current ball contact takes priority over future interception in both directions")
	game.free()
	quit(0)

func _fail(game: Node, message: String) -> void:
	push_error(message)
	game.free()
	quit(1)
