extends SceneTree
## Mirrored handling legality, body-supported catches and actual parry recovery.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var ball: FootballBall = game.ball
	for actor in game._home_players + game._away_players:
		actor.position = Vector3(0, 0, 90)
		actor.controlled_by_human = false
	for team: Array[FootballPlayer] in [game._home_players, game._away_players]:
		# Keep the two sides on separate real ticks, including dribble-force guards.
		await physics_frame
		var keeper: FootballPlayer
		for actor in team:
			if actor.profile.role == "goalkeeper": keeper = actor
		var sx := keeper.attack_sign
		keeper.position = Vector3(-49.5 * sx, 0, 0)
		keeper.rotation.y = -PI / 2 * sx
		var controller := keeper._goalkeeper_controller
		controller.reset_for_stoppage()
		_shot(ball, keeper, Vector3(.3 * sx, 1, .8), -4 * sx)
		_prepare(controller, .35)
		_check(controller.try_save() and ball.last_action == &"goalkeeper_save", keeper,
			"wide slow ball caught at full stretch instead of parried")
		ball.release_for_restart()

		# Keeper and ball positions are tested separately: handling is governed
		# by the ball's location, including the sidelines and own goal line.
		for placement in [Vector2(-30, -29.5), Vector2(-36.3, -35.7),
				Vector2(-52.1, -52.7), Vector2(49, 49.5)]:
			controller.reset_for_stoppage()
			keeper.position.x = placement.x * sx
			_shot(ball, keeper, Vector3((placement.y - placement.x) * sx, 1, 0), -4 * sx)
			_prepare(controller, .35)
			_check(not controller.try_save(), keeper, "illegal handling outside own penalty area")
		keeper.position = Vector3(-49.5 * sx, 0, 20.0)
		controller.reset_for_stoppage()
		_shot(ball, keeper, Vector3(.3 * sx, 1, .4), -4 * sx)
		_prepare(controller, .35)
		_check(not controller.try_save(), keeper, "handling beyond the penalty-area side")
		keeper.position.z = 0

		controller.reset_for_stoppage()
		_shot(ball, keeper, Vector3(.55 * sx, 1, .8), -18 * sx)
		_prepare(controller, .35)
		_check(controller.try_save(), keeper, "first reachable parry failed")
		_check(controller.is_recovering(), keeper, "stretch save did not commit recovery")
		_shot(ball, keeper, Vector3(.5 * sx, 1, -.45), -18 * sx)
		controller.update_before_move(.25)
		_check(not controller.try_save(), keeper, "opposite second save during stretch recovery")
		# Actual movement/dribble call sites must respect the same commitment.
		keeper.ai_move_direction = Vector3.BACK
		keeper._stick = Vector2.ONE
		keeper.velocity = Vector3.ZERO
		keeper._update_locomotion(1.0 / 60.0)
		_check(Vector2(keeper.velocity.x, keeper.velocity.z).length() < .001, keeper,
			"locomotion ignored committed save recovery")
		ball.position = keeper.position + Vector3(.4 * sx, .15, 0)
		ball.linear_velocity = Vector3.ZERO
		ball.last_action = &"goalkeeper_save"
		ball.last_touch = keeper.team_name
		ball.last_touch_player = keeper
		keeper._update_dribble(1.0 / 60.0)
		_check(ball.last_action == &"goalkeeper_save", keeper,
			"dribble assistance erased a parry while recovering")
		_check(not controller.try_save(), keeper, "gathered a rebound before recovery finished")
		controller.update_before_move(1.2)
		_check(not controller.is_recovering(), keeper, "recovery failed to elapse")
		ball._physics_process(1.2)
		keeper._physics_process(1.0 / 60.0)
		_check(not ball.goalkeeper_is_holding(keeper),keeper,"rebound claimed before gloves lowered")
		keeper._footballer_visual.animation_player.advance(.25/maxf(absf(keeper._footballer_visual.animation_player.get_playing_speed()),.01))
		controller.try_save()
		_check(ball.goalkeeper_is_holding(keeper), keeper, "failed to gather slow own rebound after recovery")
		ball.release_for_restart()

		# A teammate touch/back-pass and a fast or distant rebound are excluded.
		for kind in [&"pass", &"goalkeeper_save"]:
			controller.reset_for_stoppage()
			ball.position = keeper.position + Vector3(.4 * sx, .2, 0)
			ball.linear_velocity = Vector3(-sx, 0, 0)
			ball.last_action = kind
			ball.last_touch = keeper.team_name
			ball.last_touch_player = team[1] if team[1] != keeper else team[2]
			ball.action_serial += 1
			_check(not controller.try_save(), keeper, "handled a teammate's return as own rebound")
		ball.last_touch_player = keeper
		ball.last_action = &"goalkeeper_save"
		ball.linear_velocity = Vector3(-8 * sx, 0, 0)
		_check(not controller.try_save(), keeper, "gathered an unsupported fast rebound")
		ball.position = keeper.position + Vector3(1.6 * sx, .2, 0)
		ball.linear_velocity = Vector3(-sx, 0, 0)
		controller.update_before_move(.1)
		_check(not controller.try_save() and keeper.ai_move_direction.x * sx > 0, keeper,
			"distant slow rebound was remotely claimed or not approached")
		controller.reset_for_stoppage()
		_shot(ball, keeper, Vector3(.45 * sx, 1, 0), -2 * sx)
		_prepare(controller, .35)
		_check(controller.try_save() and ball.goalkeeper_is_holding(keeper), keeper,
			"body-supported slow catch regressed")
		controller.reset_for_stoppage()
		_check(not controller.is_recovering(), keeper, "stoppage retained a stale recovery")
		ball.release_for_restart()
		keeper.position = Vector3(0, 0, 90)
	for failure in failures: push_error(failure)
	print("KEEPER_OUTCOMES failures=", failures.size())
	game.free()
	quit(0 if failures.is_empty() else 1)

func _check(passed: bool, keeper: FootballPlayer, message: String) -> void:
	if not passed: failures.append(str(keeper.team_name) + ": " + message)

func _shot(ball: FootballBall, keeper: FootballPlayer, offset: Vector3, speed: float) -> void:
	ball.freeze = true
	ball.position = keeper.position + offset
	ball.linear_velocity = Vector3(speed, 0, 0)
	ball.angular_velocity = Vector3.ZERO
	ball.last_touch = &"Boardeaux" if keeper.team_name == &"Beechlawn Rovers" else &"Beechlawn Rovers"
	ball.last_action = &"shot"
	ball.action_serial += 1

func _prepare(controller: GoalkeeperController, delta: float) -> void:
	controller.update_before_move(delta)
	var visual := controller.keeper.get_node("Visual") as FootballerVisual
	if controller._save_animation_started:
		visual.animation_player.advance(.25 / maxf(absf(visual.animation_player.get_playing_speed()), .01))
