class_name HipHelpers
extends RefCounted
## Corrective hip bones for a skinned wrestler, added at load.
##
## A body skinned only to pelvis and thigh loses and gains volume as the hip
## folds: past about 90 degrees of flexion the thighs balloon and the trunks
## pinch at the crotch (body audit, Cody in the Figure-Four, Cross Rhodes squat
## and Getup). Roman's skin ships with helper bones for this; Cody's does not,
## and the .glb is 71 MB, so the helpers are made here instead of in the file:
##
##   * one bone per hip, child of the pelvis, in the thigh's own rest frame, so
##     "half the thigh's swing" is the same rotation in both;
##   * a share of the thigh weight on the hip band moves onto it (fading to
##     nothing by the knee), so the skin is carried by the pelvis, a bone that
##     turns half as far, and the thigh -- three steps, not two;
##   * the helper's animation is that half swing (see add_tracks()).
##
## Cosmetic only. A no-op on a skeleton without the bones it needs.

const SIDES := ["l", "r"]
## How far the helper turns, as a share of the thigh's swing out of rest.
const SWING := 0.5
## Past this much swing, which half of it the helper takes stops being
## obvious and has to be read off the frame before (scaled_turn).
##
## Not tuned: it is the emptiest band a thigh visits. Over the 16,964 thigh
## keys in wrestling_clips.glb the swing-from-rest spends 0.37% of its time
## between 130 and 140 degrees -- the lowest of any band above 60, with the
## traffic either side of it (14.7% at 30-40 going about a man's business,
## 2.4% at 140-150 on his back with his legs up). A branch has to be chosen
## somewhere, so it is chosen where the thigh almost never sits, and crossing
## it costs almost nothing.
const ANTIPODE_GATE := deg_to_rad(135.0)
## The share of a vertex's thigh weight that moves to the helper at the hip...
const SHARE := 0.55
## ...fading out over this far below the hip joint, metres (the knee is 0.4).
const FADE_DOWN := 0.30
## ...and above it, where the trunks meet the pelvis.
const FADE_UP := 0.10


static func helper_name(side: String) -> String:
	return "H_Hip_Vol_%s" % side.to_upper()


static func has_helpers(skeleton: Skeleton3D) -> bool:
	return skeleton != null and skeleton.find_bone(helper_name("l")) >= 0


## Adds the bones and re-weights every skinned mesh under `skeleton`. Returns
## whether anything was added.
static func install(skeleton: Skeleton3D) -> bool:
	if skeleton == null or has_helpers(skeleton):
		return false
	var pelvis := skeleton.find_bone("pelvis")
	if pelvis < 0:
		return false
	var made := {}
	for side: String in SIDES:
		var thigh := skeleton.find_bone("thigh_%s" % side)
		if thigh < 0 or skeleton.get_bone_parent(thigh) != pelvis:
			return false
		var bone := skeleton.add_bone(helper_name(side))
		skeleton.set_bone_parent(bone, pelvis)
		skeleton.set_bone_rest(bone, skeleton.get_bone_rest(thigh))
		skeleton.reset_bone_pose(bone)
		made[side] = thigh
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			_reweight(skeleton, child as MeshInstance3D, made)
	return true


static func _reweight(skeleton: Skeleton3D, mi: MeshInstance3D, thighs: Dictionary) -> void:
	var mesh := mi.mesh as ArrayMesh
	var skin := mi.skin
	if mesh == null or skin == null or mesh.get_blend_shape_count() > 0:
		return
	# Bind index of each thigh in this mesh's skin, and a new bind for its helper.
	var thigh_bind := {}
	var helper_bind := {}
	var hip_y := {}
	for side: String in thighs:
		var name := "thigh_%s" % side
		var found := -1
		for i in skin.get_bind_count():
			if skin.get_bind_name(i) == name:
				found = i
		if found < 0:
			return
		thigh_bind[side] = found
		skin.add_named_bind(helper_name(side), skin.get_bind_pose(found))
		helper_bind[side] = skin.get_bind_count() - 1
		hip_y[side] = skeleton.get_bone_global_rest(thighs[side]).origin.y
	var to_skeleton := skeleton.global_transform.affine_inverse() * mi.global_transform
	var rebuilt := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if bones.is_empty() or verts.is_empty() or bones.size() % verts.size() != 0:
			rebuilt = null
			break
		var per := bones.size() / verts.size()
		for v in verts.size():
			var y := (to_skeleton * verts[v]).y
			for side: String in thighs:
				var drop: float = hip_y[side] - y
				var z := 1.0
				if drop > 0.0:
					z = 1.0 - smoothstep(0.0, FADE_DOWN, drop)
				else:
					z = 1.0 - smoothstep(0.0, FADE_UP, -drop)
				if z <= 0.0:
					continue
				_move_weight(bones, weights, v * per, per, thigh_bind[side],
						helper_bind[side], SHARE * z)
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
		rebuilt.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {}, flags)
		rebuilt.surface_set_material(s, mesh.surface_get_material(s))
		rebuilt.surface_set_name(s, mesh.surface_get_name(s))
	if rebuilt == null:
		return
	rebuilt.custom_aabb = mesh.custom_aabb
	mi.mesh = rebuilt


