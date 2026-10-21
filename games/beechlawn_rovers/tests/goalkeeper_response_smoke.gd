extends SceneTree
## Grounded prediction, reaction gating and safer physical parries on both sides.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var ball := game.get_node("Ball") as FootballBall
	for actor in game._home_players + game._away_players:
		actor.set_physics_process(false)
		actor.controlled_by_human = false
		actor.global_position = Vector3(0, 0, 30)
	for sign_value in [1.0, -1.0]:
		var team: Array[FootballPlayer] = game._home_players if sign_value > 0 else game._away_players
		var opponents: Array[FootballPlayer] = game._away_players if sign_value > 0 else game._home_players
		var keeper: FootballPlayer
		var attacker: FootballPlayer
		for actor in team:
			if actor.profile.role == "goalkeeper": keeper = actor
		for actor in opponents:
			if actor.profile.role == "outfield":
				attacker = actor
				break
		keeper.global_position = Vector3(-49.5 * sign_value, 0, 0)
		var controller := keeper._goalkeeper_controller
		await _shot(ball, keeper, Vector3(sign_value * 10.0, 0.12, 1.0), -sign_value * 12.0)
		controller.update_before_move(0.35)
		if not controller._has_intercept:
			failures.append("%s ignored a goal-bound rolling shot by projecting it below the ground" % keeper.team_name)
		await _shot(ball, keeper, Vector3(sign_value * 0.5, 1.0, 0), -sign_value * 12.0)
		controller.update_before_move(0.0)
		if controller.try_save(): failures.append("%s saved before its reaction delay elapsed" % keeper.team_name)
		await _shot(ball, keeper, Vector3(sign_value * 0.5, 1.0, 0), sign_value * 12.0)
		controller.update_before_move(0.35)
		if controller.try_save(): failures.append("%s saved a ball already travelling away" % keeper.team_name)
		await _shot(ball, keeper, Vector3(-sign_value * 0.5, 1.0, 0), -sign_value * 12.0)
		controller.update_before_move(0.35)
		if controller.try_save(): failures.append("%s saved a ball already behind its body" % keeper.team_name)
		await _shot(ball, keeper, Vector3(sign_value * 0.5, 2.1, 0), -sign_value * 12.0)
		controller.update_before_move(0.35)
		if controller.try_save(): failures.append("%s made an unsupported high save without a jump" % keeper.team_name)
		keeper._save_pose_time = 0.0
		await _shot(ball, keeper, Vector3(sign_value * 2.6, 1.0, 0), -sign_value * 12.0)
		controller.update_before_move(0.35)
		if keeper._save_pose_time <= 0.0 or ball.last_action != &"shot":
			failures.append("%s did not prepare its visible save before contact" % keeper.team_name)
		attacker.global_position = keeper.global_position + Vector3(sign_value * 2.0, 0, 3.5)
		await _shot(ball, keeper, Vector3(sign_value * 0.9, 1.0, 0), -sign_value * 18.0)
		ball.freeze = false
		ball.linear_velocity = Vector3(-sign_value * 18.0, 0, 0)
		await physics_frame
		controller.update_before_move(0.35)
		var saved := controller.try_save()
		if saved and ball.dribble_touch(keeper, Vector3.RIGHT * sign_value, false, false, 0.23, 0.48, 1.05):
			failures.append("%s immediately absorbed its own parry with dribble assistance" % keeper.team_name)
		await physics_frame
		if not saved or ball.last_action != &"goalkeeper_save" or ball.linear_velocity.z >= 0.0:
			failures.append("%s failed to parry away from the near rebound attacker" % keeper.team_name)
		print("KEEPER_RESPONSE team=", keeper.team_name, " parry_velocity=", ball.linear_velocity)
		await _shot(ball, keeper, Vector3(sign_value * 0.9, 0.13, 0), -sign_value * 12.0)
		ball.freeze = false
		ball.linear_velocity = Vector3(-sign_value * 12.0, 0, 0)
		await physics_frame
		controller.update_before_move(0.35)
		var low_saved := controller.try_save()
		if not low_saved:
			failures.append("%s missed a reachable grounded shot after its reaction delay" % keeper.team_name)
		elif ball.dribble_touch(keeper, Vector3.RIGHT * sign_value, false, false, 0.23, 0.48, 1.05):
			failures.append("%s immediately absorbed its low parry with dribble assistance" % keeper.team_name)
		keeper.controlled_by_human = true
		keeper.ai_move_direction = Vector3.BACK
		await _shot(ball, keeper, Vector3(sign_value * 0.9, 1.0, 0), -sign_value * 12.0)
		controller.try_save()
		controller.update_before_move(0.35)
		if controller._reaction_remaining > 0.0 or keeper.ai_move_direction != Vector3.BACK:
			failures.append("%s human selection stopped reflex timing or overrode manual movement" % keeper.team_name)
		keeper.controlled_by_human = false
		attacker.global_position = Vector3(0, 0, 30)
		keeper.global_position = Vector3(0, 0, 30)
	for message in failures: push_error(message)
	game.free()
	quit(0 if failures.is_empty() else 1)

func _shot(ball: FootballBall, keeper: FootballPlayer, offset: Vector3, speed_x: float) -> void:
	ball.freeze = true
	ball.global_position = keeper.global_position + offset
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	await physics_frame
	ball.linear_velocity = Vector3(speed_x, 0, 0)
	ball.last_touch = &"Bordeaux" if keeper.team_name == &"Beechlawn Rovers" else &"Beechlawn Rovers"
	ball.last_action = &"shot"
	ball.action_serial += 1
