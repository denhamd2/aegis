extends SceneTree
## Real independent-ball flights, bounded targeting and marker-gated launches.
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
	ball.use_terrain = false
	for actor in game._home_players + game._away_players:
		actor.position = Vector3(0, 0, 90)
		actor.controlled_by_human = false
	for sx: float in [1.0, -1.0]:
		for distance: float in [12.0, 28.0, 40.0]:
			ball.freeze = true
			ball.release_for_restart()
			ball.position = Vector3(-20 * sx, .23, 14)
			await physics_frame
			var target := ball.position + Vector3(distance * sx, 0, -5)
			var seconds := .9 + distance / 25.0
			var start := ball.position
			var velocity := FootballBallFlight.launch(ball, target, seconds)
			ball.freeze = false
			_check(ball.kick_velocity(velocity, &"lofted_pass", &"Beechlawn Rovers", null), "Air launch rejected")
			_check(ball.position.distance_to(start) < .001, "Air strike moved ball position")
			var peak := ball.position.y
			for step in roundi(seconds * 60.0):
				await physics_frame
				peak = maxf(peak, ball.position.y)
			var gap := Vector2(ball.position.x - target.x, ball.position.z - target.z).length()
			_check(gap < .8 and peak > 1.3, "Physical flight missed its target or stayed on the grass")
			print("AERIAL_FLIGHT side=", sx, " metres=", distance, " landing_gap=", gap, " peak=", peak)
		ball.freeze = true
		ball.release_for_restart()
		var players: Array[FootballPlayer] = game._home_players if sx > 0 else game._away_players
		var passer: FootballPlayer
		var receiver: FootballPlayer
		for candidate in players:
			if candidate.profile.starting_slot == "winger_left": passer = candidate
			if candidate.profile.starting_slot == "striker_left": receiver = candidate
		if passer == null: passer = players[2]
		passer.position = Vector3(32 * sx, 0, 20)
		passer.rotation.y = -PI / 2 * sx
		receiver.position = Vector3(42 * sx, 0, 2)
		receiver.velocity = Vector3(2 * sx, 0, 0)
		ball.position = passer.position + Vector3(.6 * sx, .13, 0)
		var option := LoftedPassPlanner.plan(passer, &"cross", receiver.position - passer.position, .72, receiver)
		_check(not option.is_empty() and option.receiver == receiver and option.position.x * sx > 42
			and option.position.y > 1.8, "Cross did not lead the intended attacker at heading height")
		var backwards := LoftedPassPlanner.plan(passer, &"cross", Vector3(-sx, 0, 0), .72, receiver)
		_check(backwards.is_empty(), "Cross assistance redirected opposite the requested aim")
		var decision: Dictionary = game._player_decisions.choose_carrier_action(passer, players,
			game._away_players if sx > 0 else game._home_players, ball)
		ball.last_touch = passer.team_name
		passer.ai_action_cooldown = 0
		decision = game._player_decisions.choose_carrier_action(passer, players,
			game._away_players if sx > 0 else game._home_players, ball)
		_check(decision.get("type") == &"cross", "Wide AI did not choose a cross to an available attacker")
		var serial := ball.action_serial
		passer._do_pass(false, receiver.position - passer.position, false, 1, receiver, &"cross", .72)
		_check(passer._visual_pass_pending and ball.action_serial == serial, "Cross was not gated by the foot animation")
		for step in 46: await physics_frame
		_check(ball.action_serial > serial and ball.last_action == &"cross", "Authored foot contact failed to release a cross")
		_check(receiver.receive_target_time > 0 and receiver.receive_target_kind == &"cross", "Cross recipient did not get an aerial run")
		passer.position = Vector3.ZERO
		passer.ai_action_cooldown = 0
		receiver.position = Vector3(20 * sx, 0, 0)
		var opponents: Array[FootballPlayer] = game._away_players if sx > 0 else game._home_players
		var blocker: FootballPlayer = opponents[2]
		blocker.position = Vector3(2 * sx, 0, 0)
		ball.position = Vector3(.6 * sx, .13, 0)
		ball.last_touch = passer.team_name
		decision = game._player_decisions.choose_carrier_action(passer, players, opponents, ball)
		_check(decision.get("type") == &"lofted_pass", "AI did not lift over a blocked ground lane")
		blocker.position = Vector3(0, 0, 90)
		passer.position = Vector3(0, 0, 90)
		receiver.position = Vector3(0, 0, 90)
	for message in failures: push_error(message)
	print("AERIAL_FLIGHT failures=", failures.size())
	game.free()
	quit(0 if failures.is_empty() else 1)
func _check(passed: bool, message: String) -> void:
	if not passed: failures.append(message)
