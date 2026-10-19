extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var player := game.get_node("Player") as FootballPlayer
	var ball := game.get_node("Ball") as FootballBall
	player.controlled_by_human = false
	player.global_position = Vector3(40, 0, 0)
	player.rotation.y = -PI / 2.0
	player.velocity = Vector3(6, 0, 0)
	player.ai_move_direction = Vector3.RIGHT
	player._stick = Vector2.RIGHT
	ball.global_position = Vector3(40.7, 0.11, 0)
	ball.last_touch = player.team_name
	player._do_shot(0.42)
	var queued := player._visual_shot_pending
	# The next staggered tactical update asks for a different carry lane.
	player.ai_move_direction = Vector3.BACK
	player._update_locomotion(1.0 / 60.0)
	var preparation_lateral_speed := absf(player.velocity.z)
	# The real contact callback clears the commitment and applies the kick.
	player._on_visual_action_contact(&"shot")
	var contact := ball.last_action == &"shot"
	player._update_locomotion(1.0 / 60.0)
	var released := absf(player.velocity.z) > 0.01
	print("SHOT_APPROACH queued=",queued," preparation_lateral_speed=",preparation_lateral_speed," contact=",contact," steering_resumed=",released)
	var passed := queued and preparation_lateral_speed < 0.001 and contact and released
	game.free()
	if not passed:
		push_error("Staggered AI steering turns a preparing kicker away before its contact marker")
	quit(0 if passed else 1)
