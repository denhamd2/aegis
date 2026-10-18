extends SceneTree
## Coordinate a moving outfielder, live ball and authored contact after a turn.
var _shots := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 64
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	# Isolate execution from team tactics: the actual carrier still moves,
	# turns, dribbles and executes the decision layer's shot through its marker.
	game.set_physics_process(false)
	game.set_process(false)
	var player := game.get_node("Player") as FootballPlayer
	var ball := game.get_node("Ball") as FootballBall
	for actor in game._home_players + game._away_players:
		actor.set_physics_process(false)
		actor.global_position = Vector3(-45.0, 0.0, 30.0)
	player.controlled_by_human = false
	player.global_position = Vector3(23.0, 0.0, 0.0)
	player.rotation.y = PI / 2.0
	player._flat_direction = Vector3.LEFT
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	ball.freeze = false
	ball.global_position = Vector3(23.7, 0.15, 0.0)
	ball.linear_velocity = Vector3.ZERO
	ball.last_touch = player.team_name
	ball.touched.connect(_on_touch)
	var progress := ball.global_position.x
	for tick in 720:
		if tick % 12 == 0:
			var target := ball.global_position + Vector3(3.0, 0.0, 0.0)
			player.ai_move_direction = (target - player.global_position).normalized()
			game._apply_carrier_action(player, game._home_players, game._away_players)
		await physics_frame
		progress = maxf(progress, ball.global_position.x)
		if _shots > 0:
			break
	print("AI carry-to-shot: shots=", _shots, " furthest_ball_x=", snappedf(progress, 0.01))
	var success := _shots == 1 and progress > 34.0
	if not success:
		push_error("A turning, unopposed AI outfielder failed to carry into range and deliver one contact-timed shot")
	game.free()
	quit(0 if success else 1)

func _on_touch(kind: StringName, _speed: float) -> void:
	if kind == &"shot":
		_shots += 1