## Moves `share` of the weight `from_bind` carries on this vertex onto
## `to_bind`, using a free slot or the vertex's smallest one, then renormalises.
static func _move_weight(bones: PackedInt32Array, weights: PackedFloat32Array,
		at: int, per: int, from_bind: int, to_bind: int, share: float) -> void:
	var from_slot := -1
	var to_slot := -1
	var smallest := 0
	for k in per:
		if bones[at + k] == from_bind and weights[at + k] > 0.0:
			from_slot = k
		if bones[at + k] == to_bind and weights[at + k] > 0.0:
			to_slot = k
		if weights[at + k] < weights[at + smallest]:
			smallest = k
	if from_slot < 0:
		return
	var moved := weights[at + from_slot] * share
	if to_slot < 0:
		to_slot = smallest
		if to_slot == from_slot:
			return
		bones[at + to_slot] = to_bind
		weights[at + to_slot] = 0.0
	weights[at + from_slot] -= moved
	weights[at + to_slot] += moved
	var total := 0.0
	for k in per:
		total += weights[at + k]
	if total > 0.0:
		for k in per:
			weights[at + k] /= total


## `share` of `delta`, read so that it follows on from `last` -- the share
## taken at the frame before, or IDENTITY to start a track.
##
## WHY NOT Quaternion.IDENTITY.slerp(delta, share). Every rotation has two
## readings: an angle about an axis, or 360 minus it about the opposite axis.
## They are the same pose, and for a WHOLE turn it makes no difference -- but
## a SHARE of them is two different poses, and 180 degrees apart at the worst
## of it. slerp re-normalises to the shorter reading on every call and keeps
## no memory of the last frame, so it picks whichever happens to be shorter
## for that frame alone.
##
## A thigh crosses that line. Flat on his back with his legs over him a man
## sits within a few degrees of 180 off his standing rest, and the clips cross
## it rather than stopping at it: Getup_Rise key 4 is 174.1 degrees about
## (-0.25, 0.95, 0.21) and key 5 is 179.1 about (0.26, -0.92, -0.29) -- the
## same turn carrying on past the line, read back with its axis flipped. Half
## of the first is 87 degrees one way and half of the second 90 the other, so
## the helper whipped 176.4 degrees in a 33 ms frame while the thigh it
## follows moved 11.9. It carries SHARE of the skin from the hip down
## FADE_DOWN of the thigh, so that is the leg folding through itself -- 40 of
## them over 24 clips, every get-up and every move Cody takes.
##
## So both readings are built and the one nearer the last frame wins, which is
## the only thing that distinguishes them: the half that carries on. Below
## ANTIPODE_GATE there is nothing to choose -- the short reading is the turn
## the animator keyed and the long one is its 300-degree twin -- and offering
## the choice there is actively harmful, because a thigh making a small turn
## about a tumbling axis will take the long way and stay there.
static func scaled_turn(delta: Quaternion, share: float, last: Quaternion) -> Quaternion:
	var q := delta.normalized()
	if q.w < 0.0:
		q = -q                      # canonical, so the angle lands in [0, PI]
	var sine := sqrt(maxf(1.0 - q.w * q.w, 0.0))
	if sine <= 1e-6:
		return Quaternion.IDENTITY  # no turn to read, and no axis to read it on
	var axis := Vector3(q.x, q.y, q.z) / sine
	var angle := 2.0 * atan2(sine, q.w)
	var short := Quaternion(axis, angle * share)
	if angle < ANTIPODE_GATE:
		return short
	var long := Quaternion(-axis, (TAU - angle) * share)
	return short if absf(short.dot(last)) >= absf(long.dot(last)) else long


## Adds the helpers' tracks to `animation`: half the thigh's swing out of
## rest, in the same frame. `skeleton_path` is how the animation addresses the
## skeleton.
static func add_tracks(animation: Animation, skeleton: Skeleton3D, skeleton_path: NodePath) -> void:
	if not has_helpers(skeleton):
		return
	for side: String in SIDES:
		var thigh := skeleton.find_bone("thigh_%s" % side)
		var driver := animation.find_track(
				NodePath("%s:thigh_%s" % [skeleton_path, side]), Animation.TYPE_ROTATION_3D)
		if driver < 0:
			continue
		var rest := skeleton.get_bone_rest(thigh).basis.get_rotation_quaternion()
		var out := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(out, NodePath("%s:%s" % [skeleton_path, helper_name(side)]))
		animation.track_set_interpolation_type(out, animation.track_get_interpolation_type(driver))
		# Carried across the keys: which half of a turn past ANTIPODE_GATE the
		# helper takes is only decidable against the frame before it.
		var swing := Quaternion.IDENTITY
		for key in animation.track_get_key_count(driver):
			var posed: Quaternion = animation.track_get_key_value(driver, key)
			swing = scaled_turn(posed * rest.inverse(), SWING, swing)
			animation.track_insert_key(out, animation.track_get_key_time(driver, key), swing * rest)
