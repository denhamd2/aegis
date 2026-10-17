extends SceneTree
## Checks score/clock-aware pressing and late-lead defensive depth.

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
		actor.controlled_by_human = false

	var chaser: FootballPlayer = game.get_node("Player")
	var left: FootballPlayer
	var right: FootballPlayer
	for actor in home:
		if actor.profile.starting_slot == "left":
			left = actor
		elif actor.profile.starting_slot == "right":
			right = actor
	assert(left != null and right != null, "Home wide defenders missing")
	chaser.global_position = Vector3(9.0, 0.0, 0.0)
	left.global_position = Vector3(0.0, 0.0, -8.0)
	right.global_position = Vector3(0.0, 0.0, 8.0)
	var ball_position := Vector2(10.0, 0.0)
	ball.global_position = Vector3(ball_position.x, FootballBall.RADIUS, ball_position.y)
	ball.last_touch = &"Bordeaux"
	game.set("_remaining_time", 20.0)
	game.set("_home_score", 0)
	game.set("_away_score", 1)
	game._update_team_ai(home, chaser, ball_position, ball_position, away)
	assert(String(chaser.get_meta("ai_role_intent")) == "press",
		"Primary defender did not pressure the ball")
	assert(String(left.get_meta("ai_role_intent")) == "second_press"
		or String(right.get_meta("ai_role_intent")) == "second_press",
		"Trailing team did not add a second presser late in the match")
	assert(String(left.get_meta("ai_role_intent")) == "mark"
		or String(right.get_meta("ai_role_intent")) == "mark",
		"High press did not preserve a covering marker")

	# A trailing team does not send the second presser when play is in its own half.
	ball_position = Vector2(-10.0, 0.0)
	game._update_team_ai(home, chaser, ball_position, ball_position, away)
	assert(String(chaser.get_meta("ai_role_intent")) == "press"
		and String(left.get_meta("ai_role_intent")) != "second_press"
		and String(right.get_meta("ai_role_intent")) != "second_press",
		"High press triggered in the wrong field zone")

	# A late lead moves the defensive line deeper than its neutral-time target.
	game.set("_home_score", 2)
	game.set("_away_score", 1)
	game.set("_remaining_time", 20.0)
	var leading_target: Vector2 = game._defensive_shape_position(left, Vector2(10.0, 0.0))
	game.set("_remaining_time", 90.0)
	var neutral_target: Vector2 = game._defensive_shape_position(left, Vector2(10.0, 0.0))
	assert(leading_target.x < neutral_target.x,
		"Late-leading team did not drop its defensive line")
	game.set("_remaining_time", 20.0)
	game._update_team_ai(home, chaser, Vector2(10.0, 0.0), Vector2(10.0, 0.0), away)
	assert(String(left.get_meta("ai_role_intent")) != "second_press"
		and String(right.get_meta("ai_role_intent")) != "second_press",
		"Late-leading team still used a high press")

	print("Beechlawn tactical context checks passed")
	quit(0)
