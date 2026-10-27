extends SceneTree
## Imported hand marker controls one live rigid-body release for either team.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/training_ground.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game._start_kickoff(false)
	game.set_physics_process(false)
	for actor in game._home_players + game._away_players:
		actor.set_physics_process(false)
	var ball: FootballBall = game.ball
	for side in [game._home_players, game._away_players]:
		var keeper: FootballPlayer
		for actor in side:
			if actor.profile.role == "goalkeeper": keeper = actor
		assert(keeper != null)
		var controller: GoalkeeperController = keeper._goalkeeper_controller
		var visual: FootballerVisual = keeper.get_node("Visual")
		controller.reset_for_stoppage()
		visual.reset_to_idle()
		ball.release_for_restart()
		ball.global_position = keeper.global_position + Vector3(0, 1.2, 0)
		assert(ball.goalkeeper_claim(keeper))
		controller._distribution_remaining = 0
		var before := ball.action_serial
		controller.update_before_move(1.0 / 60.0)
		assert(controller._distribution_pending and visual._active_action == &"keeper_distribution",
			"Keeper did not play the distribution clip")
		assert(visual.action_contact_time(&"keeper_distribution") == 0.5,
			"Imported hand release differs from the authored frame")
		assert(absf(visual.animation_player.current_animation_length - 0.95) < 0.02,
			"Keeper distribution duration differs from the 58-frame source")
		visual.animation_player.advance(0.47)
		assert(ball.goalkeeper_is_holding(keeper) and ball.action_serial == before,
			"Ball left the gloves before contact")
		visual.animation_player.advance(0.06)
		assert(not ball.goalkeeper_is_holding(keeper), "Hand marker did not release the ball")
		assert(ball.last_action == &"goalkeeper_distribution" and ball.last_touch == keeper.team_name,
			"Distribution lost the keeper team or action")
		assert(ball.last_strike_part == &"hands", "Keeper throw was logged as a foot strike")
		assert(ball.action_serial == before + 1, "Distribution released more than once")
		visual.animation_player.advance(0.5)
		assert(ball.action_serial == before + 1 and visual._active_action == &"",
			"Distribution failed to recover into locomotion")
		# A stoppage while winding up must not emit a delayed release.
		ball.release_for_restart()
		assert(ball.goalkeeper_claim(keeper))
		controller._distribution_remaining = 0
		controller.update_before_move(1.0 / 60.0)
		var cancelled_serial := ball.action_serial
		keeper.reset_for_stoppage()
		ball.release_for_restart()
		visual.animation_player.advance(0.65)
		assert(ball.action_serial == cancelled_serial and not controller._distribution_pending,
			"Cancelled keeper throw fired its release marker")
	print("Keeper distribution marker, recovery and cancellation passed for both teams")
	quit(0)
