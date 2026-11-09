extends SceneTree
## Every authored clip on the base rig: each knee's and elbow's bend, signed,
## sampled across the clip. A joint that bends the wrong way (a knee kinked
## backwards, an elbow inside out) shows as the opposite sign to the same
## joint's natural flexion in Idle_Ready.
##
##   godot --headless --path game -s res://tools/probe/joint_audit.gd [-- --match Kick,Kneel]

const JOINTS := [["thigh_l", "calf_l", "foot_l"], ["thigh_r", "calf_r", "foot_r"],
		["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"]]


func _init() -> void:
	var filt: Array = []
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--match" and i + 1 < args.size():
			filt = Array(args[i + 1].split(","))
	var model: Node3D = (load("res://assets/characters/wrestler_base.glb") as PackedScene).instantiate()
	root.add_child(model)
	var clips: Node = (load("res://assets/animations/wrestling_clips.glb") as PackedScene).instantiate()
	var cp: AnimationPlayer = clips.find_child("AnimationPlayer", true, false)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var lib := cp.get_animation_library(cp.get_animation_library_list()[0])
	player.add_animation_library(&"a", lib)
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false)
	await process_frame
	var sign := {}
	_sample(player, sk, "a/Idle_Ready", 0.5)
	for j: Array in JOINTS:
		sign[j[1]] = signf(_bend(sk, j))
	for name: String in lib.get_animation_list():
		if not filt.is_empty() and not filt.any(func(f: String) -> bool: return name.contains(f)):
			continue
		var anim := lib.get_animation(name)
		var worst := {}
		for k in 61:
			var t := anim.length * float(k) / 60.0
			_sample(player, sk, "a/" + name, t)
			for j: Array in JOINTS:
				var b := _bend(sk, j) * float(sign[j[1]])
				if b < float(worst.get(j[1], [99.0])[0]):
					worst[j[1]] = [b, t]
		var bad := []
		for jn: String in worst:
			if float(worst[jn][0]) < -8.0:
				bad.append("%s %.0f deg at %.2fs" % [jn, worst[jn][0], worst[jn][1]])
		if not bad.is_empty():
			print("%-32s %s" % [name, ", ".join(bad)])
	print("done")
	quit()


func _sample(player: AnimationPlayer, sk: Skeleton3D, clip: String, t: float) -> void:
	player.play(clip)
	player.seek(t, true)
	player.advance(0.0)
	sk.force_update_all_bone_transforms()


## Signed bend at the middle joint (degrees): positive the way it bends
## naturally, measured about the parent bone's own X axis.
func _bend(sk: Skeleton3D, j: Array) -> float:
	var a := sk.find_bone(j[0])
	var b := sk.find_bone(j[1])
	var c := sk.find_bone(j[2])
	var pa := sk.get_bone_global_pose(a)
	var pb := sk.get_bone_global_pose(b).origin
	var pc := sk.get_bone_global_pose(c).origin
	var u := (pb - pa.origin).normalized()
	var w := (pc - pb).normalized()
	var axis := pa.basis.x.normalized()
	return rad_to_deg(atan2(u.cross(w).dot(axis), u.dot(w)))
