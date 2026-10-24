extends SceneTree
## Exercise skills while the real CharacterBody brakes with a rolling ball.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	game._kickoff_pending = false
	var actor: FootballPlayer
	for player in game._home_players+game._away_players:
		player.position = Vector3(140,0,140)
		if player.profile.player_id == &"shane_denham": actor = player
	actor.controlled_by_human = false
	var contacts: Array[Dictionary] = []
	game.ball.touched.connect(func(kind: StringName, _speed: float):
		if kind == &"skill": contacts.append({"gap":actor.skills.contact_point().distance_to(game.ball.global_position)}))
	for speed in [3.36,6.0]:
		actor.reset_for_stoppage()
		actor.position = Vector3(0,PitchSurface.height_at(0,0)+.005,0)
		actor.rotation = Vector3.ZERO
		actor.velocity = Vector3.FORWARD*speed
		actor.ai_move_direction = Vector3.FORWARD
		game.ball.release_for_restart()
		game.ball.position = actor.position+Vector3(.09,.13,-.50)
		game.ball.linear_velocity = Vector3.FORWARD*minf(speed,4)
		game.ball.last_touch = actor.team_name
		game.ball.last_touch_player = actor
		game.ball.last_action = &"dribble"
		game.ball.freeze = false
		# Finish unfreezing before applying the rolling launch. Setting cached
		# velocity while frozen was discarded by the first server integration.
		await physics_frame
		await physics_frame
		game.ball.position = actor.position+Vector3(.09,.13,-.50)
		game.ball.linear_velocity = Vector3.ZERO
		game.ball.angular_velocity = Vector3.ZERO
		game.ball.kick(Vector3.FORWARD,minf(speed,4),0,&"dribble",actor.team_name,actor)
		contacts.clear()
		actor.set_physics_process(true)
		assert(actor.skills.request(&"step_over",Vector3.RIGHT))
		var trace: Array[Dictionary] = []
		for frame in 50:
			await physics_frame
			if frame < 24: trace.append({"frame":frame,"actor":str(actor.position),"player_velocity":str(actor.velocity),"ball":str(game.ball.position),"velocity":str(game.ball.linear_velocity),"active":str(actor.skills.active),"serial":game.ball.action_serial,"expected":actor.skills._serial,"owner":str(game.ball.last_touch_player.name) if game.ball.last_touch_player != null else "none","toe":str(actor.skills.contact_point())})
		actor.set_physics_process(false)
		print("MOVING_SKILL speed=",speed," contacts=",contacts)
		if contacts.is_empty(): print("MOVING_TRACE ",JSON.stringify(trace))
		assert(contacts.size()==1,"Moving skill missed its actual foot contact")
	actor.reset_for_stoppage()
	actor.velocity = Vector3.FORWARD*actor.tuning.sprint_speed
	game.ball.last_touch = actor.team_name
	game.ball.last_touch_player = actor
	game.ball.position = actor.position+Vector3(0,.13,-.50)
	game.ball.linear_velocity = Vector3.ZERO
	assert(not actor.skills.request(&"step_over",Vector3.RIGHT), "Full-sprint entry must require controlled pace instead of starting an unreachable clip")
	game.free()
	print("SKILL_MOVING PASS")
	quit()
