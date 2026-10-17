extends SceneTree
## Checks 4v4 assembly, player switching, and low-rate opposition movement.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var packed := load("res://scenes/training_ground.tscn") as PackedScene
	assert(packed != null, "Sunday-league match scene failed to load")
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var actors := game.find_children("*", "FootballPlayer", true, false)
	assert(actors.size() == 8, "Expected four Beechlawn and four Bordeaux players")
	var home_players: Array = game.get("_home_players")
	var away_players: Array = game.get("_away_players")
	assert(home_players.size() == 4 and away_players.size() == 4, "Team arrays must assemble as 4v4")
	var controlled := game.get_node("Player") as FootballPlayer
	assert(controlled.controlled_by_human, "Beechlawn central outfielder should start human-controlled")
	assert(controlled.profile.player_id == &"david_murray", "Unexpected default controlled player profile")
	assert((controlled.get_node("ControlMarker") as MeshInstance3D).visible,
		"Controlled player marker should be visible")
	for opponent in away_players:
		assert(opponent.team_name == &"Bordeaux", "Away player is assigned to the wrong team")
		assert(not opponent.controlled_by_human, "Away players must remain AI controlled")
		assert(not (opponent.get_node("ControlMarker") as MeshInstance3D).visible,
			"AI players must not show the human control marker")
	game._start_kickoff(false)

	Input.action_press("switch_player")
	await process_frame
	await physics_frame
	Input.action_release("switch_player")
	var selected := game.get("player") as FootballPlayer
	assert(selected != controlled and selected.controlled_by_human,
		"Tab player switching did not select a different Beechlawn outfielder")
	assert((selected.get_node("ControlMarker") as MeshInstance3D).visible,
		"Player switching did not move the visual marker")
	assert(not (controlled.get_node("ControlMarker") as MeshInstance3D).visible,
		"Player switching left the old marker visible")

	var away_chaser: FootballPlayer = away_players[2]
	var starting_distance := away_chaser.global_position.distance_to(game.get_node("Ball").global_position)
	for _frame in 90:
		await physics_frame
	assert(away_chaser.global_position.distance_to(game.get_node("Ball").global_position) < starting_distance,
		"Nearest Bordeaux outfielder failed to close toward the ball")
	var ball := game.get_node("Ball") as FootballBall
	ball.global_position = Vector3(away_chaser.global_position.x, FootballBall.RADIUS,
		away_chaser.global_position.z)
	ball._dribble_cooldowns.clear()
	assert(ball.dribble_touch(away_chaser, Vector3.LEFT, false, true, 0.23, 0.48, 1.05),
		"Close opponent contact failed to produce a controlled touch")
	assert(ball.last_touch == &"Bordeaux", "Opponent contact did not update ball ownership")
	game.set("_remaining_time", 0.01)
	await process_frame
	await physics_frame
	assert(bool(game.get("_full_time")), "Short match clock failed to reach full time")
	assert((game.get_node("Ball") as FootballBall).freeze,
		"Ball should stop when the short match ends")
	print("Beechlawn 4v4 assembly and switching checks passed")
	quit(0)
