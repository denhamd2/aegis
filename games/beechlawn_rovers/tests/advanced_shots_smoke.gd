extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 64
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false); game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	for actor in game._home_players + game._away_players: actor.position = Vector3(0, 0, 90)
	var actor: FootballPlayer = game._home_players[2]
	var ball: FootballBall = game.ball
	actor.position = Vector3(32, .02, 6)
	var normal := ShotPlanner.plan(actor, .6, Vector3.RIGHT)
	var power := ShotPlanner.plan(actor, .6, Vector3.RIGHT, &"power")
	var low := ShotPlanner.plan(actor, .6, Vector3.RIGHT, &"low")
	var finesse := ShotPlanner.plan(actor, .6, Vector3.RIGHT, &"finesse")
	check(power.speed > normal.speed * 1.08, "Power shot is not meaningfully faster")
	check(low.lift < normal.lift * .3, "Low shot has an ordinary-shot loft")
	check(finesse.speed < normal.speed and finesse.spin.y > 0, "Finesse lacks its distinct speed/spin")
	var gentle := ShotPlanner.plan(actor, .1, Vector3.RIGHT)
	var hard := ShotPlanner.plan(actor, .9, Vector3.RIGHT)
	check(hard.speed > gentle.speed + 10, "Shot power does not vary with charge")
	for sx: float in [1.0, -1.0]:
		actor.attack_sign = sx
		actor.position = Vector3(15 * sx, .02, 6)
		var ends: Array[Vector3] = []
		for curved in [false, true]:
			ball.freeze = true; ball.release_for_restart()
			ball.position = Vector3(15.7 * sx, .2, 6)
			ball.linear_velocity = Vector3.ZERO; ball.angular_velocity = Vector3.ZERO
			await physics_frame
			ball.freeze = false
			ball.kick(Vector3(sx, 0, 0), 24, 3, &"shot", actor.team_name, actor,
				&"foot", &"finesse" if curved else &"standard", Vector3.UP * 30 * sx if curved else Vector3.ZERO)
			for frame in 36: await physics_frame
			ends.append(ball.position)
		check(ends[1].z < ends[0].z - .12, "Physical finesse curve absent for direction " + str(sx))
		check(ends[1].distance_to(ends[0]) < 3.0, "Finesse bends excessively")
		print("FINESSE_CURVE side=", sx, " deviation=", ends[1] - ends[0])
	ball.freeze = true; ball.release_for_restart()
	check(ball._curve_seconds == 0, "Stoppage retained curve assistance")
	# Authored markers and real toe reach still gate special ground strikes.
	for style: StringName in [&"power", &"low", &"finesse"]:
		actor.attack_sign = 1; actor.reset_for_stoppage()
		actor.position = Vector3(32, PitchSurface.height_at(32, 0) + .005, 0)
		actor.rotation.y = -PI / 2; actor._flat_direction = Vector3.RIGHT
		actor.controlled_by_human = false; actor.ai_move_direction = Vector3.ZERO
		ball.release_for_restart(); ball.position = actor.position + Vector3(.60, .13, 0)
		ball.linear_velocity = Vector3.ZERO; ball.angular_velocity = Vector3.ZERO
		await physics_frame
		ball.freeze = false
		var contacts: Array[Dictionary] = []
		var observe := func(kind: StringName, _speed: float):
			if kind == &"shot": contacts.append({"style": ball.last_strike_style, "gap": actor._receive_contact_position().distance_to(ball.position)})
		ball.touched.connect(observe)
		actor._do_shot(.6, 1, Vector3.RIGHT, style)
		actor.set_physics_process(true)
		for frame in 40: await physics_frame
		actor.set_physics_process(false)
		ball.touched.disconnect(observe)
		check(contacts.size() == 1 and contacts[0].style == style and contacts[0].gap <= .28, "Marker-gated special shot failed: " + str(style))
		ball.freeze = true
	for message in failures: push_error(message)
	print("ADVANCED_SHOTS failures=", failures.size())
	game.free(); quit(0 if failures.is_empty() else 1)
