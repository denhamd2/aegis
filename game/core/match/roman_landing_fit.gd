extends RefCounted
## Roman-only retarget-space landing fit for the running inverted drop.
## Measured skin (not hair/bone origins) at the stock roster stature. Baked
## once into private adapted clips: no runtime skinning, solver or root offset.
const CLIP := &"running_grapple_inverted_drop__defender"
const START := 55.0 / 30.0
const END := 63.0 / 30.0
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
		var parent := sk.get_bone_parent(hips)
		var parent_basis := sk.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
		# Ancestors of J_Hips are static on this clip. Convert model-up to the
		# translation track's parent frame, including imported skeleton axes.
		var skeleton_frame := model.global_basis.inverse() * sk.global_basis
		var up := (skeleton_frame * parent_basis).inverse() * Vector3.UP
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
