extends SceneTree

const VISUAL_SCENE := "res://scenes/footballer_visual.tscn"
const PREVIOUS_LIBRARY := "res://assets/characters/mixamo/y_bot_animation_set.glb"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(VISUAL_SCENE) as PackedScene
	assert(packed != null, "Could not load the reusable footballer visual scene")
	var visual := packed.instantiate() as FootballerVisual
	root.add_child(visual)
	await process_frame
	var skeleton := visual.get_node("Rig/YBot_Armature/Skeleton3D") as Skeleton3D
	assert(skeleton != null and skeleton.get_bone_count() == 65, "Visual rig does not match the verified Mixamo skeleton")
	assert(is_equal_approx(absf(visual.get_node("Rig").rotation.y), PI),
		"Y-Bot visual forward axis was not aligned to the player's attack direction")
	assert(visual.animation_tree.active, "Locomotion AnimationTree is inactive")
	assert(visual.animation_tree.tree_root is AnimationNodeBlendTree, "Expected a layered locomotion blend tree")
	var player := visual.get_node("Rig/AnimationPlayer") as AnimationPlayer
	for clip_name in ["AN_Beechlawn_Idle", "AN_Beechlawn_Jog", "AN_Beechlawn_Sprint",
			"AN_Beechlawn_PassRight", "AN_Beechlawn_ReceiveRight",
			"AN_Beechlawn_StopFromRun", "AN_Beechlawn_Turn90Left",
			"AN_Beechlawn_Turn90Right", "AN_Beechlawn_ShotRight",
			"AN_Beechlawn_GroundedSlideTackle", "AN_Beechlawn_GetUpFromProne"]:
		assert(player.has_animation(clip_name), "Missing shared Y-Bot clip: %s" % clip_name)
	assert(absf(player.get_animation("AN_Beechlawn_GetUpFromProne").length - 0.9) < 0.02,
		"Prone get-up clip duration changed from its 60 fps timing")
	var previous_rig := (load(PREVIOUS_LIBRARY) as PackedScene).instantiate()
	root.add_child(previous_rig)
	var previous_player := previous_rig.get_node("AnimationPlayer") as AnimationPlayer
	for clip_name in ["AN_Beechlawn_Idle", "AN_Beechlawn_Jog", "AN_Beechlawn_Sprint",
			"AN_Beechlawn_SlideTackle", "AN_Beechlawn_ShoulderImpactSell"]:
		assert(player.has_animation(clip_name) and previous_player.has_animation(clip_name),
			"Missing preserved animation: %s" % clip_name)
		var new_length := player.get_animation(clip_name).length
		var old_length := previous_player.get_animation(clip_name).length
		print("Animation duration %s: old=%.3f new=%.3f" % [clip_name, old_length, new_length])
		if clip_name in ["AN_Beechlawn_Jog","AN_Beechlawn_Sprint"]:
			assert(absf(new_length-1.0)<.001,"Gameplay gait uses a normalized one-second phase")
		elif absf(new_length - old_length) >= 0.02:
			push_error("60 fps combined library changed clip duration: %s" % clip_name)
			quit(1)
			return
	var thigh_index := skeleton.find_bone("mixamorig_LeftUpLeg")
	assert(thigh_index >= 0, "Could not locate Mixamo thigh bone")
	var upper_arm_index := skeleton.find_bone("mixamorig_LeftArm")
	assert(upper_arm_index >= 0, "Could not locate Mixamo upper-arm bone")
	await process_frame
	var idle_arm_pose := skeleton.get_bone_pose_rotation(upper_arm_index)
	var idle_arm_rest := skeleton.get_bone_rest(upper_arm_index).basis.get_rotation_quaternion()
	assert(idle_arm_pose.angle_to(idle_arm_rest) > 0.08,
		"Relaxed idle arm animation did not override the imported T-pose")
	await create_timer(0.15).timeout
	var idle_rotation := skeleton.get_bone_pose_rotation(thigh_index)
	visual.set_locomotion_speed(4.8, false)
	await create_timer(0.15).timeout
	var jog_rotation := skeleton.get_bone_pose_rotation(thigh_index)
	assert(idle_rotation.angle_to(jog_rotation) > 0.02, "AnimationTree did not drive a locomotion bone")
	# Normal running must select jog, and sprint intent alone must not force a
	# fast gait while the body is stationary or still accelerating.
	for frame in 20:
		visual.set_locomotion_speed(6.0, false)
		await physics_frame
	var jog_blend := float(visual.animation_tree.get("parameters/Locomotion/blend_position"))
	if absf(jog_blend - 0.55) > 0.04:
		push_error("Normal 6 m/s run selected the wrong gait: blend=%.3f (jog is 0.55)" % jog_blend)
		quit(1)
		return
	for frame in 30:
		visual.set_locomotion_speed(0.0, true)
		await physics_frame
	assert(float(visual.animation_tree.get("parameters/Locomotion/blend_position")) < 0.05,
		"Held sprint selected running footwork on a stationary body")
	for frame in 30:
		visual.set_locomotion_speed(8.6, true)
		await physics_frame
	assert(float(visual.animation_tree.get("parameters/Locomotion/blend_position")) > 0.95,
		"Sprint speed was not mapped to the blend space")
	var tree := visual.animation_tree.tree_root as AnimationNodeBlendTree
	var close_node := tree.get_node("CloseControlAnimation") as AnimationNodeAnimation
	assert(close_node != null and close_node.animation == "AN_Beechlawn_CloseControl" and close_node.loop_mode == Animation.LOOP_LINEAR,
		"Close-control clip is missing from the layered blend tree or is not looped")
	visual.set_locomotion_speed(1.5, false, false, true)
	for frame in 20:
		visual.set_locomotion_speed(1.5, false, false, true)
		await physics_frame
	assert(float(visual.animation_tree.get("parameters/CloseControl/blend_amount")) > 0.95,
		"Close-control input did not select the close-footwork loop")
	visual.set_locomotion_speed(3.0, false, false, false)
	for frame in 20:
		visual.set_locomotion_speed(3.0, false, false, false)
		await physics_frame
	assert(float(visual.animation_tree.get("parameters/CloseControl/blend_amount")) < 0.05
		and float(visual.animation_tree.get("parameters/Locomotion/blend_position")) > 0.2,
		"Releasing close control did not smoothly return toward jogging")
	visual.set_locomotion_speed(4.8, false)
	visual.set_locomotion_speed(4.2, false, true)
	assert(visual.animation_tree.active and visual._active_action == &"",
		"Fast braking must retain stepping before the final planted stop")
	visual.set_locomotion_speed(2.4, false, true)
	assert(player.current_animation == "AN_Beechlawn_StopFromRun",
		"Slow braking did not start the Blender-authored stop clip")
	visual.set_locomotion_speed(3.2, false, false)
	assert(visual.animation_tree.active and visual._active_action == &"",
		"Resuming movement did not restore locomotion from the stop clip")
	visual.set_locomotion_speed(2.4, false, true)
	await create_timer(0.68).timeout
	assert(visual.animation_tree.active and visual._active_action == &"",
		"Stop clip did not settle back into the locomotion blend")
	assert(visual.play_turn(true), "Right 90-degree turn clip did not start")
	assert(player.current_animation == "AN_Beechlawn_Turn90Right",
		"Right turn selected the wrong animation")
	await create_timer(0.68).timeout
	assert(visual.play_turn(false), "Left 90-degree turn clip did not start")
	assert(player.current_animation == "AN_Beechlawn_Turn90Left",
		"Left turn selected the wrong animation")
	await create_timer(0.68).timeout
	assert(visual.animation_tree.active and visual._active_action == &"",
		"Turn clips did not return to locomotion")
	assert(visual.play_slide_tackle(), "Grounded slide tackle did not start")
	assert(player.current_animation == "AN_Beechlawn_GroundedSlideTackle",
		"Grounded slide selected the wrong animation")
	await create_timer(0.66).timeout
	assert(visual._active_action == &"get_up" and player.current_animation == "AN_Beechlawn_GetUpFromProne",
		"Grounded slide did not chain into its prone get-up action")
	await create_timer(0.98).timeout
	assert(visual.animation_tree.active and visual._active_action == &"",
		"Grounded slide/get-up sequence did not complete and return to locomotion")
	print("Beechlawn Y-Bot: locomotion, close-control loop, ball-action events, braking stop, mirrored turns, grounded slide-to-get-up playback and locomotion resume verified")
	quit(0)
