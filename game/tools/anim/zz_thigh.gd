extends SceneTree
func _init() -> void:
	var root: Node = (load("res://assets/animations/wrestling_clips.glb") as PackedScene).instantiate()
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := root.find_child("Skeleton3D", true, false) as Skeleton3D
	var at := sk.find_bone("thigh_l")
	var rest := sk.get_bone_rest(at).basis.get_rotation_quaternion()
	for name in ["DriveBy_Attacker", "Down_Supine"]:
		var clip := player.get_animation(name)
		for t in clip.get_track_count():
			if clip.track_get_type(t) == Animation.TYPE_ROTATION_3D and String(clip.track_get_path(t).get_concatenated_subnames()) == "thigh_l":
				var line: String = String(name) + ":"
				for k in clip.track_get_key_count(t):
					var q: Quaternion = clip.track_get_key_value(t, k) * rest.inverse()
					q = q.normalized()
					if q.w < 0: q = -q
					var posed: Quaternion = clip.track_get_key_value(t, k)
					var axis_rest := Vector3.UP
					var axis_now := (posed * rest.inverse()) * (rest * axis_rest)
					var aim := rad_to_deg((rest * axis_rest).angle_to(axis_now))
					line += " %d=%.0f/aim%.0f" % [k, rad_to_deg(2.0 * acos(clampf(q.w, -1, 1))), aim]
				print(line)
	quit()
