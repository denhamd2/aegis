extends SceneTree
## Run at a 10 Hz render cadence: gait must still update each 60 Hz physics tick.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 16
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var visual := game.get_node("Player/Visual") as FootballerVisual
	var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	var bone := skeleton.find_bone("mixamorig_RightUpLeg")
	for i in 30: visual.set_locomotion_speed(6.0)
	var previous := Quaternion.IDENTITY
	var held := 0
	var longest := 0
	for tick in 100:
		await physics_frame
		var pose := skeleton.get_bone_pose_rotation(bone)
		if tick > 20:
			held = held + 1 if pose.is_equal_approx(previous) else 0
			longest = maxi(longest, held)
		previous = pose
	print("LOCOMOTION_CLOCK longest_stale_physics_ticks=", longest)
	game.free()
	if longest > 2:
		push_error("Running pose froze across physics ticks between idle frames")
		quit(1)
		return
	quit(0)
