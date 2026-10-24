extends SceneTree
## Wide low/mid/high real-ball saves require extension, flight and full recovery.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var cases: Array[Dictionary] = []
	for band in [{"name":"low","height":.42},{"name":"mid","height":1.15},{"name":"high","height":2.20}]:
		for side in [-1.,1.]:
			cases.append({"name":band.name,"height":band.height,"side":side*2.,"time":.58,"distance":10.,"save":true})
	cases.append({"name":"unreachable","height":1.3,"side":3.4,"time":.24,"distance":6.,"save":false})
	cases.append({"name":"late","height":1.2,"side":2.,"time":.12,"distance":3.,"save":false})
	var report: Array[Dictionary] = []
	for team in [game._home_players,game._away_players]:
		var keeper: FootballPlayer
		for candidate in team:
			if candidate.profile.role == "goalkeeper": keeper = candidate
		for scenario in cases:
			for candidate in game._home_players+game._away_players:
				candidate.set_physics_process(false)
				candidate.position = Vector3(140,0,140)
			var sx := keeper.attack_sign
			keeper.position = Vector3(-49.5*sx,PitchSurface.height_at(-49.5*sx,0)+.005,0)
			keeper.rotation = Vector3(0,-PI/2*sx,0)
			keeper.reset_for_stoppage()
			keeper.controlled_by_human = false
			game.ball.release_for_restart()
			game.ball.freeze = true
			game.ball.linear_velocity = Vector3.ZERO
			game.ball.angular_velocity = Vector3.ZERO
			game.ball.position = keeper.position+Vector3(float(scenario.distance)*sx,1.90 if scenario.height>1.6 else .8,0)
			await physics_frame
			await physics_frame
			game.ball.freeze = false
			await physics_frame
			var target := keeper.position+Vector3(0,float(scenario.height),float(scenario.side)*sx)
			assert(game.ball.kick_velocity(FootballBallFlight.physics_launch(game.ball,target,float(scenario.time)),&"shot",&"Boardeaux" if sx>0 else &"Beechlawn Rovers",null))
			keeper.set_physics_process(true)
			var saved := false
			var closest := INF
			var peak_roll := 0.0
			var flight := false
			var start := keeper.position
			var launch_z := keeper.position.z
			var committed := false
			var detail: Dictionary = {}
			for tick in 85:
				await physics_frame
				if keeper._goalkeeper_controller._save_animation_started and not committed:
					committed = true
					launch_z = keeper.position.z
				if committed and not keeper.is_on_floor(): flight = true
				var skeleton := keeper._footballer_visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
				var axis := skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_Head")).origin-skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_Hips")).origin
				axis = skeleton.global_basis*axis
				var roll := rad_to_deg(acos(clampf(absf(axis.normalized().y),0,1)))
				peak_roll = maxf(peak_roll,roll)
				for hand in keeper._footballer_visual.hand_positions():
					var from: Vector3 = game.ball.position-game.ball.linear_velocity/60.
					var gap := hand.distance_to(Geometry3D.get_closest_point_to_segment(hand,from,game.ball.position))
					if gap<closest:
						closest=gap
						detail={"tick":tick,"hand":str(hand),"ball":str(game.ball.position),"roll":roll,"clip":str(keeper._footballer_visual.animation_player.current_animation)}
				if game.ball.last_action in [&"goalkeeper_save",&"goalkeeper_catch"]:
					saved = true
					break
				if (game.ball.position.x-keeper.position.x)*sx < -1: break
			var travel := absf(keeper.position.z-launch_z)
			for frame in 130: await physics_frame
			var restored := keeper.is_on_floor() and not keeper._keeper_is_recovering() \
				and (keeper.get_node("CollisionShape3D").shape as CapsuleShape3D).height>1.7
			var motion_ok: bool = not scenario.save or (peak_roll>55 and travel>.12 and flight and restored)
			var result := {"team":str(keeper.team_name),"case":scenario.name,"side":scenario.side,"saved":saved,"expected":scenario.save,"closest_m":closest,"roll_degrees":peak_roll,"committed_travel_m":travel,"airborne":flight,"restored":restored,"motion_ok":motion_ok,"detail":detail}
			report.append(result)
			print("FULL_DIVE_CASE ",JSON.stringify(result))
			keeper.reset_for_stoppage()
			keeper.set_physics_process(false)
	var path := OS.get_environment("BEECHLAWN_FULL_DIVE_REPORT")
	if path!="":
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify({"cases":report},"  ")+"\n")
	var valid := true
	for result in report:
		if result.saved!=result.expected or not result.motion_ok: valid=false
	game.free()
	if not valid:
		push_error("Full-stretch diving save or honest-miss control failed; inspect FULL_DIVE_CASE")
		quit(1)
		return
	print("KEEPER_FULL_DIVE PASS: bilateral low/mid/high contact, physical flight, recovery, honest misses")
	quit()
