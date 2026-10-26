extends SceneTree
## Live fixed-tick approach, actual shared toe contact, and genuine misses.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false); game._set_players_physics_enabled(false)
	game._spectator_mode = true
	var kicks: Array[Dictionary] = []
	var passes: Array[StringName] = []
	game.ball.touched.connect(func(action: StringName, _speed: float):
		if action==&"pass": passes.append(action))
	game.ball.touched.connect(func(action: StringName, speed: float):
		if action == &"shot": kicks.append({"distance":game.restart.last_contact_distance,"speed":speed,"root":game.restart.taker.position,"style":game.ball.last_strike_style}))
	for sx in [1.0,-1.0]:
		var team: StringName = &"Beechlawn Rovers" if sx>0 else &"Boardeaux"
		for style in [&"standard",&"finesse",&"low"]:
			game.restart.cancel(); game._goal_pause_timer=0; game._full_time=false
			game._set_players_physics_enabled(false)
			game.restart.begin("FREE KICK",team,Vector3(28*sx,0,3*sx))
			var actor: FootballPlayer = game.restart.taker
			var start := actor.position
			var stationary: Vector3 = game.ball.position
			var serial: int = game.ball.action_serial
			game.restart._shot_style=style; game.restart._target_z=-2.7*sx
			game.restart._target_height=2.1
			var before := kicks.size()
			game.restart.take(.76,true)
			assert(game.restart.phase == game.restart.Phase.ACTION and game.restart._approaching)
			var max_jump := 0.0
			var side_spin := 0.0
			for tick in 128:
				game.restart.update(1.0/60)
				await physics_frame
				if not game.restart.released:
					assert(game.ball.freeze and game.ball.position.is_equal_approx(stationary),"Ball is stationary until a real boot contact")
				if tick<30: assert(game.ball.action_serial==serial,"No early wind-up impulse")
				for defender in game.restart.wall:
					max_jump=maxf(max_jump,defender.position.y-game.surface_height(defender.position.x,defender.position.z))
				if style==&"finesse" and game.restart.released: side_spin=maxf(side_spin,absf(game.ball.angular_velocity.y))
				if not game.restart.active(): break
			assert(kicks.size()==before+1,"One actual strike, without a fallback impulse")
			assert(float(kicks[-1].distance)<=.22,"Live toe must reach the independent ball")
			assert(start.distance_to(kicks[-1].root)>1.0,"Taker approaches rather than striking from a static pose")
			assert(not game.restart.active(),"Follow-through returns to open play")
			if style==&"standard": assert(max_jump>.05 and max_jump<.35,"Wall reacts with a bounded physical hop")
			if style==&"finesse": assert(side_spin>8,"Actual curled flight retains intended side spin")
			print("FREE_KICK_CONTACT ",team," ",style," toe_m=",kicks[-1].distance," hop_m=",max_jump)
		# Keep the ball within the former 1.1m root test, but outside boot reach.
		game.restart.cancel(); game._set_players_physics_enabled(false)
		game.restart.begin("FREE KICK",team,Vector3(29*sx,0,2*sx))
		game.restart._shot_style=&"standard";game.restart.take(.7,true)
		game.ball.position.z+=.75*sx
		var miss_serial: int=game.ball.action_serial
		for tick in 64:
			game.restart.update(1.0/60)
			await physics_frame
		assert(not game.restart.released and game.ball.freeze and game.ball.action_serial==miss_serial,"Anatomical miss cannot release through the old root-radius guard")
		game.restart.cancel()
		game._set_players_physics_enabled(false)
		game.restart.begin("FREE KICK",team,Vector3(31*sx,0,4*sx))
		var pass_start: Vector3=game.restart.taker.position
		var pass_count:=passes.size()
		game.restart.take(.5,false)
		assert(game.restart.taker.position.is_equal_approx(pass_start),"Short free kick must not teleport its taker at commit")
		for tick in 110:
			game.restart.update(1.0/60);await physics_frame
			if not game.restart.active(): break
		assert(passes.size()==pass_count+1 and not game.restart.active(),"Short free kick approaches and releases once")
		game.restart.cancel();game._set_players_physics_enabled(false)
		game.restart.begin("FREE KICK",team,Vector3(29*sx,0,3*sx))
		var cancel_serial: int=game.ball.action_serial
		game.restart.take(.7,true);game.restart.update(.15);game.restart.cancel()
		assert(not game.restart.active() and not game.restart._approaching and not game.restart._marker_pending)
		assert(game.restart.taker.velocity.is_zero_approx() and game.restart._preview==null)
		for tick in 4:await physics_frame
		assert(game.ball.action_serial==cancel_serial,"Cancelled run-up cannot release later")
	game.free()
	print("FREE_KICK_CONTACT PASS: both teams, three strikes, fixed ball, >1m approach, <=22cm anatomical contact, single impulses, reacting wall, genuine misses and cleanup")
	root.close_requested.emit()
