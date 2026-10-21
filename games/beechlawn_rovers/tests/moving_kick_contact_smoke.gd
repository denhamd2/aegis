extends SceneTree
## Real shared footballer, live rigid ball and moving marker-gated contacts.
var failures: Array[String] = []
var contact_gap := INF
var contacts := 0
var kicks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for human in [false, true]:
		for kind in [&"pass", &"shot"]:
			for speed in [0.0, 6.0, 8.6]:
				await _case(kind, speed, human)
	await _case(&"shot", 0.0, true, true)
	for message in failures:
		push_error(message)
	print("MOVING_CONTACT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

func _case(kind: StringName, speed: float, human := false, off_axis := false) -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for actor in game._home_players + game._away_players:
		actor.set_physics_process(false)
		actor.global_position = Vector3(-45.0, 0.0, 30.0)
	var player := game.get_node("Player") as FootballPlayer
	var ball := game.get_node("Ball") as FootballBall
	var visual := player.get_node("Visual") as FootballerVisual
	player.controlled_by_human = human
	player.global_position = Vector3(10.0, 0.0, 0.0)
	player.rotation.y = -PI / 2.0
	player._flat_direction = Vector3.RIGHT
	player.velocity = Vector3.RIGHT * speed
	player.ai_move_direction = Vector3.RIGHT if speed > 0.0 else Vector3.ZERO
	player.ai_sprinting = speed > player.tuning.jog_speed
	# This fixture travels world-right; choose the matching screen direction
	# so it also exercises the opposite-touchline broadcast orientation.
	var move_action: StringName = &"move_right" if player.camera.global_basis.x.x > 0.0 else &"move_left"
	if human and speed > 0.0: Input.action_press(move_action)
	if human and speed > player.tuning.jog_speed: Input.action_press("sprint")
	ball.global_position = player.global_position + (Vector3(0, 0.13, 0.95) if off_axis else Vector3(0.65, 0.13, 0.0))
	ball.linear_velocity = Vector3.RIGHT * speed
	ball.last_touch = player.team_name
	ball.last_action = &"dribble"
	ball.freeze = false
	contact_gap = INF
	contacts = 0
	kicks = 0
	visual.action_contact.connect(func(action: StringName):
		if action == kind:
			contacts += 1
			contact_gap = player._receive_contact_position().distance_to(ball.global_position))
	ball.touched.connect(func(action: StringName, _power: float):
		if action == kind: kicks += 1)
	player.set_physics_process(true)
	if kind == &"pass": player._do_pass(false, Vector3.RIGHT)
	else: player._do_shot(0.55)
	for tick in 70:
		await physics_frame
		if contacts > 0 and not off_axis: break
	print("MOVING_CONTACT kind=", kind, " speed=", speed,
		" human=", human, " off_axis=", off_axis, " markers=", contacts, " impulses=", kicks, " toe_gap_m=", snappedf(contact_gap, 0.001))
	if off_axis and kicks != 0:
		failures.append("A stationary kick struck a ball beside the player, outside the actual foot window")
	elif not off_axis and (contacts != 1 or kicks != 1 or contact_gap > 0.30):
		failures.append("%s at %.1f m/s: expected one close physical contact; markers=%d kicks=%d gap=%.3f" % [kind, speed, contacts, kicks, contact_gap])
	Input.action_release(move_action)
	Input.action_release("sprint")
	game.free()
	await process_frame
