extends SceneTree
var failed := false
func _initialize() -> void:call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failed=true; push_error(message)
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_kickoff(false)
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var ball: FootballBall=game.ball
	# Whole ball must cross either touchline; last touch determines the taker.
	for side in [-1.0,1.0]:
		ball.position=Vector3(12,.3,side*34.05)
		game._check_boundary_restart()
		check(not game.restart.active(),"Partly out ball must remain in play")
		ball.position=Vector3(12,.3,side*34.2)
		ball.last_touch=&"Beechlawn Rovers"
		game._check_boundary_restart()
		check(game.restart.active() and game.restart.kind=="THROW-IN" and game.restart.team==&"Boardeaux","Real throw awarded to opposite team")
		check(absf(game.restart.taker.position.z)>34.0,"Thrower's feet are on/outside touchline")
		var serial:=ball.action_serial
		game.restart.take(.5)
		var max_height := 0.0
		for frame in 85:
			game.restart.update(1.0/60)
			await physics_frame
			max_height=maxf(max_height,ball.position.y)
		check(not game.restart.active(),"Throw animation completes and resumes play")
		check(ball.action_serial>serial and max_height>1.7,"Overhead throw releases physically above the head")
		check(not ball.freeze,"Ball remains independent after release")
		game._set_players_physics_enabled(false)
		game.rules.restart_taker=null
	for entry in [{"last":&"Boardeaux","kind":"CORNER RESTART","team":&"Beechlawn Rovers"},{"last":&"Beechlawn Rovers","kind":"GOAL KICK","team":&"Boardeaux"}]:
		ball.position=Vector3(52.7,.4,9)
		ball.last_touch=entry.last
		game._check_boundary_restart()
		check(game.restart.kind==entry.kind and game.restart.team==entry.team,"Goal-line ownership "+entry.kind)
		game.restart.take(.5)
		for frame in 65:
			game.restart.update(1.0/60)
			await physics_frame
		check(not game.restart.active(),"Goal-line restart completes")
		game._set_players_physics_enabled(false)
	# A human restart waits, pauses the clock, then preserves deliberate aim/power.
	game.rules.restart_taker=null
	game.restart.begin("FREE KICK",&"Beechlawn Rovers",Vector3(20,0,4))
	var clock: float=game._remaining_time
	game._physics_process(1)
	check(is_equal_approx(clock,game._remaining_time),"Clock pauses during preparation")
	game.restart._ignore_buttons=false
	Input.action_press("shoot")
	game.restart.update(.6)
	check(game.restart.charge>.5,"Held keyboard shot charges free kick")
	Input.action_release("shoot")
	game.restart.update(1.0/60)
	check(game.restart.phase==game.restart.Phase.ACTION,"Release executes human restart")
	var before:=ball.action_serial
	# The free kick now includes an animated approach before the strike.
	for frame in 120:
		game.restart.update(1.0/60)
		await physics_frame
	check(ball.action_serial>before and not game.restart.active(),"Free-kick shot contact and follow-through finish")
	game._set_players_physics_enabled(false)
	game.restart.begin("PENALTY",&"Beechlawn Rovers",Vector3(44,0,2))
	var opposing_keeper: FootballPlayer
	for actor in game._away_players:
		if actor.profile.role=="goalkeeper": opposing_keeper=actor
	check(opposing_keeper!=null and is_equal_approx(opposing_keeper.position.x,52.5),"Penalty goalkeeper starts on goal line")
	var penalty_serial:=ball.action_serial
	game.restart.take(.55,true)
	for frame in 85:
		game.restart.update(1.0/60)
		await physics_frame
	check(ball.action_serial>penalty_serial and not game.restart.active(),"Penalty physically releases and returns to match/goal state")
	game.free()
	print("RESTARTS whole-ball ownership, overhead release, corners, goal kicks, free-kick contact and paused preparation failures=",int(failed))
	quit(1 if failed else 0)
