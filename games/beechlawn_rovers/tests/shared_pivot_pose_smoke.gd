extends SceneTree
## Verify the actual imported human rig, not just the Blender/source quaternions.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/match_11v11.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._set_players_physics_enabled(false)
	var visual := game.get_node("Player/Visual") as FootballerVisual
	var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	visual.animation_tree.active = false
	for clip in [FootballerVisual.TURN_LEFT_CLIP, FootballerVisual.TURN_RIGHT_CLIP]:
		if absf(visual.animation_player.get_animation(clip).length - 0.6) > 0.02:
			_fail(game, "Shared pivot duration changed during export");return
		visual.animation_player.play(clip)
		visual.animation_player.seek(0.3, true)
		await physics_frame
		for side in ["Left", "Right"]:
			var shoulder := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_" + side + "Arm")).origin)
			var elbow := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_" + side + "ForeArm")).origin)
			var drop := shoulder.y - elbow.y
			if drop < 0.15:
				_fail(game, "Shared pivot retained a horizontal arm: %s %s %.3f m" % [clip, side, drop]);return
	print("Shared pivot pose PASS: both mirrored 0.6 s clips, relaxed arms on imported human rig")
	game.free()
	quit(0)

func _fail(game: Node, message: String) -> void:
	push_error(message)
	game.free()
	quit(1)
