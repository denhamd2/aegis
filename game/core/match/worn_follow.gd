class_name WornFollow
extends SkeletonModifier3D
## Carries the body's FINAL pose onto a second skeleton that dresses it.
##
## Roman is rigged on two skeletons -- body and head on one (114 bones);
## bottoms, shoes, hair, beard and wrist tape on another (471) -- and the clip
## drives both. Everything that bends the body after the clip only ever
## reached the first: the grip IK, FootPlant, the Inertializer. Measured by
## tools/probe/wear_follow.tscn before this: his wrist tape up to 0.82 m from
## his wrists through a body slam, left hanging where the clip had the hand
## while the IK took the real one to Cody's thigh.
##
## Runs LAST on the body skeleton and writes the worn one's shared bones to
## match: rotation and position only -- scale belongs to each skeleton's own
## RomanHeadShape, and copying it would apply it twice. The shared bones have
## the same rests and parents except the root (J_Hips), whose rest the worn
## skeleton holds in another axis frame; that one is matched in world space.
##
## Presentation only (ARCHITECTURE.md): bones on the model, nothing read back.

var worn: Skeleton3D
var _pairs: PackedInt32Array = []   # body, worn, body, worn, ...
var _root_body := -1
var _root_worn := -1


func bind(to: Skeleton3D) -> void:
	worn = to
	_pairs.clear()
	var body := get_skeleton()
	if body == null or worn == null:
		return
	for b in body.get_bone_count():
		var w := worn.find_bone(body.get_bone_name(b))
		if w < 0:
			continue
		var bp := body.get_bone_parent(b)
		var wp := worn.get_bone_parent(w)
		var same_parent := bp >= 0 and wp >= 0 \
				and body.get_bone_name(bp) == worn.get_bone_name(wp)
		if same_parent:
			_pairs.append(b)
			_pairs.append(w)
		elif bp < 0:
			_root_body = b
			_root_worn = w


func _process_modification() -> void:
	var body := get_skeleton()
	if body == null or worn == null or not is_instance_valid(worn):
		return
	if _root_body >= 0:
		var world := body.global_transform * body.get_bone_global_pose(_root_body)
		var g := worn.global_transform.affine_inverse() * world
		# Keep the worn root's own scale; take where and which way from the body.
		var s := worn.get_bone_global_pose(_root_worn).basis.get_scale()
		worn.set_bone_global_pose(_root_worn,
				Transform3D(g.basis.orthonormalized().scaled_local(s), g.origin))
	for i in range(0, _pairs.size(), 2):
		worn.set_bone_pose_rotation(_pairs[i + 1], body.get_bone_pose_rotation(_pairs[i]))
		worn.set_bone_pose_position(_pairs[i + 1], body.get_bone_pose_position(_pairs[i]))
