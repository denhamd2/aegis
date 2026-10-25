extends SceneTree
## A stopped former cross must return to normal ground-ball pursuit on rutted turf.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game); await process_frame
	game.set_process(false); game.set_physics_process(false); game._set_players_physics_enabled(false)
	var ball: FootballBall = game.ball
	ball.freeze = true; ball.use_terrain = false
	for sx: float in [1.0, -1.0]:
		var actor: FootballPlayer = game._home_players[2] if sx > 0 else game._away_players[2]
		actor.reset_for_stoppage(); actor.controlled_by_human = false
		# The actor's root is in a shallow rut while the ball rests on adjacent turf.
		actor.position = Vector3(35 * sx, -.045, 0)
		actor.rotation.y = -PI / 2 * sx
		actor.ai_move_direction = Vector3(sx, 0, 0)
		ball.release_for_restart(); ball.position = Vector3(35.45 * sx, .12, 0)
		ball.last_action = &"cross"; ball.last_touch = actor.team_name
		ball.last_strike_style = &"driven_cross"; ball.seconds_since_bounce = 2.0
		actor._aerial_controller.before_move(1.0 / 60.0)
		if actor.ai_move_direction != Vector3(sx, 0, 0) or actor._aerial_controller.committed():
			failures.append("Stopped cross overrode ground pursuit; side=" + str(sx) + " movement=" + str(actor.ai_move_direction))
	for message in failures: push_error(message)
	print("GROUNDED_AERIAL_RECOVERY failures=", failures.size())
	game.free(); quit(0 if failures.is_empty() else 1)
