extends SceneTree
var use_left := OS.get_environment("BEECHLAWN_STRIKE_FOOT")=="left"
## A released shot command must survive a friendly incoming pass, with no trap.
var failures: Array[String] = []
var shots := 0
var receipts := 0
var contact_gap := INF

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for actor in game._home_players + game._away_players:
		actor.set_physics_process(false)
		actor.global_position = Vector3(-45, 0, 30)
	var player := game.get_node("Player") as FootballPlayer
	var visual := player.get_node("Visual") as FootballerVisual
	var ball := game.get_node("Ball") as FootballBall
	player.global_position = Vector3(10, 0, 0)
	player.rotation.y = -PI / 2.0
	player._flat_direction = Vector3.RIGHT
	player.controlled_by_human = true
	player.receive_target_time = 1.0
	player.set_physics_process(true)
	ball.freeze = false
	ball.global_position = Vector3(16, 0.13, -.14 if use_left else 0.0)
	ball.linear_velocity = Vector3.LEFT * 12.0
	ball.last_touch = player.team_name
	ball.last_action = &"pass"
	ball.action_serial += 1
	ball.touched.connect(func(kind: StringName, _speed: float):
		if kind == &"shot":
			shots += 1
			contact_gap = player._receive_contact_position().distance_to(ball.global_position)
			if visual.strike_foot()!=(&"left" if use_left else &"right"): failures.append("Wrong first-time strike boot")
		if kind == &"receive": receipts += 1)
	Input.action_press("shoot")
	for tick in 3: await physics_frame
	Input.action_release("shoot")
	for tick in 65:
		await physics_frame
		if shots > 0: break
	if shots != 1 or receipts != 0 or contact_gap > 0.30:
		failures.append("Buffered first-time shot: shots=%d traps=%d contact_gap=%.3f" % [shots, receipts, contact_gap])
	player.set_physics_process(false)
	visual.animation_player.stop()
	visual._active_action = &""
	if not visual.play_receive() or not visual.play_shot():
		failures.append("A first-time shot could not interrupt receive settle")
	visual.animation_player.stop()
	visual._active_action = &""
	visual.play_pass()
	visual.on_action_contact_marker()
	if not visual.play_shot():
		failures.append("Completed pass contact left the follow-through blocking the next shot")
	visual.animation_player.stop()
	visual._active_action = &""
	visual.play_pass()
	visual.on_action_contact_marker()
	ball.freeze = true
	ball.global_position = player.global_position + Vector3(0.65, 0.13, 0)
	player._do_pass(false, Vector3.RIGHT)
	if not player._visual_pass_pending:
		failures.append("Starting a second pass during follow-through erased its pending contact")
	for message in failures: push_error(message)
	print("FIRST_TIME_SHOT shots=", shots, " traps=", receipts,
		" toe_gap_m=", snappedf(contact_gap, 0.001), " failures=", failures.size())
	game.free()
	quit(0 if failures.is_empty() else 1)
