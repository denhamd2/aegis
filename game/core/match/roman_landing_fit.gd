extends RefCounted
## Roman-only retarget-space landing fit for the running inverted drop.
## Measured skin (not hair/bone origins) at the stock roster stature. Baked
## once into private adapted clips: no runtime skinning, solver or root offset.
const CLIP := &"running_grapple_inverted_drop__defender"
const RECOVERY := &"running_drop_down_neck"
const START := 55.0 / 30.0
const END := 63.0 / 30.0
const BOOT_BRACE := 63.5 / 30.0
const BOOT_CONTACT := 64.0 / 30.0
# Constrained degree-12 Bezier envelope fitted to protected skin/gear floor
# samples. End triples are zero: C2 entry/exit. Units before roster stature.
const CONTROL := [
	0.0, 0.0, 0.0, 0.0, -0.4902703379929363, -0.5533828844031743,
	0.0, 0.0, 0.0, -0.2658521335179965, 0.0, 0.0, 0.0,
]

static func offset(seconds: float) -> float:
	if seconds <= START or seconds >= END: return 0.0
	var t := (seconds - START) / (END - START)
	var points: Array = CONTROL.duplicate()
	for count in range(points.size() - 1, 0, -1):
		for index in count: points[index] = lerpf(points[index], points[index + 1], t)
	return points[0]

static func apply(library: AnimationLibrary, skeletons: Array, model: Node3D) -> void:
	if not library.has_animation(CLIP): return
	var animation := library.get_animation(CLIP)
	for sk: Skeleton3D in skeletons:
		var hips := sk.find_bone("J_Hips")
		if hips < 0: continue
		# Ancestors of J_Hips are static on this clip. Convert model-up to the
		# translation track's parent frame, including imported skeleton axes.
		var up := _model_up(sk, hips, model)
		var track := animation.find_track(NodePath("%s:J_Hips" % model.get_path_to(sk)), Animation.TYPE_POSITION_3D)
		assert(track >= 0, "Roman landing fit needs an authored hips position track")
		var original: Animation = animation.duplicate()
		# Keep untouched keys bit-exact, including their interpolation metadata.
		for key in animation.track_get_key_count(track):
			var time := animation.track_get_key_time(track, key)
			var correction := offset(time)
			if correction != 0.0:
				var position: Vector3 = animation.track_get_key_value(track, key)
				animation.track_set_key_value(track, key, position + up * correction)
		# Half-tick keys approximate the smooth envelope under linear playback.
		# Import stores float32 key times: do not insert nearly duplicate keys.
		for half_tick in range(220, 253):
			var time := float(half_tick) / 120.0
			var present := false
			for key in original.track_get_key_count(track):
				if absf(original.track_get_key_time(track, key) - time) < 0.000001:
					present = true
					break
			if not present:
				var position: Vector3 = original.position_track_interpolate(track, time)
				animation.position_track_insert_key(track, time, position + up * offset(time))
	_brace_landing_boots(animation)


static func _brace_landing_boots(animation: Animation) -> void:
	# Roman's imported boot geometry dips between two clear skin samples.
	# Bring his settled knee and ankle angles forward by one 60 Hz tick.
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(animation.track_get_path(track).get_concatenated_subnames())
		if not _carries_leg_rotation(bone):
			continue
		var pose := animation.rotation_track_interpolate(track, BOOT_CONTACT)
		var key := animation.track_find_key(track, BOOT_BRACE, Animation.FIND_MODE_NEAREST)
		if key >= 0 and absf(animation.track_get_key_time(track, key) - BOOT_BRACE) < 0.000001:
			animation.track_set_key_value(track, key, pose)
		else:
			animation.rotation_track_insert_key(track, BOOT_BRACE, pose)


static func apply_recovery(library: AnimationLibrary, player: AnimationPlayer, model: Node3D) -> void:
	var name := "%s/%s" % [PairedRecipes.LIBRARY, CLIP]
	if not player or not library.has_animation(&"down_neck") or not player.has_animation(name):
		return
	var landing := player.get_animation(name)
	var down: Animation = library.get_animation(&"down_neck").duplicate()
	# Preserve the neck sell and its loop. Carry the fitted leg, boot and
	# back angles into the recovery so the feet do not snap under the mat.
	for track in down.get_track_count():
		var path := down.track_get_path(track)
		var bone := String(path.get_concatenated_subnames())
		var type := down.track_get_type(track)
		if type == Animation.TYPE_POSITION_3D and bone == "J_Hips":
			var sk := model.get_node(NodePath(path.get_concatenated_names())) as Skeleton3D
			var correction := _model_up(sk, sk.find_bone(bone), model) * (-0.020 * 1.866 / 1.905)
			for key in down.track_get_key_count(track):
				var position: Vector3 = down.track_get_key_value(track, key)
				down.track_set_key_value(track, key, position + correction)
		if type != Animation.TYPE_ROTATION_3D \
				or (bone not in ["J_Spine1", "J_Spine2", "J_Chest"] and not _carries_leg_rotation(bone)):
			continue
		var source := landing.find_track(path, type)
		if source < 0:
			continue
		var final_pose := landing.rotation_track_interpolate(source, landing.length)
		var correction := final_pose * down.rotation_track_interpolate(track, 0.0).inverse()
		for key in down.track_get_key_count(track):
			var rotation: Quaternion = down.track_get_key_value(track, key)
			down.track_set_key_value(track, key, (correction * rotation).normalized())
	down.loop_mode = Animation.LOOP_LINEAR
	library.add_animation(RECOVERY, down)


static func _model_up(sk: Skeleton3D, bone: int, model: Node3D) -> Vector3:
	var parent := sk.get_bone_parent(bone)
	var basis := sk.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
	return (model.global_basis.inverse() * sk.global_basis * basis).inverse() * Vector3.UP


static func _carries_leg_rotation(bone: String) -> bool:
	for prefix in ["J_Leg_", "J_Knee_", "J_Foot_", "J_Toe_",
			"H_Leg_Vol_", "H_Kn_", "H_Foot_", "H_Toe_"]:
		if bone.begins_with(prefix):
			return true
	return false
