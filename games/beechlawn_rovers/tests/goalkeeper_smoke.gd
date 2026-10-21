extends SceneTree
## Verifies keeper shot reads, bounded positioning and physical close-contact saves.

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
	var home_keeper: FootballPlayer
	for actor in home:
		actor.set_physics_process(false)
		if actor.profile.role == "goalkeeper":
			home_keeper = actor
	assert(home_keeper != null and home_keeper._goalkeeper_controller != null,
		"Beechlawn goalkeeper controller was not initialized")
	assert(home_keeper.profile.role == "goalkeeper", "Keeper role was not preserved")
	home_keeper.controlled_by_human = false
	var controller := home_keeper._goalkeeper_controller

	# A goal-bound shot triggers a predictive lateral target after its reaction delay.
	home_keeper.global_position = Vector3(-49.5, 0.0, 0.0)
	ball.global_position = Vector3(-43.5, 1.2, 2.0)
	ball.linear_velocity = Vector3(-12.0, 0.0, 0.8)
	ball.last_touch = &"Bordeaux"
	ball.last_action = &"shot"
	ball.action_serial += 1
	var original_position := home_keeper.global_position
	controller.update_before_move(0.35)
	assert(home_keeper.global_position == original_position,
		"Goalkeeper teleported instead of receiving a movement target")
	var shot_target: Vector3 = home_keeper.get_meta("goalkeeper_target")
	assert(shot_target.z > 1.0, "Goalkeeper did not track the predicted shot lane")
	assert(home_keeper.ai_move_direction.length_squared() > 0.01,
		"Goalkeeper did not move toward a reachable shot")

	# Shots projected outside the frame retain the standard goal-centre position.
	ball.global_position = Vector3(-43.5, 1.2, 8.0)
	ball.linear_velocity = Vector3(-12.0, 0.0, 0.0)
	ball.last_touch = &"Bordeaux"
	ball.last_action = &"shot"
	ball.action_serial += 1
	controller.update_before_move(0.35)
	var wide_target: Vector3 = home_keeper.get_meta("goalkeeper_target")
	assert(is_equal_approx(wide_target.z, controller._goal_line_position().z),
		"Keeper chased a shot projected outside the goal frame")

	# A save must be close enough to the keeper and must physically parry the ball.
	home_keeper.global_position = Vector3(-49.5, 0.0, 0.0)
	ball.global_position = Vector3(-46.8, 1.0, 0.0)
	ball.linear_velocity = Vector3(-11.0, 0.0, 0.0)
	ball.last_touch = &"Bordeaux"
	ball.last_action = &"shot"
	assert(not controller.try_save(), "Keeper made a save from outside contact reach")
	assert(ball.last_touch == &"Bordeaux", "Out-of-reach save changed the ball touch")
	ball.global_position = Vector3(-49.0, 1.0, 0.0)
	ball.action_serial += 1
	controller.update_before_move(0.35)
	assert(controller.try_save(), "Keeper failed to parry a shot at close contact")
	assert(ball.last_touch == home_keeper.team_name, "Save did not register keeper possession touch")
	assert(ball.last_action == &"goalkeeper_save", "Save action was not recorded")
	await physics_frame
	assert(ball.linear_velocity.x > 0.0, "Parry did not redirect the ball into the field")
	assert(home_keeper._save_pose_time > 0.0, "Save reaction pose was not triggered")

	# A slower close-range shot is gathered, briefly held and distributed to a
	# teammate through the same physical ball impulse used by ordinary passes.
	ball.global_position = home_keeper.global_position + Vector3(0.45, 1.0, 0.0)
	ball.linear_velocity = Vector3(-2.0, 0.0, 0.0)
	ball.last_touch = &"Bordeaux"
	ball.last_action = &"shot"
	ball.action_serial += 1
	controller.update_before_move(0.35)
	assert(controller.try_save(), "Keeper failed to claim a slow close-range shot")
	assert(ball.goalkeeper_is_holding(home_keeper), "Claim did not establish keeper possession")
	assert(ball.last_action == &"goalkeeper_catch", "Claim was not recorded as a catch")
	controller.update_before_move(0.3)
	assert(ball.goalkeeper_is_holding(home_keeper), "Keeper released the ball before the hold interval")
	controller.update_before_move(0.3)
	assert(not ball.goalkeeper_is_holding(home_keeper), "Keeper did not distribute after the hold interval")
	assert(ball.last_action == &"goalkeeper_distribution", "Distribution action was not recorded")
	assert(ball.last_touch == home_keeper.team_name, "Distribution lost the keeper's team touch")
	assert(ball.linear_velocity.length() > 1.0, "Distribution did not impart physical ball velocity")

	print("Beechlawn goalkeeper reaction, catch and distribution checks passed")
	quit(0)
