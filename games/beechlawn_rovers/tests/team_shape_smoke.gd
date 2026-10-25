extends SceneTree
## Checks 4v4 support spacing and goal-side defensive recovery targets.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var scene := load("res://scenes/training_ground.tscn") as PackedScene
	assert(scene != null, "Sunday-league match scene failed to load")	
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game._start_kickoff(false)

	var ball := game.get_node("Ball") as FootballBall
	var home: Array = game.get("_home_players")
	var away: Array = game.get("_away_players")
	for actor in home + away:
		actor.set_physics_process(false)
		actor.receive_target_time = 0.0

	var carrier: FootballPlayer = game.get_node("Player")
	var left_support: FootballPlayer
	var right_support: FootballPlayer
	for actor in home:
		if actor.profile.starting_slot == "left":
			left_support = actor
		elif actor.profile.starting_slot == "right":
			right_support = actor
	assert(left_support != null and right_support != null, "Home wide support roles missing")
	carrier.global_position = Vector3.ZERO
	left_support.global_position = Vector3(-20.0, 0.0, -8.0)
	right_support.global_position = Vector3(-20.0, 0.0, 8.0)
	ball.last_touch = carrier.team_name
	game._update_team_ai(home, carrier, Vector2.ZERO, Vector2.ZERO)
	var left_target: Vector3 = left_support.get_meta("ai_target_position")
	var right_target: Vector3 = right_support.get_meta("ai_target_position")
	assert(left_target.z < -5.0 and right_target.z > 5.0,
		"Possession support collapsed the two wide lanes")
	assert(left_target.x > -20.0 and right_target.x > -20.0,
		"Wide support players did not advance with possession")

	# An AI carrier at the ball should push forward while its teammates fan out.
	left_support.global_position = Vector3(0.0, 0.0, 0.0)
	right_support.global_position = Vector3(-15.0, 0.0, 8.0)
	ball.last_touch = carrier.team_name
	game._update_team_ai(home, left_support, Vector2.ZERO, Vector2.ZERO)
	var carrier_target: Vector3 = left_support.get_meta("ai_target_position")
	assert(carrier_target.x > left_support.global_position.x + 2.0,
		"AI ball carrier did not choose a forward dribble target")

	# With Beechlawn in possession, Boardeaux's non-pressing defenders recover
	# behind the ball in their own attacking coordinate frame (goal-side).
	var away_chaser: FootballPlayer
	var away_defenders: Array[FootballPlayer] = []
	for actor in away:
		if actor.profile.role != "outfield":
			continue
		if away_chaser == null:
			away_chaser = actor
			actor.global_position = Vector3(10.0, 0.0, 0.0)
		else:
			away_defenders.append(actor)
			actor.global_position = Vector3(0.0, 0.0, -8.0 if away_defenders.size() == 1 else 8.0)
	assert(away_chaser != null and away_defenders.size() == 2, "Away defensive roles missing")
	var ball_position := Vector2(15.0, 0.0)
	ball.last_touch = carrier.team_name
	game._update_team_ai(away, away_chaser, ball_position, ball_position)
	for defender in away_defenders:
		var target: Vector3 = defender.get_meta("ai_target_position")
		assert(target.x > ball_position.x + 5.0,
			"Non-pressing defender failed to recover between the ball and own goal")

	print("Beechlawn team support and defensive shape checks passed")
	quit(0)
