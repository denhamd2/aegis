extends SceneTree
## The AI's progressive short-pass recipient must survive the visual windup.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var ball: FootballBall = game.ball
	for team: Array[FootballPlayer] in [game._home_players, game._away_players]:
		var opposition: Array[FootballPlayer] = game._away_players if team == game._home_players else game._home_players
		for actor in team + opposition:
			actor.position = Vector3(0, 0, 90)
			actor.controlled_by_human = false
			actor.receive_target_time = 0
			actor.ai_action_cooldown = 0
			actor._footballer_visual.end_presentation()
		var outfield: Array[FootballPlayer] = []
		for actor in team:
			if actor.profile.role == "outfield":outfield.append(actor)
		var carrier := outfield[0]
		var near := outfield[1]
		var progressive := outfield[2]
		var sign_x := carrier.attack_sign
		carrier.position = Vector3.ZERO
		carrier.rotation.y = -PI/2 * sign_x
		near.position = Vector3(8*sign_x, 0, 0)
		progressive.position = Vector3(16*sign_x, 0, 0)
		var defender: FootballPlayer = game._nearest_outfielder(opposition, Vector2.ZERO)
		defender.position = Vector3(4.6*sign_x, 0, 1.8)
		ball.freeze = false
		ball.position = Vector3(.6*sign_x, .11, 0)
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.last_touch = carrier.team_name
		var decision: Dictionary = game._player_decisions.choose_carrier_action(carrier, team, opposition, ball)
		if decision.get("type") != &"short_pass" or decision.get("direction", Vector3.ZERO).normalized().dot(Vector3(sign_x,0,0)) < .99:
			_fail(game, "Fixture did not select a progressive short pass: " + str(decision));return
		game._apply_carrier_action(carrier, team, opposition)
		for frame in 30:await physics_frame
		if progressive.receive_target_time <= 0 or near.receive_target_time > 0:
			_fail(game, "AI-selected progressive recipient was replaced by the nearer collinear teammate at contact");return
		print("PASS_COMMITMENT ", carrier.team_name, " selected=", progressive.profile.player_id)
		# An unavailable committed receiver cancels rather than secretly retargets.
		carrier._footballer_visual.end_presentation()
		near.receive_target_time = 0;progressive.receive_target_time = 0
		ball.position = Vector3(.6*sign_x,.11,0);ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		var serial := ball.action_serial
		carrier._do_pass(false,Vector3(sign_x,0,0),false,1.0,progressive)
		progressive.position = Vector3(0,0,90)
		for frame in 30:await physics_frame
		if ball.action_serial != serial or near.receive_target_time > 0:
			_fail(game,"Unavailable committed recipient silently retargeted another player");return
	game.free();quit(0)
func _fail(game: Node, message: String) -> void:
	push_error(message);game.free();quit(1)
