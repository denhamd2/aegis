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
		for key in animation.track_get_key_count(driver):
			var posed: Quaternion = animation.track_get_key_value(driver, key)
			var swing := Quaternion.IDENTITY.slerp(posed * rest.inverse(), SWING)
			animation.track_insert_key(out, animation.track_get_key_time(driver, key), swing * rest)
