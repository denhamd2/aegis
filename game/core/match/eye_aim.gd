class_name EyeAim
extends SkeletonModifier3D
## Eyes that look at the other man (gauntlet/refs/aaa_gap.md item 12).
##
## Roman's model has real eye bones, J_Eye_L and J_Eye_R, that no clip
## animates: until this his eyes stared straight out of his skull wherever his
## head pointed, so in a face-off close-up he looked THROUGH Cody. 2K26's faces
## are alive in exactly those shots, and most of that is the eyes tracking.
##
## A SkeletonModifier3D so it runs after the animation has posed the head each
## frame, which is the only time an aim can be right. It rotates each eye bone
## in its own frame from its rest-pose line of sight toward the target,
## clamped to MAX_ANGLE: past that a real eye would be the head turning, and
## an eyeball rolled further shows all white. Outside the clamp it eases back
## to centre rather than pinning at the edge.
##
## Presentation only. It touches two bones no gameplay reads, reads positions,
## and writes nothing back, so the replay hash cannot see it
## (ARCHITECTURE.md's cosmetic-systems rule).
##
## No blink: the model has no eyelid bones and no blend shapes (checked on the
## .glb). Cody's eyes are part of his body mesh and cannot move until they are
## split out, so he gets none of this.

## How far an eye turns before it gives up and recentres, in degrees. Human
## eyes comfortably rotate about 25-30 degrees; the rest is the head.
const MAX_ANGLE := 28.0
## Easing toward the aim, per second; fast, because eyes move in saccades.
const FOLLOW := 18.0
## The line of sight in skeleton space at rest: the model faces +Z.
const REST_FORWARD := Vector3(0.0, 0.0, 1.0)

## Where the eyes look: returns a world position, or Vector3.INF for "no
## one to look at" (eyes ease back to centre). Read every frame.
var look_target: Callable
var eye_bones: PackedStringArray = ["J_Eye_L", "J_Eye_R"]

var _current: Dictionary = {}   # bone -> Quaternion applied last frame


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not look_target.is_valid():
		return
	var delta := get_process_delta_time()
	var k := 1.0 - exp(-FOLLOW * maxf(delta, 1.0 / 240.0))
	var aim_world: Vector3 = look_target.call()
	var aim := skeleton.global_transform.affine_inverse() * aim_world
	for bone_name in eye_bones:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var want := Quaternion.IDENTITY if aim_world == Vector3.INF \
				else aim_rotation(skeleton, bone, aim)
		var have: Quaternion = _current.get(bone_name, Quaternion.IDENTITY)
		var now := have.slerp(want, k)
		_current[bone_name] = now
		var rest := skeleton.get_bone_rest(bone)
		skeleton.set_bone_pose_rotation(bone, rest.basis.get_rotation_quaternion() * now)


## The rotation, in the eye bone's own frame, that turns its rest line of
## sight toward `aim` (skeleton space), or identity if that is past MAX_ANGLE.
static func aim_rotation(skeleton: Skeleton3D, bone: int, aim: Vector3) -> Quaternion:
	var parent := skeleton.get_bone_parent(bone)
	var parent_pose := skeleton.get_bone_global_pose(parent) if parent >= 0 \
			else Transform3D.IDENTITY
	var eye := parent_pose * skeleton.get_bone_rest(bone)
	# The rest line of sight, in the bone's own frame.
	var forward := (skeleton.get_bone_global_rest(bone).basis.inverse() * REST_FORWARD).normalized()
	# The rest line carried by the animated head, and the line to the target,
	# both in the bone's own frame.
	var to_aim := (eye.basis.inverse() * (aim - eye.origin)).normalized()
	if to_aim.is_zero_approx():
		return Quaternion.IDENTITY
	var angle := forward.angle_to(to_aim)
	if angle > deg_to_rad(MAX_ANGLE):
		return Quaternion.IDENTITY
	return Quaternion(forward, to_aim)
