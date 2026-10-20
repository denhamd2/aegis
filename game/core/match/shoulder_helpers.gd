class_name ShoulderHelpers
extends RefCounted
## Corrective shoulder bones for a skinned wrestler, added at load: HipHelpers'
## fix, for the shoulder.
##
## The owner, 20 Oct: "when Cody wins the match and is celebrating, one of his
## shoulders and arm gets deformed." Cody's skin was transferred from the base
## mannequin onto a statue (rig_static_wrestler.py), and its shoulder is two
## bones: the clavicle and the upper arm. An arm raised overhead -- the win,
## the arm raised by the referee, the title held up -- swings the upper arm
## 120-170 degrees out of his A-pose rest, and the deltoid, carried by one
## bone across that whole swing, folds into the joint: the top of the
## shoulder caves in and the armpit tears out.
##
##   * one bone per shoulder, child of the clavicle, in the upper arm's own
##     rest frame, so "half the upper arm's swing" is the same rotation in
##     both;
##   * a share of the upper-arm weight round the joint -- the deltoid cap
##     and the armpit -- moves onto it, fading to nothing a hand's width down
##     the arm and a little way onto the chest;
##   * its animation is that half swing (add_tracks()), read through
##     HipHelpers.scaled_turn for the same reason the hips are: an arm thrown
##     up and over passes 180 degrees from rest.
##
## Cosmetic only. A no-op on a skeleton without the bones it needs.

const SIDES := ["l", "r"]
const SWING := 0.5
## The share of a vertex's upper-arm weight that moves to the helper at the
## joint, fading out FADE_DOWN along the arm and FADE_IN onto the body.
const SHARE := 0.5
const FADE_DOWN := 0.16
const FADE_IN := 0.08


static func helper_name(side: String) -> String:
	return "H_Shoulder_Vol_%s" % side.to_upper()


static func has_helpers(skeleton: Skeleton3D) -> bool:
	return skeleton != null and skeleton.find_bone(helper_name("l")) >= 0


## Adds the bones and re-weights every skinned mesh under `skeleton`. Returns
## whether anything was added.
static func install(skeleton: Skeleton3D) -> bool:
	if skeleton == null or has_helpers(skeleton):
		return false
	var made := {}
	for side: String in SIDES:
		var clavicle := skeleton.find_bone("clavicle_%s" % side)
		var upper := skeleton.find_bone("upperarm_%s" % side)
		if clavicle < 0 or upper < 0 or skeleton.get_bone_parent(upper) != clavicle:
			return false
		made[side] = upper
	for side: String in SIDES:
		var upper: int = made[side]
		var bone := skeleton.add_bone(helper_name(side))
		skeleton.set_bone_parent(bone, skeleton.get_bone_parent(upper))
		skeleton.set_bone_rest(bone, skeleton.get_bone_rest(upper))
		skeleton.reset_bone_pose(bone)
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			_reweight(skeleton, child as MeshInstance3D, made)
	return true


static func _reweight(skeleton: Skeleton3D, mi: MeshInstance3D, uppers: Dictionary) -> void:
	var mesh := mi.mesh as ArrayMesh
	var skin := mi.skin
	if mesh == null or skin == null or mesh.get_blend_shape_count() > 0:
		return
	var upper_bind := {}
	var helper_bind := {}
	var joint := {}
	var along := {}
	for side: String in uppers:
		var name := "upperarm_%s" % side
		var found := -1
		for i in skin.get_bind_count():
			if skin.get_bind_name(i) == name:
				found = i
		if found < 0:
			return
		upper_bind[side] = found
		skin.add_named_bind(helper_name(side), skin.get_bind_pose(found))
		helper_bind[side] = skin.get_bind_count() - 1
		var rest := skeleton.get_bone_global_rest(uppers[side])
		joint[side] = rest.origin
		# Down the arm: toward the elbow.
		var elbow := skeleton.find_bone("lowerarm_%s" % side)
		along[side] = (skeleton.get_bone_global_rest(elbow).origin - rest.origin).normalized() \
				if elbow >= 0 else rest.basis.y.normalized()
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
			var p := to_skeleton * verts[v]
			for side: String in uppers:
				var t: float = (p - (joint[side] as Vector3)).dot(along[side])
				var z := 1.0
				if t > 0.0:
					z = 1.0 - smoothstep(0.0, FADE_DOWN, t)
				else:
					z = 1.0 - smoothstep(0.0, FADE_IN, -t)
				if z <= 0.0:
					continue
				HipHelpers._move_weight(bones, weights, v * per, per, upper_bind[side],
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


## Adds the helpers' tracks to `animation`: half the upper arm's swing out of
## rest, in the same frame.
static func add_tracks(animation: Animation, skeleton: Skeleton3D, skeleton_path: NodePath) -> void:
	if not has_helpers(skeleton):
		return
	for side: String in SIDES:
		var upper := skeleton.find_bone("upperarm_%s" % side)
		var driver := animation.find_track(
				NodePath("%s:upperarm_%s" % [skeleton_path, side]), Animation.TYPE_ROTATION_3D)
		if driver < 0:
			continue
		var rest := skeleton.get_bone_rest(upper).basis.get_rotation_quaternion()
		var out := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(out, NodePath("%s:%s" % [skeleton_path, helper_name(side)]))
		animation.track_set_interpolation_type(out, animation.track_get_interpolation_type(driver))
		var swing := Quaternion.IDENTITY
		for key in animation.track_get_key_count(driver):
			var posed: Quaternion = animation.track_get_key_value(driver, key)
			swing = HipHelpers.scaled_turn(posed * rest.inverse(), SWING, swing)
			animation.track_insert_key(out, animation.track_get_key_time(driver, key), swing * rest)
