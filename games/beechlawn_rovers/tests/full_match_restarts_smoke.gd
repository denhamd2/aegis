extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game._start_kickoff(false)
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var ball := game.get_node("Ball") as FootballBall
	ball.global_position=Vector3(12,0.3,34.2)
	ball.last_touch=&"Beechlawn Rovers"
	game._check_boundary_restart()
	assert(game._boundary_pending and game._boundary_team==&"Bordeaux")
	game._physics_process(0.8)
	assert(not game._boundary_pending and not ball.freeze)
	assert(absf(ball.global_position.z)<34.0)
	game._set_players_physics_enabled(false)
	ball.global_position=Vector3(52.7,0.4,8.0)
	ball.last_touch=&"Bordeaux"
	game._check_boundary_restart()
	assert(game._boundary_kind=="CORNER RESTART" and game._boundary_team==&"Beechlawn Rovers")
	game._physics_process(0.8)
	game._set_players_physics_enabled(false)
	ball.global_position=Vector3(52.7,0.4,9.0)
	ball.last_touch=&"Beechlawn Rovers"
	game._check_boundary_restart()
	assert(game._boundary_kind=="GOAL KICK" and game._boundary_team==&"Bordeaux")
	game._physics_process(0.8)
	assert(ball.global_position.x<52.5)
	print("Full-match boundary ownership and restart placement PASS (touchline uses prototype ground restart)")
	game.free()
	quit(0)
