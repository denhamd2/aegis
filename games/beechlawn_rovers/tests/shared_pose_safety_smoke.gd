extends SceneTree
## Imported human poses must stay relaxed during idle and standing football actions.

func _initialize() -> void:
	call_deferred("_run")

func _arm_drops(visual: FootballerVisual) -> Vector2:
	var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var result := Vector2.ZERO
	for side in ["Left", "Right"]:
		var shoulder := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_" + side + "Arm")).origin)
		var elbow := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_" + side + "ForeArm")).origin)
		result.x += shoulder.y - elbow.y
		var hand := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_" + side + "Hand")).origin)
		result.y += shoulder.y - hand.y
	return result * 0.5

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var startup_failures: Array[String] = []
	for actor in game._home_players + game._away_players:
		var skeletons: Array[Node] = actor.get_node("Visual").find_children("*", "Skeleton3D", true, false)
		if skeletons.size() != 1:
			startup_failures.append("%s has %d visible rigs instead of one" % [actor.name, skeletons.size()])
	for actor in game._home_players + game._away_players:
		if actor.profile.role == "outfield" and _arm_drops(actor.get_node("Visual")).x < 0.14:
			startup_failures.append(str(actor.name))
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	for tick in 8:
		await physics_frame
	var failures: Array[String] = []
	if not startup_failures.is_empty():
		failures.append("Bind-pose arms visible before the first animation tick: " + ", ".join(startup_failures))
	for actor in game._home_players + game._away_players:
		var visual := actor.get_node("Visual") as FootballerVisual
		var drops := _arm_drops(visual)
		if actor.profile.role == "outfield" and drops.x < 0.14:
			failures.append("live idle %s elbow drop %.3f m" % [actor.name, drops.x])
	var visual := game.get_node("Player/Visual") as FootballerVisual
	visual.animation_tree.active = false
	for clip in [&"AN_Beechlawn_Idle", &"AN_Beechlawn_Walk", &"AN_Beechlawn_SlowJog", &"AN_Beechlawn_Jog", &"AN_Beechlawn_Sprint",
			FootballerVisual.STOP_CLIP, FootballerVisual.PASS_CLIP, FootballerVisual.RECEIVE_CLIP,
			FootballerVisual.SHOT_CLIP, &"AN_Beechlawn_CloseControl",
			&"AN_Beechlawn_WalkOn", &"AN_Beechlawn_WarmupJog"]:
		var animation := visual.animation_player.get_animation(clip)
		var horizontal_samples := 0
		var min_elbow_drop := INF
		for index in 9:
			visual.animation_player.play(clip)
			visual.animation_player.seek(animation.length * float(index) / 9.0, true)
			await physics_frame
			var drops := _arm_drops(visual)
			min_elbow_drop = minf(min_elbow_drop, drops.x)
			if drops.x < 0.10 and drops.y < 0.16:
				horizontal_samples += 1
		print("POSE_SAFETY clip=", clip, " horizontal_samples=", horizontal_samples,
			"/9 min_elbow_drop_m=", snappedf(min_elbow_drop, 0.001))
		if horizontal_samples > 4:
			failures.append("%s retained a T-shaped pose through %d/9 samples" % [clip, horizontal_samples])
		if clip == FootballerVisual.STOP_CLIP and min_elbow_drop < 0.15:
			failures.append("Braking flared the supporting arms toward the shoulder line (%.3f m drop)" % min_elbow_drop)
	if not failures.is_empty():
		push_error("Shared pose safety: " + "; ".join(failures))
		game.free()
		quit(1)
		return
	print("PASS: all live outfield idle poses and standing action silhouettes avoid sustained T poses")
	game.free()
	quit(0)
