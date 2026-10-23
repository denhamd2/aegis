extends SceneTree
## Wing delivery -> AI run -> forehead contact, including an actual close defender.
var failures: Array[String] = []
var contacts: Array[Dictionary] = []
var variant: StringName = &"standard"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	variant = StringName(OS.get_environment("BEECHLAWN_CROSS_VARIANT")) if not OS.get_environment("BEECHLAWN_CROSS_VARIANT").is_empty() else &"standard"
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 64
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._kickoff_pending = false
	game._set_players_physics_enabled(false)
	var ball: FootballBall = game.ball
	ball.touched.connect(func(kind: StringName, _speed: float):
		if kind in [&"cross", &"aerial_control"] or ball.last_strike_part == &"head" or (kind == &"shot" and ball.last_strike_style in [&"volley", &"half_volley"]):
			var gap := INF
			for other in game._home_players + game._away_players:
				if other.team_name != ball.last_touch and other.profile.role == "outfield":
					gap = minf(gap, other.position.distance_to(ball.position))
			contacts.append({"kind":kind,"part":ball.last_strike_part,"style":ball.last_strike_style,"team":ball.last_touch,"opponent_gap":gap,"tick":Engine.get_physics_frames()}))
	for sx: float in [1.0, -1.0]:
		for contested: bool in ([false] if variant == &"driven_cross" else [false, true]):
			game._set_players_physics_enabled(false)
			for actor in game._home_players + game._away_players:
				actor.reset_for_stoppage()
				actor.position = Vector3(140, 0, 140)
				actor.controlled_by_human = false
			ball.freeze = true
			ball.release_for_restart()
			var team: Array[FootballPlayer] = game._home_players if sx > 0 else game._away_players
			var opponents: Array[FootballPlayer] = game._away_players if sx > 0 else game._home_players
			var passer: FootballPlayer = team[2]
			var receiver: FootballPlayer
			for actor in team:
				if actor.profile.starting_slot == "striker_left": receiver = actor
			var defender: FootballPlayer = opponents[2]
			passer.position = Vector3(33 * sx, PitchSurface.height_at(33 * sx, 21) + .005, 21)
			passer.rotation.y = atan2(21.0, 9.0 * -sx)
			receiver.position = Vector3(42 * sx, PitchSurface.height_at(42 * sx, 2) + .005, 2)
			receiver.rotation.y = -PI / 2 * sx
			if contested:
				defender.position = Vector3(44 * sx, PitchSurface.height_at(44 * sx, 2.9) + .005, 2.9)
				# A wide presser prevents the central marker chasing the winger
				# during wind-up; once airborne the central player contests it.
				var wide_presser: FootballPlayer = opponents[3]
				wide_presser.position = passer.position + Vector3(sx, 0, 1.8)
				defender.rotation.y = PI / 2 * sx
				defender.set_meta("ai_role_intent", "press")
				defender.set_physics_process(true)
			var toward := receiver.position - passer.position
			toward.y = 0
			passer.rotation.y = atan2(-toward.x, -toward.z)
			ball.position = passer.position + toward.normalized() * .6 + Vector3.UP * .13
			ball.last_touch = passer.team_name
			ball.last_action = &"dribble"
			ball.last_touch_player = passer
			ball.action_serial += 1
			await physics_frame
			ball.freeze = false
			receiver.set_physics_process(true)
			var before := contacts.size()
			passer._do_pass(false, toward, false, 1, receiver, &"cross", .72, variant)
			for frame in 155:
				if frame % 12 == 0:
					game._update_ai(.2)
				await physics_frame
			var cross_count := 0
			var head_count := 0
			var close_contest := false
			for event in contacts.slice(before):
				if event.kind == &"cross": cross_count += 1
				if event.part == &"head" or (variant == &"driven_cross" and event.style == &"volley"):
					head_count += 1
					if event.opponent_gap < 2.5: close_contest = true
			_check(cross_count == 1, "Cross did not leave the actual animated boot")
			_check(head_count >= 1, "Cross produced no expected aerial reception; side=" + str(sx) + " contested=" + str(contested))
			if contested: _check(close_contest, "Contested fixture had no opponent near the actual header")
			print("CROSS_RECEPTION variant=",variant," side=",sx," contested=",contested," contacts=",contacts.slice(before)," receiver=",receiver.position," ball=",ball.position)
			ball.freeze = true
	for message in failures: push_error(message)
	print("CROSS_HEADER failures=",failures.size())
	game.free()
	quit(0 if failures.is_empty() else 1)
func _check(passed: bool, message: String) -> void:
	if not passed: failures.append(message)
