extends SceneTree
## Checks one-player pressure and distinct lane-aware marks on off-ball threats.

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

	var presser: FootballPlayer
	var left_defender: FootballPlayer
	var right_defender: FootballPlayer
	for actor in home:
		match actor.profile.starting_slot:
			"center":
				presser = actor
			"left":
				left_defender = actor
			"right":
				right_defender = actor
	assert(presser != null and left_defender != null and right_defender != null,
		"Beechlawn defensive roles missing")
	var away_left: FootballPlayer
	var away_center: FootballPlayer
	var away_right: FootballPlayer
	for actor in away:
		if actor.profile.role != "outfield":
			continue
		match actor.profile.starting_slot:
			"left":
				away_left = actor
			"center":
				away_center = actor
			"right":
				away_right = actor
	assert(away_left != null and away_center != null and away_right != null,
		"Boardeaux attacking roles missing")

	presser.controlled_by_human = false
	presser.global_position = Vector3(9.0, 0.0, 0.0)
	left_defender.global_position = Vector3(0.0, 0.0, -8.0)
	right_defender.global_position = Vector3(0.0, 0.0, 8.0)
	away_center.global_position = Vector3(10.0, 0.0, 0.0)
	away_left.global_position = Vector3(7.0, 0.0, -8.0)
	away_right.global_position = Vector3(7.0, 0.0, 8.0)
	var ball_position := Vector2(10.0, 0.0)
	ball.last_touch = away_center.team_name
	var assignments: Dictionary = game._assign_defensive_marks(home, presser, away, ball_position)
	assert(assignments.get(left_defender.get_instance_id()) == away_left,
		"Left defender did not select the attacker in its lane")
	assert(assignments.get(right_defender.get_instance_id()) == away_right,
		"Right defender did not select the attacker in its lane")
	assert(assignments.get(left_defender.get_instance_id()) != assignments.get(right_defender.get_instance_id()),
		"Two defenders collapsed onto one attacking threat")

	game._update_team_ai(home, presser, ball_position, ball_position, away)
	assert(String(presser.get_meta("ai_role_intent")) == "press",
		"Nearest defender was not assigned to pressure")
	assert(String(left_defender.get_meta("ai_role_intent")) == "mark"
		and String(right_defender.get_meta("ai_role_intent")) == "mark",
		"Off-ball defenders did not receive mark tasks")
	var left_target: Vector3 = left_defender.get_meta("ai_target_position")
	assert(left_target.distance_to(away_left.global_position) < 6.0,
		"Defender's assigned mark target was too far from its runner")
	assert(left_target.x < ball_position.x and right_defender.get_meta("assigned_mark") == away_right.profile.player_id,
		"Mark targets did not remain goal-side and lane-aware")

	print("Beechlawn defensive pressure and marking checks passed")
	quit(0)
