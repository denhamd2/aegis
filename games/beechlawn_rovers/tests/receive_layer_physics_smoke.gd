extends SceneTree
## Moving receiver overlay must leave the supporting leg and pelvis untouched.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game = load("res://scenes/match_11v11.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var actor: FootballPlayer = game.player
	var visual := actor._footballer_visual
	var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var roots := {}
	for other in game._home_players+game._away_players:
		var id: int = other._footballer_visual.animation_tree.tree_root.get_instance_id()
		assert(not roots.has(id),"Receive bone filters must be actor-local")
		roots[id]=true
	for foot: StringName in [&"left",&"right"]:
		visual.reset_to_idle()
		visual.set_locomotion_speed(6,false,false,false,.1)
		visual.animation_tree.advance(.15)
		var before := skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_LeftFoot"))
		assert(visual.play_context_receive(foot,true,1))
		assert(before.is_equal_approx(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_LeftFoot"))),"Starting receive cannot reset the gait phase")
		visual.advance_context_receive(.2)
		var support := "Right" if foot == &"left" else "Left"
		var poses := {}
		for name in ["Hips",support+"UpLeg",support+"Leg",support+"Foot",support+"Toe_End"]:
			var index := skeleton.find_bone("mixamorig_"+name)
			poses[name] = skeleton.get_bone_global_pose(index)
		var receiving_toe := visual.receive_context_position(foot)
		visual.animation_tree.set("parameters/Receive/blend_amount",0.0)
		visual.animation_tree.advance(0)
		for name in poses:
			var index := skeleton.find_bone("mixamorig_"+name)
			assert(poses[name].is_equal_approx(skeleton.get_bone_global_pose(index)),"Overlay changed support chain: "+name)
		assert(receiving_toe.distance_to(visual.receive_context_position(foot))>.02,"Selected receiving leg actually changes")
		visual.cancel_context_receive()
	# Observe integrated physics rather than the velocity getter inside an impulse callback.
	var speeds := []
	for mode: StringName in [&"close",&"carry",&"sprint"]:
		actor.reset_for_stoppage()
		actor.position=Vector3(10,0,10)
		actor.rotation.y=-PI/2
		actor.velocity=Vector3.RIGHT*6
		var ball: FootballBall=game.ball
		ball.release_for_restart()
		ball.freeze=true
		ball.position=actor.position+Vector3(.55,FootballBall.RADIUS,0)
		ball.last_touch=actor.team_name
		ball.last_action=&"pass"
		await physics_frame
		ball.freeze=false
		await physics_frame
		ball.linear_velocity=Vector3.LEFT*8
		assert(ball.receive_touch(actor,ball.position,Vector3.RIGHT,mode))
		for frame in 3: await physics_frame
		speeds.append(ball.linear_velocity.x)
		assert(ball.linear_velocity.x>3,"Moving first touch must retain carrier travel")
	assert(speeds[0]<speeds[1] and speeds[1]<speeds[2],"Close/carry/sprint have distinct physical outlets")
	print("RECEIVE_LAYER_PHYSICS PASS supporting leg/pelvis unchanged, both active feet, integrated close/carry/sprint velocities=",speeds)
	game.free()
	quit()
