extends SceneTree
## Travelling fast high shots on both real keeper rigs, with reachable/miss cases.
var report: Array[Dictionary] = []
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var cases := [
		{"name":"central_high","height":2.05,"side":0.,"time":.42,"save":true},
		{"name":"under_bar","height":2.30,"side":0.,"time":.42,"save":true},
		{"name":"high_left","height":2.20,"side":-1.2,"time":.48,"save":true},
		{"name":"high_right","height":2.20,"side":1.2,"time":.48,"save":true},
		{"name":"long_under_bar","height":2.30,"side":0.,"time":.80,"distance":18.,"save":true},
		{"name":"long_high_left","height":2.25,"side":-1.2,"time":.80,"distance":18.,"save":true},
		{"name":"unreachable_corner","height":2.30,"side":3.3,"time":.24,"save":false},
		{"name":"too_late","height":2.20,"side":1.5,"time":.12,"save":false},
		{"name":"over_bar","height":2.90,"side":0.,"time":.42,"save":false},
	]
	for team in [game._home_players,game._away_players]:
		var keeper: FootballPlayer
		for player in team:
			if player.profile.role == "goalkeeper": keeper = player
		for scenario in cases:
			for player in game._home_players+game._away_players:
				player.set_physics_process(false)
				player.position = Vector3(140,0,140)
			var sx := keeper.attack_sign
			keeper.position = Vector3(-49.5*sx,PitchSurface.height_at(-49.5*sx,0)+.005,0)
			keeper.rotation = Vector3(0,-PI/2*sx,0)
			keeper.controlled_by_human = false
			keeper.reset_for_stoppage()
			if keeper.has_meta("last_keeper_outcome"): keeper.remove_meta("last_keeper_outcome")
			game.ball.release_for_restart()
			game.ball.freeze = true
			game.ball.linear_velocity = Vector3.ZERO
			game.ball.angular_velocity = Vector3.ZERO
			game.ball.position = keeper.position+Vector3(float(scenario.get("distance",minf(8,float(scenario.time)*25)))*sx,1.90,0)
			await physics_frame
			await physics_frame
			game.ball.freeze = false
			await physics_frame
			var target := keeper.position+Vector3(0,float(scenario.height),float(scenario.side)*sx)
			var launch := FootballBallFlight.physics_launch(game.ball,target,float(scenario.time))
			assert(game.ball.kick_velocity(launch,&"shot",&"Boardeaux" if sx > 0 else &"Beechlawn Rovers",null), "High-shot fixture must launch a real legal-speed shot")
			keeper.set_physics_process(true)
			var saved := false
			var closest := INF
			var detail: Dictionary = {}
			var max_root := keeper.position.y
			var start_y := keeper.position.y
			var first_cross := -1
			for tick in 72:
				await physics_frame
				max_root = maxf(max_root,keeper.position.y)
				if first_cross < 0 and (game.ball.position.x+49.5*sx)*sx <= 0: first_cross = tick
				for hand in keeper._footballer_visual.hand_positions():
					var distance := hand.distance_to(game.ball.position)
					if distance < closest:
						closest = distance
						detail = {"tick":tick,"ball":str(game.ball.position),"hand":str(hand),"keeper":str(keeper.position),"clip":str(keeper._footballer_visual.animation_player.current_animation)}
				if game.ball.last_action in [&"goalkeeper_save",&"goalkeeper_catch"]:
					saved = true
					break
				if (game.ball.position.x-keeper.position.x)*sx < -1: break
			var tip_height := -1.0
			if saved:
				if String(scenario.name).contains("high_") and scenario.name != "central_high":
					assert(String(keeper._footballer_visual.animation_player.current_animation).contains("HighDive"))
					assert(max_root-start_y > .12,"High dive requires physical lift")
				for frame in 80:
					await physics_frame
					if tip_height < 0 and (game.ball.position.x+52.5*sx)*sx <= 0: tip_height = game.ball.position.y
				assert(keeper.is_on_floor() and not keeper._goalkeeper_controller._high_air_active,"Keeper must land naturally after a high save")
				assert((keeper.get_node("CollisionShape3D").shape as CapsuleShape3D).height > 1.7,"High-dive collision must restore after recovery")
				if String(scenario.name).ends_with("under_bar"):
					assert(keeper.get_meta("last_keeper_outcome",&"") == &"tip_over")
					assert(tip_height > GoalkeeperController.GOAL_HEIGHT+FootballBall.RADIUS,"A tip over must physically clear the bar")
			if scenario.name == "too_late": assert(first_cross >= 0 and first_cross/60.0 < keeper._goalkeeper_controller._reaction_time(),"Late-shot fixture must arrive before reaction")
			var result := {"team":str(keeper.team_name),"case":scenario.name,"expected_save":scenario.save,"saved":saved,"closest_hand_m":closest,"peak_root_y":max_root,"first_cross_tick":first_cross,"tip_height":tip_height,"detail":detail}
			report.append(result)
			print("HIGH_SHOT_CASE ",JSON.stringify(result))
			keeper.reset_for_stoppage()
			keeper.set_physics_process(false)
	var path := OS.get_environment("BEECHLAWN_KEEPER_HIGH_REPORT")
	if path != "":
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify({"cases":report},"  ")+"\n")
	var valid := true
	for result in report:
		if result.saved != result.expected_save: valid = false
	game.free()
	if not valid:
		push_error("Reachable high-shot saves or genuine miss controls failed; inspect HIGH_SHOT_CASE")
		quit(1)
		return
	print("KEEPER_HIGH_SHOTS PASS: fast central/corner shots and unreachable/reaction misses on both rigs")
	quit()
