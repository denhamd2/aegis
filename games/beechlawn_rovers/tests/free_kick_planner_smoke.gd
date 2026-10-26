extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false);game._set_players_physics_enabled(false)
	for sx in [1.0,-1.0]:
		var team: StringName = &"Beechlawn Rovers" if sx>0 else &"Boardeaux"
		game.restart.begin("FREE KICK",team,Vector3(29*sx,0,4*sx))
		var taker: FootballPlayer = game.restart.taker
		var opposing: Array = game._away_players if sx>0 else game._home_players
		assert(game.restart.wall.size()>=3 and game.restart._preview.multimesh.instance_count==18)
		if sx>0:
			Input.action_press("aim_right");game.restart.update(.2);Input.action_release("aim_right")
			assert(game.restart._target_z>.6 and is_equal_approx(game.restart._goal_reticle.position.z,game.restart._target_z),"Keyboard goal aiming updates the actual reticle")
			Input.action_press("low_modifier");game.restart.update(.016);Input.action_release("low_modifier")
			var reticle: Vector3=game.restart._goal_reticle.position
			assert(absf(reticle.y-game.surface_height(reticle.x,reticle.z)-.18)<.005,"Low aim is grounded at the goal mouth")
			game.restart.update(.016)
		for actor: FootballPlayer in game.restart.wall:
			assert(actor.profile.role!="goalkeeper" and actor.position.distance_to(game.restart.spot)>=9.15)
			assert((-actor.global_basis.z).dot((game.restart.spot-actor.position).normalized())>.95,"Wall faces the taker")
			assert(actor.get_node("Visual")._active_clip==&"AN_Beechlawn_WallBrace")
		var attacks: Array = game._home_players if sx>0 else game._away_players
		for actor: FootballPlayer in attacks:
			for defender in game.restart.wall:
				assert(actor.position.distance_to(defender.position)>=1.0,"Attackers clear the defensive wall")
		var keeper: FootballPlayer
		for actor: FootballPlayer in opposing:
			if actor.profile.role=="goalkeeper":keeper=actor
		var target_a := FootballFreeKickPlanner.choose(taker,[keeper],game.restart.spot,2)
		keeper.position.z=3.0*sx
		var target_b := FootballFreeKickPlanner.choose(taker,[keeper],game.restart.spot,2)
		assert(target_b.target_z*sx<0,"Aim at space away from visible goalkeeper position")
		keeper.position.z=-3.0*sx
		var target_c := FootballFreeKickPlanner.choose(taker,[keeper],game.restart.spot,2)
		assert(target_c.target_z*sx>0 and target_c.target_z!=target_b.target_z,"Context changes target, not only serial")
		assert(FootballFreeKickPlanner.choose(taker,opposing,Vector3(10*sx,0,0),2).is_empty(),"Deep kicks use normal short/long outlets")
		var standard := FootballFreeKickPlanner.strike(taker,.75,-2.6*sx,2.0,&"standard",false)
		var power := FootballFreeKickPlanner.strike(taker,.75,-2.6*sx,2.0,&"power",false)
		var curve := FootballFreeKickPlanner.strike(taker,.75,-2.6*sx,2.0,&"finesse",false)
		var low := FootballFreeKickPlanner.strike(taker,.75,-2.6*sx,2.0,&"low",false)
		assert(power.velocity.length()>standard.velocity.length() and curve.velocity.length()<standard.velocity.length())
		assert(low.velocity.y<.35 and standard.velocity.y>4,"Low stays low; elevated strikes keep their arc")
		assert(curve.spin.length()>1 and absf(curve.velocity.z-standard.velocity.z)>.1,"Curled launch has compensated side spin")
		var destination := FootballBallFlight.physics_position_from(game.ball.position,standard.velocity,standard.time,FootballBallFlight.damping(game.ball),FootballBallFlight.gravity(game.ball))
		assert(absf(destination.x-52.5*sx)<.01 and absf(destination.z+2.6*sx)<.01)
		var goal_ground: float=game.surface_height(52.5*sx,-2.6*sx)
		assert(absf(destination.y-goal_ground-2.0)<.02,"Discrete trajectory solver matches the intended goal plane")
		var variants := {}
		for serial in 8:
			game.ball.action_serial=serial
			var shot := FootballFreeKickPlanner.strike(taker,.9,3.0*sx,2.2,&"power")
			variants[str(shot.velocity)]=true
		assert(variants.size()>4,"Skill/charge-dependent physical placement error adds honest variation")
		game.restart.cancel()
	game.free()
	print("FREE_KICK_PLANNER PASS: legal facing/clearance, shared original brace, visible-keeper choice, delivery fallback, low/power/curl, discrete flight and bounded placement variation")
	root.close_requested.emit()
