extends SceneTree
## Last touch is not possession when the nearest opposing player is out of reach.
var _opposition_touches := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 64
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	var home := game.get_node("Player") as FootballPlayer
	var away: FootballPlayer
	for actor in game._away_players:
		if actor.profile.role == "outfield":
			away = actor
			break
	for actor in game._home_players + game._away_players:
		actor.set_physics_process(false)
		actor.controlled_by_human = false
		actor.global_position = Vector3(-45.0, 0.0, 30.0)
	home.global_position = Vector3(1.55, 0.0, 1.85)
	away.global_position = Vector3(1.18, 0.0, 1.33)
	home.set_physics_process(true)
	away.set_physics_process(true)
	var ball := game.get_node("Ball") as FootballBall
	ball.freeze = false
	ball.global_position = Vector3(0.0, FootballBall.RADIUS + 0.02, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.last_touch = home.team_name
	ball.last_action = &"dribble"
	ball.touched.connect(func(_kind: StringName, _speed: float):
		if ball.last_touch == away.team_name: _opposition_touches += 1)
	var start := ball.global_position
	for tick in 180:
		if tick % 12 == 0:
			var point := Vector2(ball.global_position.x, ball.global_position.z)
			game._update_team_ai(game._away_players, away, point, point, game._home_players)
			if tick == 0 and away.ai_move_direction.length_squared() < 0.01:
				_fail(game, "Defender stopped outside contact reach of an unowned loose ball");return
		await physics_frame
		if _opposition_touches > 0:
			break
	print("Loose-ball recovery: opponent_touches=", _opposition_touches,
		" ball_travel=", snappedf(ball.global_position.distance_to(start), 0.01))
	if _opposition_touches == 0:
		_fail(game, "Defender did not reach and touch the loose ball within three simulated seconds");return
	game.free()
	quit(0)

func _fail(game: Node, message: String) -> void:
	push_error(message)
	game.free()
	quit(1)
