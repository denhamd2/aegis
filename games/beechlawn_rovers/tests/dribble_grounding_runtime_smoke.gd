extends SceneTree
## The old capsule climbed its rolling ball and inherited a vertical launch.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	for other in game._home_players + game._away_players: other.position = Vector3(200,0,200)
	var actor: FootballPlayer = game.player
	for human in [false,true]:
		actor.reset_for_stoppage()
		actor.position = Vector3.ZERO
		actor.rotation.y = -PI/2
		actor.controlled_by_human = human
		actor.ai_move_direction = Vector3.RIGHT
		actor.ai_action_cooldown = 100
		actor.set_physics_process(true)
		game.ball.release_for_restart()
		game.ball.freeze=true
		game.ball.position = Vector3(0.45,0.15,0)
		game.ball.freeze = false
		var visual := actor.get_node("Visual") as FootballerVisual
		var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
		var leg := skeleton.find_bone("mixamorig_LeftUpLeg")
		var previous := skeleton.get_bone_pose_rotation(leg)
		var late_motion := 0
		var max_height := 0.0
		var action: StringName = &"move_right" if actor.camera.global_basis.x.x>0 else &"move_left"
		if human: Input.action_press(action)
		for frame in 360:
			await physics_frame
			max_height = maxf(max_height, actor.position.y-PitchSurface.height_at(actor.position.x,actor.position.z))
			var current := skeleton.get_bone_pose_rotation(leg)
			if frame > 180 and current.angle_to(previous) > 0.002: late_motion += 1
			previous = current
		Input.action_release(action)
		print("DRIBBLE_RUNTIME human=",human," height=",max_height," late_leg_motion=",late_motion)
		if max_height > 0.12 or late_motion < 130:
			push_error("Live dribbling launched the capsule or locomotion froze after a cycle")
			game.free(); quit(1); return
	game.free(); quit(0)
