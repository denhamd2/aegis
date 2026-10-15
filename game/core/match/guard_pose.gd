class_name GuardPose
extends SkeletonModifier3D
## A blended procedural cover over authored standing poses while actively
## guarding. The animation remains the base pose; this gently draws in the arms.

const BLEND_TICKS := 5.0
var wrestler: WrestlerController
var guarding := false
var _blend := 0.0
var _ids := {}
var bones := {
	"upperarm_l": "upperarm_l", "lowerarm_l": "lowerarm_l",
	"upperarm_r": "upperarm_r", "lowerarm_r": "lowerarm_r",
}

func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for key: String in bones:
		_ids[key] = sk.find_bone(bones[key])

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or wrestler == null:
		return
	_blend = move_toward(_blend, 1.0 if guarding else 0.0, 1.0 / BLEND_TICKS)
	if _blend <= 0.001:
		return
	var to_skel := sk.global_basis.inverse()
	var right := (to_skel * wrestler.global_basis.x).normalized()
	var forward := (to_skel * -wrestler.global_basis.z).normalized()
	_apply(sk, "upperarm_l", right, -13.0 * _blend)
	_apply(sk, "lowerarm_l", right, -20.0 * _blend)
	_apply(sk, "upperarm_r", right, -10.0 * _blend)
	_apply(sk, "lowerarm_r", right, -18.0 * _blend)
	_apply(sk, "upperarm_l", forward, -7.0 * _blend)
	_apply(sk, "upperarm_r", forward, 7.0 * _blend)

func _apply(sk: Skeleton3D, bone: String, axis: Vector3, degrees: float) -> void:
	var id := int(_ids.get(bone, -1))
	if id < 0 or absf(degrees) < 0.001:
		return
	var pose := sk.get_bone_global_pose(id)
	pose.basis = Basis(axis, deg_to_rad(degrees)) * pose.basis
	sk.set_bone_global_pose(id, pose)
