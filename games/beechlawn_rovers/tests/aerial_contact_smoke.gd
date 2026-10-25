extends SceneTree
## Real clip markers, bounded physical jumps, misses and both attacking teams.
var failures: Array[String] = []
var headers := 0
var chest_controls := 0
var contact_gaps: Array[float] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 64
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var ball: FootballBall = game.ball
	for actor in game._home_players + game._away_players:
		actor.position = Vector3(0, 0, 90)
		actor.controlled_by_human = false
	ball.touched.connect(func(kind: StringName, _speed: float):
		if ball.last_strike_part == &"head" and kind == &"shot":
			headers += 1
			var actor := ball.last_touch_player as FootballPlayer
			contact_gaps.append(actor._aerial_controller.forehead_point().distance_to(ball.position))
		elif ball.last_strike_part == &"chest" and kind == &"aerial_control":
			chest_controls += 1
			var actor := ball.last_touch_player as FootballPlayer
			contact_gaps.append(actor._aerial_controller.chest_point().distance_to(ball.position)))
	for sx: float in [1.0, -1.0]:
		var team: Array[FootballPlayer] = game._home_players if sx > 0 else game._away_players
		var actor: FootballPlayer
		for candidate in team:
			if candidate.profile.starting_slot == "striker_left": actor = candidate
		actor.reset_for_stoppage()
		actor.position = Vector3(32 * sx, PitchSurface.height_at(32 * sx, 0) + .005, 0)
		actor.rotation.y = -PI / 2 * sx
		actor.controlled_by_human = true
		actor.velocity = Vector3.ZERO
		ball.freeze = true
		ball.release_for_restart()
		ball.position = actor.position + Vector3(2.5 * sx, 2.2, 0)
		await physics_frame
		var destination := actor.position + Vector3(.14 * sx, actor.tuning.header_contact_height, 0)
		ball.freeze = false
		ball.kick_velocity(FootballBallFlight.launch(ball, destination, .31), &"cross", actor.team_name, team[1])
		actor._aerial_controller.request_header(Vector3(sx, 0, 0))
		actor.set_physics_process(true)
		var before := headers
		var start_y := actor.position.y
		var highest := start_y
		for frame in 50:
			await physics_frame
			highest = maxf(highest, actor.position.y)
			if frame == 10: _check(headers == before, "Header impulse occurred before its animation marker")
		_check(headers == before + 1, "Reachable actual header contact failed for side " + str(sx))
		_check(highest - start_y > .12 and highest - start_y < .4, "Header jump was absent or launched the character too high")
		_check(absf(actor.position.y - start_y) < .12 and not actor._aerial_controller.committed(), "Header did not land and recover")
		print("AERIAL_HEADER side=", sx, " headers=", headers - before, " jump_m=", highest - start_y, " ball=", ball.position)
		ball.freeze = true
		for frame in 20: await physics_frame
		_check(absf(actor.position.y - start_y) < .12, "Actor jumped again without an aerial request")
		actor.set_physics_process(false)
		actor.reset_for_stoppage()
		actor.position = Vector3(32 * sx, start_y, 0)
		ball.release_for_restart()
		ball.position = actor.position + Vector3(2.5 * sx, 1.7, 0)
		await physics_frame
		var chest := actor._aerial_controller.chest_point()
		ball.freeze = false
		ball.kick_velocity(FootballBallFlight.launch(ball, chest, .235), &"lofted_pass", actor.team_name, team[1])
		actor.receive_target_time = 1
		actor.receive_target_kind = &"lofted_pass"
		actor.set_physics_process(true)
		before = chest_controls
		for frame in 38: await physics_frame
		_check(chest_controls == before + 1, "Aerial chest reception failed for side " + str(sx))
		_check(ball.linear_velocity.length() < 5, "Chest touch failed to cushion the incoming ball")
		actor.set_physics_process(false)
		actor.reset_for_stoppage()
		ball.freeze = true
		ball.release_for_restart()
		actor.position = Vector3(5*sx, PitchSurface.height_at(5*sx,0)+.005, 0)
		actor.controlled_by_human = false
		actor.set_meta("ai_role_intent", "press")
		actor.receive_target_time = 0
		ball.position = actor.position + Vector3(2.5*sx,1.7,0)
		await physics_frame
		var opposition: Array[FootballPlayer] = game._away_players if sx>0 else game._home_players
		ball.freeze = false
		ball.kick_velocity(FootballBallFlight.launch(ball,actor._aerial_controller.chest_point(),.235), &"lofted_pass", opposition[2].team_name, opposition[2])
		before = chest_controls
		actor.set_physics_process(true)
		for frame in 40: await physics_frame
		_check(chest_controls==before+1 and ball.last_touch==actor.team_name, "AI midfielder failed to intercept an opposing lofted pass with its chest")
		actor.set_physics_process(false)
		actor.reset_for_stoppage()
		ball.freeze = true
		actor.position = Vector3(0, 0, 90)
	for gap in contact_gaps: _check(gap <= .20, "Header was permitted outside physical forehead reach")
	for message in failures: push_error(message)
	print("AERIAL_CONTACT headers=", headers, " chest=", chest_controls, " gaps=", contact_gaps, " failures=", failures.size())
	game.free()
	quit(0 if failures.is_empty() else 1)
func _check(passed: bool, message: String) -> void:
	if not passed: failures.append(message)
