extends SceneTree
## Headless regression checks for the playable first milestone.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var packed := load("res://scenes/training_ground.tscn") as PackedScene
	assert(packed != null, "Sunday-league match scene failed to load")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game._start_kickoff(false)

	var ball := game.get_node("Ball") as FootballBall
	var player := game.get_node("Player") as FootballPlayer
	var visual := player.get_node("Visual") as FootballerVisual
	var ball_visual := game.get_node("Ball/BallVisual") as Node3D
	var ball_bounds := _mesh_bounds(ball_visual, ball_visual)
	assert(absf(ball_bounds.size.x - 0.22) < 0.015, "Imported worn ball visual is not regulation diameter")
	assert(absf(ball_bounds.size.y - 0.22) < 0.015, "Imported worn ball visual is not spherical")
	assert(ball_visual.find_children("*", "MeshInstance3D", true, false).size() == 1,
		"Match ball should render one ball mesh, without a duplicate fallback model")
	var ball_collision := game.get_node("Ball/CollisionShape3D") as CollisionShape3D
	assert(ball_collision.shape is SphereShape3D, "Ball collision must remain a lightweight sphere")
	assert(absf((ball_collision.shape as SphereShape3D).radius - FootballBall.RADIUS) < 0.001,
		"Ball collision radius no longer matches gameplay tuning")
	var detector := game.get_node("Goals/PositiveEnd/GoalDetector") as GoalDetector
	var result := {"goals": 0}
	detector.goal_scored.connect(func(_team: String, _side: int) -> void: result["goals"] += 1)
	var goal_visual := game.get_node("Goals/PositiveEnd/BlenderGoalModel") as Node3D
	var goal_size := _mesh_bounds(goal_visual, goal_visual).size
	assert(absf(goal_size.y - 2.56) < 0.08, "Blender goal height import/axis conversion is incorrect")
	assert(absf(goal_size.x - 7.56) < 0.10, "Blender goal opening-width geometry is incorrect")
	# The authored sagging mesh extends behind the 1.8 m gameplay net collider.
	assert(absf(goal_size.z - 2.0) < 0.1 and is_equal_approx(game.venue.goal.depth, 1.8),
		"Park-goal visual/collider depths no longer match the current source")

	# Check the complete ball crosses the line even when it moves several metres
	# between physics samples. This reproduces the high-speed Area miss case.
	ball.freeze = true
	ball.global_position = Vector3(51.8, FootballBall.RADIUS + 0.02, 0.0)
	await physics_frame
	ball.global_position = Vector3(53.2, FootballBall.RADIUS + 0.02, 0.0)
	await physics_frame
	assert(result["goals"] == 1, "A valid full-ball goal-line crossing was missed")

	# A ball above the crossbar must not count.
	await create_timer(1.8).timeout
	ball.global_position = Vector3(51.8, GOAL_HEIGHT + FootballBall.RADIUS + 0.2, 0.0)
	await physics_frame
	ball.global_position = Vector3(53.2, GOAL_HEIGHT + FootballBall.RADIUS + 0.2, 0.0)
	await physics_frame
	assert(result["goals"] == 1, "A shot above the crossbar counted as a goal")
	game._goal_pause_timer = 0.0
	game._prepare_kickoff(&"Beechlawn Rovers")
	game._start_kickoff(false)

	# A pass input just before the ball enters contact range should be buffered,
	# but a ball beyond the contact-assist radius must not be kicked remotely.
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.global_position = player.global_position + Vector3(1.30, FootballBall.RADIUS, 0.0)
	await physics_frame
	assert(not player._can_kick(), "Kick assistance reached too far from the player")
	player._queue_pass(false)
	assert(player._pending_pass > 0.0, "Pass action did not enter its input buffer")
	ball.global_position = player.global_position + Vector3(0.98, FootballBall.RADIUS, 0.0)
	assert(player._can_kick(), "Ball entering the contact window was not kickable")
	ball.freeze = false
	for _frame in 2:
		await physics_frame
	assert(player.get("_visual_pass_pending"),
		"Buffered pass did not begin its contact-timed animation")
	# Buffer eligibility uses root reach; execution still needs the real boot.
	visual.animation_player.seek(visual.action_contact_time(&"pass"), true)
	ball.global_position = player._receive_contact_position() + Vector3.UP * 0.06
	visual.on_action_contact_marker()
	await physics_frame
	assert(ball.linear_velocity.length() > player.tuning.short_pass_speed * 0.7,
		"Buffered pass did not apply a playable ball impulse")
	for _frame in 60:
		await physics_frame
	# A completed pass may transfer human control to its receiver.
	player = game.player
	visual = player.get_node("Visual") as FootballerVisual

	# A quick shot tap receives the same short contact buffer and remains a
	# grounded strike when the authored foot reaches the contact window.
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position = player.global_position + Vector3(1.30, FootballBall.RADIUS, 0.0)
	await physics_frame
	Input.action_press("shoot")
	await physics_frame
	Input.action_release("shoot")
	ball.global_position = player.global_position + Vector3(0.65, FootballBall.RADIUS, 0.0)
	ball.freeze = false
	for _frame in 2:
		await physics_frame
	assert(player.get("_visual_shot_pending"),
		"Buffered shot did not start its authored contact animation")
	var shot_serial := ball.action_serial
	for _frame in 22:
		await physics_frame
	assert(ball.action_serial > shot_serial and ball.last_action == &"shot",
		"Buffered shot did not apply its impulse at the authored contact marker (serial=%d start=%d action=%s pending=%s clip=%s time=%.3f)" % [
			ball.action_serial, shot_serial, String(ball.last_action), str(player.get("_visual_shot_pending")),
			player.get_node("Visual/Rig/AnimationPlayer").current_animation,
			player.get_node("Visual/Rig/AnimationPlayer").current_animation_position])
	assert(ball.linear_velocity.length() > player.tuning.shot_min_speed * 0.7,
		"Buffered shot did not apply a playable ball impulse")

	# Camera-relative keyboard input should move the controlled player.
	ball.freeze = false
	var initial := player.global_position
	Input.action_press("move_right")
	for _frame in 30:
		await physics_frame
	Input.action_release("move_right")
	assert(player.global_position.distance_to(initial) > 0.35, "Player movement input did not move the player")
	assert(ball.get_parent() == game, "Ball must remain an independent rigid body")

	print("Beechlawn Milestone 1 smoke checks passed")
	quit(0)

const GOAL_HEIGHT := 2.44

func _mesh_bounds(node: Node3D, space: Node3D) -> AABB:
	var has_point := false
	var bounds := AABB()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var local_bounds := mesh_instance.get_aabb()
		for corner_index in 8:
			var corner := Vector3(
				local_bounds.position.x + (local_bounds.size.x if corner_index & 1 else 0.0),
				local_bounds.position.y + (local_bounds.size.y if corner_index & 2 else 0.0),
				local_bounds.position.z + (local_bounds.size.z if corner_index & 4 else 0.0))
			var point := space.to_local(mesh_instance.to_global(corner))
			if not has_point:
				bounds = AABB(point, Vector3.ZERO)
				has_point = true
			else:
				bounds = bounds.expand(point)
	return bounds
