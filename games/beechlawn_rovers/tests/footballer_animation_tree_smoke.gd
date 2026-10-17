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
	assert(visual.animation_tree.active, "Locomotion AnimationTree is inactive")
	assert(visual.animation_tree.tree_root is AnimationNodeBlendSpace1D, "Expected a one-dimensional locomotion blend space")
	var player := visual.get_node("Rig/AnimationPlayer") as AnimationPlayer
	for clip_name in ["AN_Beechlawn_Idle", "AN_Beechlawn_Jog", "AN_Beechlawn_Sprint", "AN_Beechlawn_PassRight"]:
		assert(player.has_animation(clip_name), "Missing locomotion clip: %s" % clip_name)
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
		if absf(new_length - old_length) >= 0.02:
			push_error("60 fps combined library changed clip duration: %s" % clip_name)
			quit(1)
			return
	var thigh_index := skeleton.find_bone("mixamorig_LeftUpLeg")
	assert(thigh_index >= 0, "Could not locate Mixamo thigh bone")
	await create_timer(0.15).timeout
	var idle_rotation := skeleton.get_bone_pose_rotation(thigh_index)
	visual.set_locomotion_speed(4.8, false)
	await create_timer(0.15).timeout
	var jog_rotation := skeleton.get_bone_pose_rotation(thigh_index)
	assert(idle_rotation.angle_to(jog_rotation) > 0.02, "AnimationTree did not drive a locomotion bone")
	visual.set_locomotion_speed(6.0, true)
	assert(is_equal_approx(visual.animation_tree.get("parameters/blend_position"), 1.0), "Sprint speed was not mapped to the blend space")
	print("Beechlawn reusable Y-Bot visual: 65-bone rig, preserved clip timing, pass clip, active blend and bone playback verified")
	quit(0)
