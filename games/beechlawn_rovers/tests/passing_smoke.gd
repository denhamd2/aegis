extends SceneTree
## Verifies teammate targeting, through-ball lead, and receiver movement.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	root.get_node("MatchSession").switch_mode = &"manual"
	var scene := load("res://scenes/training_ground.tscn") as PackedScene
	assert(scene != null, "Sunday-league match scene failed to load")
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set("_kickoff_pending", false)
	game._set_players_physics_enabled(true)

	var passer := game.get_node("Player") as FootballPlayer
	var visual := passer.get_node("Visual") as FootballerVisual
	var ball := game.get_node("Ball") as FootballBall
	var home: Array = game.get("_home_players")
	var receiver: FootballPlayer
	for actor in home:
		if actor != passer and actor.profile.role == "outfield":
			receiver = actor
			break
	assert(receiver != null, "Could not find a Beechlawn receiving teammate")
	passer.global_position = Vector3.ZERO
	passer.velocity = Vector3.ZERO
	ball.freeze = true
	ball.global_position = Vector3(0.60, FootballBall.RADIUS, 0.0)
	ball.last_touch = passer.team_name
	for actor in home:
		if actor != passer:
			actor.global_position = Vector3(12.0, 0.0, 14.0)
	receiver.global_position = Vector3(10.0, 0.0, 1.0)
	var chosen := passer._choose_pass_target(Vector3.RIGHT, true)
	assert(chosen.get("receiver") == receiver, "Pass did not select the teammate in the aimed lane")
	passer._do_pass(true)
	for _frame in 27:
		await physics_frame
	assert(ball.last_touch == passer.team_name, "Pass did not register the passing team's touch")
	assert(receiver.receive_target_time > 0.0, "AI receiver did not receive a timed movement target")
	var target_gap_before := receiver.global_position.distance_to(receiver.receive_target)
	for _frame in 24:
		await physics_frame
	var target_gap_after := receiver.global_position.distance_to(receiver.receive_target)
	assert(target_gap_after < target_gap_before - 0.25,
		"AI receiver did not move toward the pass target")
	# Let the authored pass finish before issuing another action; the second
	# request intentionally tests buffering rather than interrupting the kick.
	for _frame in 36:
		await physics_frame

	# A leading pass should place the target ahead of a moving runner.
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	receiver.receive_target_time = 0.0
	receiver.global_position = Vector3(10.0, 0.0, 1.0)
	receiver.velocity = Vector3(0.0, 0.0, -3.0)
	var through := passer._choose_pass_target(Vector3.RIGHT, true)
	var through_target: Vector3 = through.get("position", Vector3.ZERO)
	assert(through.get("receiver") == receiver, "Through ball selected the wrong teammate")
	assert(through_target.z < receiver.global_position.z,
		"Through ball did not lead the runner's current movement")

	# A pass can be queued only when the ball's current trajectory is closing
	# on the controlled player's kick window, then executes on physical arrival.
	ball.freeze = false
	ball.global_position = Vector3(2.0, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3(-4.0, 0.0, 0.0)
	ball.last_touch = passer.team_name
	assert(passer._ball_will_reach_kick_window(), "Incoming ground pass was not recognized")
	var first_time_result := {"kind": &"none"}
	ball.touched.connect(func(kind: StringName, _speed: float) -> void: first_time_result["kind"] = kind)
	passer._queue_pass(false)
	assert(passer._pending_pass > 0.8, "Incoming pass did not receive the extended first-time buffer")
	ball.global_position = passer.global_position + Vector3(0.9, FootballBall.RADIUS, 0.0)
	passer._update_actions(0.016)
	assert(passer.get("_visual_pass_pending"),
		"Buffered first-time pass did not start its contact-timed pass animation")
	# Evaluate the real boot pose before emitting the authored marker. Root
	# approach eligibility alone no longer authorizes a remote pass impulse.
	visual.animation_player.seek(visual.action_contact_time(&"pass"), true)
	ball.global_position = passer._receive_contact_position() + Vector3.UP * 0.06
	visual.on_action_contact_marker()
	assert(ball.last_touch == passer.team_name, "Buffered first-time pass did not execute on arrival")
	assert(first_time_result["kind"] == &"pass", "Buffered first-time pass did not produce a pass action")
	ball.last_touch = &"Boardeaux"
	assert(not passer._ball_will_reach_kick_window(), "First-time pass buffer accepted an opponent ball")

	# AI should choose a reachable point ahead on a moving ball's path.
	ball.freeze = true
	ball.global_position = Vector3.ZERO
	ball.linear_velocity = Vector3(10.0, 0.0, 0.0)
	var away: Array = game.get("_away_players")
	for actor in away:
		actor.global_position = Vector3(40.0, 0.0, 20.0)
	var defender: FootballPlayer = away[1]
	defender.global_position = Vector3(4.0, 0.0, 0.0)
	var interception: Vector2 = game._best_interception_position(away, Vector2.ZERO)
	assert(interception.x > 1.0 and interception.x < 4.5,
		"AI interception target was not placed on the reachable ball path")
	ball.global_position = Vector3(defender.global_position.x, FootballBall.RADIUS,
		defender.global_position.z)
	ball.last_touch = passer.team_name
	ball._dribble_cooldowns.clear()
	assert(ball.dribble_touch(defender, Vector3.LEFT, false, true, 0.23, 0.48, 1.05),
		"Defender could not claim the ball at close interception contact")
	assert(ball.last_touch == defender.team_name,
		"Interception contact did not transfer the ball's team touch")
	print("Beechlawn passing and receiving checks passed")
	quit(0)
