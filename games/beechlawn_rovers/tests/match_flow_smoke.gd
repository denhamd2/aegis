extends SceneTree
## Verifies center kickoff, goal pause, and conceded-team restart.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var scene := load("res://scenes/training_ground.tscn") as PackedScene
	assert(scene != null, "Sunday-league match scene failed to load")
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var ball := game.get_node("Ball") as FootballBall
	var player := game.get_node("Player") as FootballPlayer
	var home: Array = game.get("_home_players")
	var away: Array = game.get("_away_players")
	assert(bool(game.get("_kickoff_pending")), "Match did not wait for kickoff input")
	assert(ball.freeze, "Ball should be stationary before kickoff")
	assert(not player.is_physics_processing(), "Players should be held before kickoff")
	assert(absf(ball.global_position.x) < 0.01 and absf(ball.global_position.z) < 0.01,
		"Kickoff ball is not on the centre spot")
	for opponent in away:
		if opponent.profile.role == "outfield":
			assert(opponent.global_position.distance_to(Vector3.ZERO) >= 9.15,
				"Defender started inside the kickoff exclusion radius")

	Input.action_press("pass")
	await process_frame
	Input.action_release("pass")
	for frame in 30:
		await physics_frame
	assert(not bool(game.get("_kickoff_pending")), "Kickoff did not enter open play")
	assert(not ball.freeze, "Ball remained frozen after kickoff")
	assert(ball.last_touch == &"Beechlawn Rovers", "Human kickoff did not register the kicking team")
	assert(player.is_physics_processing(), "Player movement did not resume after kickoff")

	game._on_goal("Beechlawn Rovers", 1)
	assert(not ball.freeze, "Scored ball should continue physically into the net")
	assert(not player.is_physics_processing(), "Players should stop during the goal pause")
	assert(game.get("_kickoff_team") == &"Boardeaux", "Conceding team was not awarded the restart")
	game._physics_process(.5)
	assert(not ball.freeze and not game._kickoff_pending,"Goal follow-through must precede kickoff")
	var goal_skip := InputEventKey.new()
	goal_skip.keycode=KEY_SPACE;goal_skip.pressed=true
	game.presentation.handle_key(goal_skip)
	assert(bool(game.get("_kickoff_pending")), "Goal pause did not prepare a new kickoff")
	assert(ball.freeze, "Ball should remain still while AI lines up its kickoff")
	game._physics_process(1.1)
	assert(not bool(game.get("_kickoff_pending")), "Boardeaux did not restart after its short setup delay")
	for frame in 30:
		await physics_frame
	assert(ball.last_touch == &"Boardeaux", "AI kickoff did not register Boardeaux as the kicking team")
	assert(player.is_physics_processing(), "Players did not resume after the AI restart")
	print("Beechlawn kickoff and goal-restart checks passed")
	quit(0)
