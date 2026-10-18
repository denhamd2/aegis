extends SceneTree
## Run the complete short clock with both teams on AI, at a preserved 60 Hz dt.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.time_scale=6.0
	Engine.physics_ticks_per_second=360
	Engine.max_physics_steps_per_frame=64
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var actors: Array=game._home_players+game._away_players
	for actor in actors:actor.controlled_by_human=false
	var ball := game.get_node("Ball") as FootballBall
	var last_ball := ball.global_position
	var travelled := 0.0
	var max_still := 0
	var still := 0
	var samples := 0
	var home_shots := 0
	var away_shots := 0
	var serial := -1
	while not game._full_time and samples<18000:
		if game._kickoff_pending:game._start_kickoff(false)
		await physics_frame
		samples+=1
		var distance := ball.global_position.distance_to(last_ball)
		travelled+=distance
		last_ball=ball.global_position
		assert(ball.global_position.is_finite() and ball.global_position.y>-0.25,"Ball escaped terrain")
		for actor in actors:
			assert(actor.global_position.is_finite() and actor.global_position.y>-0.5,"Player escaped terrain")
		if samples%60==0:
			still=still+1 if ball.linear_velocity.length()<0.1 and not ball.freeze else 0
			max_still=maxi(max_still,still)
		if ball.action_serial!=serial:
			serial=ball.action_serial
			if ball.last_action==&"shot":
				if ball.last_touch==&"Beechlawn Rovers":home_shots+=1
				else:away_shots+=1
	assert(game._full_time,"Full short match did not reach full time")
	assert(ball.freeze,"Ball was not held at full time")
	assert(travelled>50.0,"AI match did not progress the ball")
	print("11v11 SOAK PASS seconds=180 ticks=",samples," ball_travel_m=",snappedf(travelled,0.1)," shots=",home_shots,"/",away_shots," goals=",game._home_score,"/",game._away_score," longest_stationary_samples_s=",max_still)
	game.free()
	quit(0)
