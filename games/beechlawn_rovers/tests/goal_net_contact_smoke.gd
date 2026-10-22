extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var game=load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	for actor in game._home_players+game._away_players:actor.position=Vector3(200,0,200)
	var ball: FootballBall=game.ball
	for side in [-1,1]:
		ball.freeze=true
		ball.position=Vector3.ZERO
		for f in 3:await physics_frame
		ball.position=Vector3(side*50.0,1.1,0)
		ball.linear_velocity=Vector3.ZERO
		ball.angular_velocity=Vector3.ZERO
		ball.last_touch=&"Boardeaux" if side<0 else &"Beechlawn Rovers"
		ball.freeze=false
		ball.kick(Vector3(side,0,0),18,0,&"shot",ball.last_touch)
		var previous: int=game._home_score+game._away_score
		for f in 28:
			await physics_frame
		if game._home_score+game._away_score!=previous+1:
			push_error("Goal missing"); game.free(); quit(1); return
		assert(not ball.freeze,"Ball must keep moving into net after crossing the goal line")
		var impact: Dictionary=game._net_impacts[side]
		var material:=impact.material as ShaderMaterial
		print("NET_CONTACT end=",side," point=",material.get_shader_parameter("impact_point")," vector=",material.get_shader_parameter("impact_vector"))
		assert(float(impact.age)<.1,"Physical net contact drives deformation")
		assert((material.get_shader_parameter("impact_vector") as Vector3).length()>.1,"Shot creates readable local bulge")
		for f in 8:await physics_frame
		assert(game._home_score+game._away_score==previous+1,"Net rebound cannot award another goal")
	game.free()
	print("GOAL_NET actual ball impacts, bulge parameters, continued flight and one score at both ends PASS")
	quit()
