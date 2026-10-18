extends SceneTree
## Isolated checks for dribble assistance, rolling range, shot power and aim.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var packed := load("res://scenes/training_ground.tscn") as PackedScene
	assert(packed != null, "Match scene failed to load for ball physics checks")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var ball := game.get_node("Ball") as FootballBall
	var player := game.get_node("Player") as FootballPlayer
	# This fixture isolates ball forces/power curves. Authored foot-contact timing
	# is covered by the separate pass/receive/shot integration checks.
	player.bind_footballer_visual(null)
	game.set_physics_process(false)
	for actor_node in game.get_tree().get_nodes_in_group("football_players"):
		var actor := actor_node as FootballPlayer
		actor.set_physics_process(false)
		actor.global_position = Vector3(300.0, 0.0, 300.0)
	player.global_position = Vector3.ZERO

	# The possession spring acts each physics frame, but touch notifications are
	# throttled. It must never snap the independent ball to a target transform.
	var touch_offsets: Dictionary[String, float] = {}
	for mode in ["close", "normal", "sprint"]:
		ball.freeze = true
		ball.global_position = player.global_position + Vector3(0.8, FootballBall.RADIUS, 0.0)
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.last_touch = &"none"
		ball.last_action = &"none"
		ball._dribble_cooldowns.clear()
		await physics_frame
		ball.freeze = false
		var initial_position := ball.global_position
		var initial_serial := ball.action_serial
		var close_control: bool = mode == "close"
		var sprinting: bool = mode == "sprint"
		ball.dribble_touch(player, Vector3.RIGHT, sprinting, close_control,
			player.tuning.dribble_touch_interval, player.tuning.close_touch_distance,
			player.tuning.sprint_touch_distance)
		assert(ball.global_position == initial_position, "Dribble assistance teleported the ball")
		for _frame in 9:
			ball.dribble_touch(player, Vector3.RIGHT, sprinting, close_control,
				player.tuning.dribble_touch_interval, player.tuning.close_touch_distance,
				player.tuning.sprint_touch_distance)
			await physics_frame
		touch_offsets[mode] = Vector2(ball.global_position.x - player.global_position.x,
			ball.global_position.z - player.global_position.z).length()
		assert(ball.action_serial == initial_serial + 1,
			"Dribble assistance emitted repeated touch events inside one cooldown")
	assert(touch_offsets["close"] < touch_offsets["normal"],
		"Close-control touch did not retain tighter ball spacing")
	assert(touch_offsets["normal"] < touch_offsets["sprint"],
		"Sprint touch did not push the ball farther ahead")
	assert(touch_offsets["close"] > 0.55 and touch_offsets["sprint"] < 1.35,
		"Dribble touch spacing escaped a playable foot-control range")
	print("Dribble spacing close/normal/sprint: %.2f / %.2f / %.2f m" % [
		touch_offsets["close"], touch_offsets["normal"], touch_offsets["sprint"]])

	# Measure ground-pass travel in the actual match collision/physics scene.
	# At 60 Hz, a 12 m/s pass should cover a useful midfield distance in 2 s;
	# softer and harder impulses must remain ordered.
	var distances: Array[float] = []
	for launch_speed in [6.0, 12.0, 18.0]:
		ball.freeze = true
		ball.global_position = Vector3.ZERO
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.last_touch = &"none"
		ball.last_action = &"none"
		await physics_frame
		ball.freeze = false
		ball.kick(Vector3.RIGHT, launch_speed, 0.0, &"pass", player.team_name)
		await physics_frame
		if distances.is_empty():
			assert(ball.angular_velocity.z < 0.0,
				"A +X ground pass did not receive forward-roll spin about -Z")
		var start := ball.global_position
		for _frame in 120:
			await physics_frame
		var distance := Vector2(ball.global_position.x - start.x,
			ball.global_position.z - start.z).length()
		distances.append(distance)
		print("Ball ground pass %.0f m/s: %.2f m in 2 s" % [launch_speed, distance])
	assert(distances[0] >= 6.0 and distances[0] <= 11.0,
		"Soft ground pass rolled outside the expected range")
	assert(distances[1] >= 15.0 and distances[1] <= 21.0,
		"12 m/s ground pass did not cover midfield distance")
	assert(distances[2] > distances[1] and distances[2] <= 34.0,
		"Hard ground pass did not travel farther with bounded range")

	# The charge curve must increase speed and the aim assist must preserve a
	# forward goal component when lateral keyboard aim is requested.
	var shot_speeds: Array[float] = []
	for charge in [0.0, 1.0]:
		ball.freeze = true
		ball.global_position = player.global_position + Vector3(0.5, FootballBall.RADIUS, 0.0)
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.last_touch = &"none"
		ball.last_action = &"none"
		await physics_frame
		ball.freeze = false
		player._aim = Vector2.ZERO
		player._do_shot(charge)
		await physics_frame
		shot_speeds.append(ball.linear_velocity.length())
	player._aim = Vector2(1.0, 0.0)
	ball.freeze = true
	ball.global_position = player.global_position + Vector3(0.5, FootballBall.RADIUS, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	await physics_frame
	ball.freeze = false
	player._do_shot(0.5)
	await physics_frame
	assert(shot_speeds[1] > shot_speeds[0] * 1.7,
		"A full-power shot did not meaningfully exceed a tap shot")
	assert(ball.linear_velocity.x > 0.0,
		"Lateral shot aim removed the attack-direction goal assistance")
	print("Shot speed tap/full: %.2f / %.2f m/s; lateral aim retained forward component %.2f m/s" % [
		shot_speeds[0], shot_speeds[1], ball.linear_velocity.x])

	print("Beechlawn ball fundamentals checks passed")
	quit(0)
