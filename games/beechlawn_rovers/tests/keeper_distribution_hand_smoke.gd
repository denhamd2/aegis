extends SceneTree
## The held rigid body tracks the throwing glove before its fixed-tick release.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/training_ground.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._start_kickoff(false)
	game.set_physics_process(false)
	for actor in game._home_players + game._away_players: actor.set_physics_process(false)
	var ball: FootballBall = game.ball
	var keeper: FootballPlayer
	for actor in game._home_players:
		if actor.profile.role == "goalkeeper": keeper = actor
	assert(keeper != null)
	var visual: FootballerVisual = keeper.get_node("Visual")
	var controller: GoalkeeperController = keeper._goalkeeper_controller
	controller.reset_for_stoppage()
	visual.reset_to_idle()
	ball.release_for_restart()
	ball.freeze = true
	ball.global_position = keeper.global_position + Vector3(0, 1.25, 0)
	ball.reset_physics_interpolation()
	await physics_frame
	ball.freeze = false
	assert(ball.goalkeeper_claim(keeper))
	controller._distribution_remaining = 0
	controller.update_before_move(1.0 / 60.0)
	var release_gaps: Array[float] = []
	visual.action_contact.connect(func(action: StringName):
		if action == &"keeper_distribution":
			release_gaps.append(ball.global_position.distance_to(visual.hand_positions()[1])))
	for tick in 63:
		await physics_frame
	assert(release_gaps.size() == 1 and release_gaps[0] < 0.26,
		"Held ball did not follow the throwing glove at release: %s" % str(release_gaps))
	assert(not ball.goalkeeper_is_holding(keeper) and ball.last_action == &"goalkeeper_distribution")
	print("KEEPER_HAND_RELEASE gap_m=", release_gaps[0])
	quit(0)
