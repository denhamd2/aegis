extends SceneTree
## Misses, interruptions, collision cleanup and caller-order-neutral head contests.
var failures: Array[String] = []
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
	var home: FootballPlayer = game._home_players[2]
	var away: FootballPlayer = game._away_players[2]
	for sx: float in [1.0, -1.0]:
		var actor := home if sx > 0 else away
		actor.reset_for_stoppage()
		actor.controlled_by_human = true
		actor.position = Vector3(32*sx, PitchSurface.height_at(32*sx,0)+.005, 0)
		actor.rotation.y = -PI/2*sx
		ball.freeze = true
		ball.release_for_restart()
		ball.position = actor.position + Vector3(2.5*sx,2.2,0)
		await physics_frame
		ball.freeze = false
		ball.kick_velocity(FootballBallFlight.launch(ball, actor.position+Vector3(1.0*sx,1.97,0),.31), &"cross", actor.team_name, null)
		actor._aerial_controller.request_header(Vector3(sx,0,0))
		actor.set_physics_process(true)
		var initial_y := actor.position.y
		for frame in 45: await physics_frame
		_check(ball.last_strike_part != &"head" and absf(actor.position.y-initial_y)<.08,
			"Distant forehead target caused a remote header/jump")
		actor.set_physics_process(false)
		actor.reset_for_stoppage()
		ball.freeze = true
		ball.release_for_restart()
		ball.position = actor.position + Vector3(2.5*sx,2.2,0)
		await physics_frame
		ball.freeze = false
		ball.kick_velocity(FootballBallFlight.launch(ball, actor.position+Vector3(.14*sx,1.97,0),.31), &"cross", actor.team_name, null)
		actor._aerial_controller.request_header(Vector3(sx,0,0))
		actor.set_physics_process(true)
		for frame in 16: await physics_frame
		_check(actor in ball.get_collision_exceptions(), "Valid contact did not enter the narrow capsule exception")
		var location := ball.position
		actor.reset_for_stoppage()
		_check(actor not in ball.get_collision_exceptions() and not actor._aerial_controller.committed(), "Stoppage leaked aerial state/collision exception")
		_check(ball.position.distance_to(location)<.001, "Cancelling an aerial action moved the ball")
		for frame in 40: await physics_frame
		_check(ball.last_strike_part != &"head", "Cancelled aerial action emitted a stale header")
		actor.set_physics_process(false)
		actor.position = Vector3(0,0,90)
	# Evaluate both actual imported rigs at the authored marker. A real reach
	# gets one winner; an equal-looking pose outside reach gets no impulse.
	for equal: bool in [true,false]:
		for reverse: bool in [false,true]:
			ball.freeze = true
			ball.release_for_restart()
			for actor in [home,away]:
				actor.reset_for_stoppage()
				actor.position = Vector3(32 if actor==home else 32.72,.22,0)
				actor.rotation.y = -PI/2 if actor==home else PI/2
				actor._footballer_visual.play_aerial(&"header")
				actor._footballer_visual.animation_player.seek(.3,true,true)
				actor._aerial_controller._active = &"header"
				actor._aerial_controller._elapsed = .3
				actor._aerial_controller._contact_seconds = .3
				actor._aerial_controller._header_aim = Vector3.RIGHT if actor==home else Vector3.LEFT
			ball.position = (home._aerial_controller.forehead_point()+away._aerial_controller.forehead_point())*.5
			if not equal:ball.position.x -= .075
			ball.last_touch = &"none"
			ball.last_touch_player = null
			ball.last_action = &"cross"
			ball.last_strike_part = &"foot"
			ball.action_serial += 1
			var serial := ball.action_serial
			for actor in [home,away]:
				actor._aerial_controller._serial = serial
				actor._aerial_controller._incoming_kind = &"cross"
			var expected := FootballAerialContest.winner(ball)
			for actor in ([away,home] if reverse else [home,away]):
				actor._footballer_visual.on_action_contact_marker()
			if equal:
				_check(ball.action_serial==serial+(0 if expected==null else 1), "Equal aerial reaches used caller order or forced a miss")
				if expected!=null: _check(ball.last_touch_player==expected, "Equal reach ignored the selected winner")
			else:
				_check(expected==home and ball.action_serial==serial+1 and ball.last_touch_player==home and ball.last_strike_part==&"head",
					"Closest valid forehead lost the contest or produced duplicate impulses")
	for message in failures:push_error(message)
	print("AERIAL_SAFETY failures=",failures.size())
	game.free()
	quit(0 if failures.is_empty() else 1)
func _check(passed: bool,message: String) -> void:
	if not passed:failures.append(message)
