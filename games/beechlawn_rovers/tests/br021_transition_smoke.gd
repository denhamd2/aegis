extends SceneTree
## World-space foot trace through real start and direction changes.
func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var actor: FootballPlayer = game.player
	for other in game._home_players + game._away_players:
		if other != actor: other.position = Vector3(140, 0, 140)
	game.ball.release_for_restart()
	game.ball.freeze = true
	game.ball.position = Vector3(100, .2, 100)
	actor.position = Vector3(-18, PitchSurface.height_at(-18, 0) + .005, 0)
	actor.rotation.y = -PI / 2
	actor.reset_for_stoppage()
	actor.controlled_by_human = false
	actor.ai_sprinting = false
	var skeleton := actor._footballer_visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var rows: Array[Dictionary] = []
	actor.set_physics_process(true)
	for tick in 185:
		if tick < 65:
			actor.ai_move_direction = Vector3.RIGHT
		elif tick < 120:
			actor.ai_move_direction = Vector3.FORWARD
		else:
			actor.ai_move_direction = Vector3.LEFT
		await physics_frame
		var feet: Dictionary = {}
		for side in ["Left", "Right"]:
			var index := skeleton.find_bone("mixamorig_" + side + "Toe_End")
			var point := skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
			feet[side] = [point.x, point.y, point.z]
		rows.append({"tick": tick, "phase": "start" if tick < 65 else "turn" if tick < 120 else "reverse",
			"speed": Vector2(actor.velocity.x, actor.velocity.z).length(),
			"yaw": actor.rotation.y,
			"root": [actor.position.x, actor.position.y, actor.position.z], "feet": feet,
			"blend": actor._footballer_visual._blend_position})
	actor.set_physics_process(false)
	var result: Dictionary = {}
	for phase in ["start", "turn", "reverse"]:
		var speeds: Array[float] = []
		var foot_speed: Array[float] = []
		for index in range(1, rows.size()):
			var row: Dictionary = rows[index]
			var before: Dictionary = rows[index - 1]
			if row.phase != phase or before.phase != phase: continue
			speeds.append(float(row.speed))
			for side in ["Left", "Right"]:
				var current: Array = row.feet[side]
				var previous: Array = before.feet[side]
				var height := float(current[1]) - PitchSurface.height_at(float(current[0]), float(current[2]))
				var old_height := float(previous[1]) - PitchSurface.height_at(float(previous[0]), float(previous[2]))
				if height < .09 and old_height < .09 and absf(height - old_height) * 60 < .2 and row.speed > .5:
					foot_speed.append(Vector2(float(current[0]) - float(previous[0]), float(current[2]) - float(previous[2])).length() * 60)
		foot_speed.sort()
		var mean := 0.0
		for value in foot_speed: mean += value / maxi(1, foot_speed.size())
		result[phase] = {"mean_low_foot_slip": mean, "p90_low_foot_slip": foot_speed[mini(foot_speed.size()-1, int(foot_speed.size()*.9))] if foot_speed else -1,
			"samples": foot_speed.size(), "max_speed": speeds.max() if speeds else 0}
		print("BR021_TRANSITION ", phase, " ", result[phase])
	var path := OS.get_environment("BEECHLAWN_BR021_TRANSITION_REPORT")
	if path != "":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"summary": result, "samples": rows}, "  ") + "\n")
	var valid := float(result.start.mean_low_foot_slip) <= .65 \
		and float(result.turn.mean_low_foot_slip) <= .90 \
		and float(result.reverse.mean_low_foot_slip) <= 1.20 \
		and int(result.start.samples) >= 15 and int(result.turn.samples) >= 12 \
		and int(result.reverse.samples) >= 15 \
		and float(result.start.max_speed) >= 5.9 and float(result.turn.max_speed) >= 5.9 \
		and float(result.reverse.max_speed) >= 5.9
	game.free()
	if not valid:
		push_error("BR-021 live start/turn/reversal planted-foot slip regressed")
		quit(1)
		return
	print("BR021_TRANSITION_SMOKE PASS")
	quit()
