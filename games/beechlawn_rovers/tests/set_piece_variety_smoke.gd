extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	var planner := preload("res://scripts/restart_planner.gd")
	for team in [game._home_players,game._away_players]:
		var taker: FootballPlayer = team[2]
		var sx := taker.attack_sign
		var opposing: Array = game._away_players if sx>0 else game._home_players
		var targets := {}
		for serial in 7:
			var plan := planner.plan(taker,team,opposing,"PENALTY",Vector3(41.5*sx,0,0),serial)
			assert(absf(plan.direction.z) > .05,"AI penalties must offer deliberate placement")
			targets[plan.target_z]=true
		assert(targets.size()==7,"Penalties vary placement")
		game.restart.begin("FREE KICK",taker.team_name,Vector3(28*sx,0,3))
		assert(game.restart.wall.size()>=2)
		for actor in game.restart.wall:
			assert(actor.profile.role != "goalkeeper" and actor.position.distance_to(game.restart.spot)>=9.15,"Legal wall personnel and distance")
		assert(game.restart._goal_reticle != null)
		game.restart.cancel()
		game.restart.begin("GOAL KICK",taker.team_name,Vector3(-47*sx,0,0))
		assert(game.restart.taker.profile.role == "goalkeeper","Goal kicks use actual keeper, not array index zero")
		game.restart.cancel()
		# Deliberately open short outlet, then block it; test real lane scoring.
		for actor in team: actor.position=Vector3(-15*sx,0,25)
		taker.position=Vector3(-47*sx,0,0)
		var receiver: FootballPlayer = team[3]
		receiver.position=Vector3(-35*sx,0,0)
		for defender in opposing: defender.position=Vector3(0,0,-30)
		var safe := planner.plan(taker,team,opposing,"GOAL KICK",taker.position,0)
		assert(safe.mode == &"pass","Open short outlet")
		opposing[2].position=Vector3(-36*sx,0,0)
		var blocked := planner.plan(taker,team,opposing,"GOAL KICK",taker.position,0)
		assert(blocked.mode == &"long","Pressured outlet leads to long distribution")
		game.ball.position=Vector3(30*sx,.12,0)
		var powerful := ShotPlanner.plan(taker,.75,Vector3.RIGHT*sx,&"power")
		var travel: float = 22.5/powerful.speed
		var goal_height: float = .12+powerful.lift*travel-4.905*travel*travel
		assert(powerful.speed>25 and goal_height>1.0,"Powerful shots carry elevation to goal")
	game.free()
	print("SET_PIECES PASS: mirrored wall, keeper role, target variety, short/long lane decisions, powerful elevated shots")
	quit()
