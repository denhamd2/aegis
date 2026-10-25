extends SceneTree
## Lists every single-key limb flip over 100 degrees per clip (the
## body-deformation gate's count, itemised).
func _initialize() -> void:
	var root: Node = (load("res://assets/animations/wrestling_clips.glb") as PackedScene).instantiate()
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip_name in player.get_animation_list():
		var clip := player.get_animation(clip_name)
		for t in clip.get_track_count():
			if clip.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := String(clip.track_get_path(t).get_concatenated_subnames())
			if not (bone.begins_with("thigh") or bone.begins_with("calf")
					or bone.begins_with("upperarm") or bone.begins_with("lowerarm")):
				continue
			for k in range(1, clip.track_get_key_count(t)):
				var a: Quaternion = clip.track_get_key_value(t, k - 1)
				var b: Quaternion = clip.track_get_key_value(t, k)
				var d := rad_to_deg(a.angle_to(b))
				if d > 100.0:
					print("%s %s key %d: %.0f" % [clip_name, bone, k, d])
	root.free()
	quit()
