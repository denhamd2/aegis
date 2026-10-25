extends SceneTree
## Verifies an incoming first-time pass reaches the authored contact frame in time.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/training_ground.tscn") as PackedScene
	assert(packed != null, "Match scene failed to load for first-time pass check")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var player := game.get_node("Player") as FootballPlayer
	var ball := game.get_node("Ball") as FootballBall
	var visual := player.get_node("Visual") as FootballerVisual
	game.set("_kickoff_pending", false)
	game._set_players_physics_enabled(false)
	player.controlled_by_human = true
	player.global_position = Vector3.ZERO
	player.rotation.y = -PI * 0.5
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	for actor in game.get("_home_players") + game.get("_away_players"):
		if actor != player:
			actor.global_position = Vector3(30.0, 0.0, 30.0)
	var touch_result := {"count": 0, "gap": INF}
	ball.touched.connect(func(_kind: StringName, _speed: float) -> void:
		touch_result["count"] = int(touch_result["count"]) + 1
		touch_result["gap"] = ball.global_position.distance_to(player._receive_contact_position()))
	var expected_touch_count := 0
	for launch_speed in [8.5, 18.0]:
		for _frame in 60:
			await physics_frame
		player.global_position = Vector3.ZERO
		player.rotation.y = -PI * 0.5
		player.velocity = Vector3.ZERO
		player._pending_pass = 0.0
		player._visual_pass_pending = false
		ball.freeze = false
		ball.global_position = Vector3(1.5, FootballBall.RADIUS, 0.0)
		ball.linear_velocity = Vector3(-launch_speed, 0.0, 0.0)
		ball.angular_velocity = Vector3.ZERO
		ball.last_touch = player.team_name
		ball.last_action = &"pass"
		ball.action_serial = 0
		ball.reset_physics_interpolation()
		player._queue_pass(false)
		assert(player._ball_will_reach_kick_window(), "Incoming pass was not recognized")
		player._update_actions(1.0 / 60.0)
		assert(player.get("_visual_pass_pending"),
			"First-time pass did not start before the ball reached the player")
		assert(visual.animation_player.get_playing_speed() > 1.2,
			"Incoming pass did not accelerate its contact animation to match ball arrival")
		var contact_frame := -1
		for frame in 30:
			await physics_frame
			# Movement is disabled in this fixture; still tick the real contact
			# window as FootballPlayer._physics_process does in the match.
			player._resolve_pending_kick_contact(1.0 / 60.0)
			if ball.action_serial == 1:
				contact_frame = frame + 1
				break
		if contact_frame <= 0 or contact_frame > 20:
			push_error("First-time pass missed its predicted contact window (frame %d)" % contact_frame)
			quit(1)
			return
		expected_touch_count += 1
		assert(ball.last_action == &"pass" and touch_result["count"] == expected_touch_count,
			"First-time contact did not produce exactly one pass impulse")
		assert(float(touch_result["gap"]) <= player.tuning.kick_foot_contact_radius,
			"First-time pass bypassed the live boot contact window")
		print("First-time %.1f m/s pass contact: physics frame %d (%.3f s), one impulse, gap %.3f m" % [
			launch_speed, contact_frame, float(contact_frame) / 60.0, float(touch_result["gap"])])
	quit(0)
