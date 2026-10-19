extends SceneTree
## Reception gives way to carrying on contact, and to defending on turnover.

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
		await physics_frame
		var opposition: Array[FootballPlayer] = game._away_players if team == game._home_players else game._home_players
		for actor in game._home_players + game._away_players:
			actor.global_position = Vector3(-40.0, 0.0, 30.0)
			actor.velocity = Vector3.ZERO
			actor.receive_target_time = 0.0
			actor.ai_action_cooldown = 0.0
		var receiver: FootballPlayer
		for actor in team:
			if actor.profile.role == "outfield":
				receiver = actor
				break
		var direction := Vector3(receiver.attack_sign, 0.0, 0.0)
		receiver.global_position = direction * 12.0 + Vector3(0.0, 0.0, 6.0)
		receiver.rotation.y = -PI * 0.5 * receiver.attack_sign
		receiver._flat_direction = direction
		receiver._stick = Vector2.RIGHT
		receiver.receive_target = receiver.global_position - direction
		receiver.receive_target_time = 2.0
		ball.global_position = receiver.global_position + direction * 0.55 + Vector3.UP * FootballBall.RADIUS
		ball.linear_velocity = Vector3.ZERO
		ball._dribble_cooldowns.clear()
		ball._dribble_controller = null
		ball._kick_control_release = 0.0
		ball.last_touch = receiver.team_name
		ball.last_action = &"pass"
		var ball_position := Vector2(ball.global_position.x, ball.global_position.z)
		game._update_team_ai(team, receiver, ball_position, ball_position, opposition)
		if (receiver.get_meta("ai_target_position") as Vector3).distance_to(receiver.receive_target) > 0.01:
			_fail(game, "Incoming pass lost its reception target before contact")
			return
		receiver._update_dribble(1.0 / 60.0)
		if ball.last_action != &"dribble":
			_fail(game, "Reception fixture did not produce a physical control touch")
			return
		game._update_team_ai(team, receiver, ball_position, ball_position, opposition)
		var carry_target: Vector3 = receiver.get_meta("ai_target_position")
		if receiver.receive_target_time > 0.0 or (carry_target.x - ball.global_position.x) * receiver.attack_sign < 2.5:
			_fail(game, "Receiver kept chasing its stale arrival point after controlling the pass")
			return
		receiver.receive_target = direction * 40.0 + Vector3(0.0, 0.0, 25.0)
		receiver.receive_target_time = 2.0
		ball.last_touch = opposition[0].team_name
		ball.last_action = &"tackle"
		game._update_team_ai(team, receiver, ball_position, ball_position, opposition)
		if (receiver.get_meta("ai_target_position") as Vector3).distance_to(receiver.receive_target) < 0.01:
			_fail(game, "A turnover left the defender chasing an obsolete pass target")
			return
		receiver._physics_process(1.0 / 60.0)
		if receiver.receive_target_time > 0.0:
			_fail(game, "A lost pass retained its reception timer beyond the next physics tick")
			return
	print("PASS: receipt resumes carrying, and turnover resumes defending, in both directions")
	game.free()
	quit(0)

func _fail(game: Node, message: String) -> void:
	push_error(message)
	game.free()
	quit(1)
