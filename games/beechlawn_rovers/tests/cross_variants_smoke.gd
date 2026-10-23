extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240; Engine.max_physics_steps_per_frame = 64
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game); await process_frame
	game.set_process(false); game.set_physics_process(false); game._set_players_physics_enabled(false)
	for node in game._home_players + game._away_players: node.position = Vector3(0, 0, 90)
	var ball: FootballBall = game.ball
	for sx: float in [1.0, -1.0]:
		var team: Array[FootballPlayer] = game._home_players if sx > 0 else game._away_players
		var actor: FootballPlayer = team[2]
		var receiver: FootballPlayer = team[3]
		actor.position = Vector3(33 * sx, 0, 21); receiver.position = Vector3(42 * sx, 0, 2)
		ball.freeze = true; ball.release_for_restart(); ball.position = actor.position + Vector3(.3 * sx, .13, -.5)
		var direction := receiver.position - ball.position
		var options := {}
		for variant: StringName in [&"standard", &"driven_cross", &"lofted_cross", &"early_cross"]:
			receiver.position = Vector3(42 * sx, 0, 2)
			ball.position = actor.position + Vector3(.3 * sx, .13, -.5)
			var plan := LoftedPassPlanner.plan(actor, &"cross", direction, .75, receiver, variant)
			check(not plan.is_empty(), "Cross variant has no legal launch: " + str(variant))
			if plan.is_empty(): continue
			options[variant] = plan
			receiver.position = Vector3(0, 0, 90) # Isolate free flight from receiving collisions.
			ball.position = actor.position + Vector3(.3 * sx, .13, -.5)
			ball.linear_velocity = Vector3.ZERO; ball.angular_velocity = Vector3.ZERO
			await physics_frame; ball.freeze = false
			ball.kick_velocity(plan.velocity, &"cross", actor.team_name, actor, &"foot", variant)
			var peak := ball.position.y
			for frame in roundi(plan.flight_seconds * 60):
				await physics_frame; peak = maxf(peak, ball.position.y)
			var error := ball.position.distance_to(plan.position)
			check(error < .45, "Physical cross missed its flight target: " + str(variant) + " error=" + str(error))
			options[variant]["peak"] = peak
			print("CROSS_VARIANT side=", sx, " variant=", variant, " time=", plan.flight_seconds, " peak=", peak, " error=", error)
			ball.freeze = true; ball.release_for_restart()
		if options.size() != 4: continue
		check(options.driven_cross.flight_seconds < options.standard.flight_seconds and options.driven_cross.peak < options.standard.peak, "Driven cross is not faster/lower")
		check(options.lofted_cross.flight_seconds > options.standard.flight_seconds and options.lofted_cross.peak > options.standard.peak + 1.0, "Lofted cross has no distinct arc")
		check(options.early_cross.position.x * sx > options.standard.position.x * sx + 1.0, "Early cross fails to lead the run")
		actor.position = Vector3(0, 0, 90); receiver.position = Vector3(0, 0, 90)
	for message in failures: push_error(message)
	print("CROSS_VARIANTS failures=", failures.size())
	game.free(); quit(0 if failures.is_empty() else 1)
