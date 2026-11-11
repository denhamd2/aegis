class_name FallRagdoll
extends RefCounted
## A long fall's limp body (off the Cell's roof, its wall, through a panel):
## a PhysicalBoneSimulator3D on the game skeleton, capsules on the main bones,
## built the first time it is needed. Cosmetic only -- the man's root still
## falls on its deterministic ballistic path (WrestlerController._tick_roof_fall),
## so nothing in the match reads where the bones went.

## Canonical game bones that get a body, and their capsule radius.
const BONES := {
	"pelvis": 0.14, "spine_02": 0.14, "spine_03": 0.15, "Head": 0.11,
	"upperarm_l": 0.055, "lowerarm_l": 0.05, "upperarm_r": 0.055, "lowerarm_r": 0.05,
	"thigh_l": 0.075, "calf_l": 0.06, "thigh_r": 0.075, "calf_r": 0.06,
}

var _sim: PhysicalBoneSimulator3D
var _bodies: Array[PhysicalBone3D] = []
var _limp := false


static func for_wrestler(w: WrestlerController) -> FallRagdoll:
	if w.skeleton == null:
		return null
	var r := FallRagdoll.new()
	if not r._build(w):
		return null
	return r


func _build(w: WrestlerController) -> bool:
	var sk := w.skeleton
	_sim = PhysicalBoneSimulator3D.new()
	_sim.name = "FallRagdoll"
	_sim.active = false
	sk.add_child(_sim)
	for canonical: String in BONES:
		var bone := w._skeleton_bone_name(canonical)
		var i := sk.find_bone(bone)
		if i < 0:
			continue
		var pb := PhysicalBone3D.new()
		pb.bone_name = bone
		pb.mass = 6.0
		pb.friction = 0.9
		pb.linear_damp = 0.15
		pb.angular_damp = 1.2
		# Only the ground and the set pieces under him, not his own capsule.
		pb.collision_layer = 0
		pb.collision_mask = 1
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE if canonical in ["Head", "upperarm_l",
				"upperarm_r", "thigh_l", "thigh_r", "spine_02", "spine_03"] \
				else PhysicalBone3D.JOINT_TYPE_HINGE
		var length := _bone_length(sk, i)
		var shape := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = float(BONES[canonical])
		cap.height = maxf(length, cap.radius * 2.2)
		shape.shape = cap
		# Along the bone (the bone's +Y runs toward its child).
		shape.position = Vector3(0.0, length * 0.5, 0.0)
		pb.add_child(shape)
		_sim.add_child(pb)
		_bodies.append(pb)
	return not _bodies.is_empty()


static func _bone_length(sk: Skeleton3D, i: int) -> float:
	var kids := sk.get_bone_children(i)
	if kids.is_empty():
		return 0.2
	return sk.get_bone_rest(kids[0]).origin.length()


func is_limp() -> bool:
	return _limp


## Goes limp, moving as the body was: `v` in metres a second.
func go_limp(v: Vector3) -> void:
	if _sim == null or _limp:
		return
	_limp = true
	_sim.active = true
	_sim.physical_bones_start_simulation()
	for b in _bodies:
		b.linear_velocity = v + Vector3(0.0, 0.0, 0.0)
		b.angular_velocity = Vector3(randf_range(-2, 2), 0.0, randf_range(-2, 2)) * 0.0 \
				+ Vector3(1.2, 0.0, 0.6)


## Landed: the animation has him again (the down clip, inertialized).
func settle() -> void:
	if _sim == null or not _limp:
		return
	_limp = false
	_sim.physical_bones_stop_simulation()
	_sim.active = false
