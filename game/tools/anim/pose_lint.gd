class_name PoseLint
extends RefCounted
## Automated checks on what a pose MEANS (gauntlet/refs/animation_gap.md,
## Phase 1). Every animation defect the owner has flagged -- the tie-up and
## grapple holds as backbends, the knee to the gut leaning away from the knee,
## a lean the wrong way round in eight clips before that -- was visible on a
## frame and invisible to every test, because the tests counted tracks and
## timings. These read the posed skeleton and fail on the defect itself.
##
## Everything is measured on the base rig in its own space: +Y up, +Z the way
## he faces (see test_clip_readability.gd), the mat at y = 0.
##
## Checks, per sampled frame:
##   * below_mat   -- no bone more than BELOW_MAT_TOLERANCE under the mat.
##   * neck        -- the head's line off the neck no more than NECK_MAX_DEG
##                    off the torso's line: past that the neck reads broken.
##   * hand_inside -- a hand no nearer than HAND_TORSO_CLEARANCE to its own
##                    torso's centre line (pelvis to neck): inside the body.
##   * lean        -- at a tagged frame (ClipIntent.LEAN), the torso leans the
##                    tagged way by at least LEAN_MIN_DEG.

const BELOW_MAT_TOLERANCE := 0.03
const NECK_MAX_DEG := 75.0
const HAND_TORSO_CLEARANCE := 0.07
const LEAN_MIN_DEG := 6.0
const SAMPLES := 11

const FORWARD := Vector3(0.0, 0.0, 1.0)


## Posed skeleton-space position of `bone`.
static func at(skeleton: Skeleton3D, bone: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


## The torso's lean off vertical, degrees: + forward, - back. Measured on the
## line from the pelvis to the neck, in the plane of the character's own
## facing (his pelvis yaw), so a man turned sideways is read correctly.
static func lean_deg(skeleton: Skeleton3D) -> float:
	var torso := at(skeleton, "neck_01") - at(skeleton, "pelvis")
	return rad_to_deg(atan2(torso.dot(facing_of(skeleton)), torso.dot(Vector3.UP)))


## The way his hips face, flattened onto the mat: up crossed with the
## left-to-right hip line. For the rig at rest (facing +Z, his right hip at
## -X) that is +Z. Independent of the rig's bone axes, which are rest-pose
## artifacts.
static func facing_of(skeleton: Skeleton3D) -> Vector3:
	var across := at(skeleton, "thigh_r") - at(skeleton, "thigh_l")
	var facing := Vector3.UP.cross(across)
	facing.y = 0.0
	return facing.normalized() if facing.length() > 0.001 else FORWARD


## No knee check, and why. A knee bent backwards is the one defect this
## file set out to catch that it cannot yet, reliably. Three measures were
## tried against render-checked poses and each misread normal ones:
##   * off the hip-ankle line along the foot: every man on his back with
##     pointed feet read as hyperextended;
##   * along the chest's facing: every roll and get-up did;
##   * the calf's own rotation about the knee's hinge (calibrated off the
##     kneel): Down_Supine bends about the OPPOSITE hinge sign to standing
##     and kneeling, by 105 degrees -- the pose is a face-down body rolled
##     over, which flips the leg frames -- yet rendered on Cody's skinned
##     mesh it reads as a normal knees-up lie.
## A reliable one needs the kneecap's direction from the mesh itself. Until
## then, knees are judged on renders.


## The way his chest faces, in 3D: the torso line (pelvis to neck) crossed
## with the hip line (left to right). +Z for the rig at rest.
static func body_front(skeleton: Skeleton3D) -> Vector3:
	var torso := at(skeleton, "neck_01") - at(skeleton, "pelvis")
	var across := at(skeleton, "thigh_r") - at(skeleton, "thigh_l")
	var front := torso.cross(across)
	return front.normalized() if front.length() > 1e-6 else FORWARD


## Defects in the current pose, as short strings.
static func check_pose(skeleton: Skeleton3D) -> Array[String]:
	var out: Array[String] = []
	# below_mat -- real joints only: *_leaf bones are end markers with no
	# geometry of their own, and flagged a toe tip 3 cm "under" a foot that
	# was flat on the mat.
	var lowest := INF
	var lowest_bone := ""
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		if name.contains("leaf"):
			continue
		var y := skeleton.get_bone_global_pose(i).origin.y
		if y < lowest:
			lowest = y
			lowest_bone = name
	if lowest < -BELOW_MAT_TOLERANCE:
		out.append("below_mat %s %.3f" % [lowest_bone, lowest])
	# neck
	var pelvis := at(skeleton, "pelvis")
	var neck := at(skeleton, "neck_01")
	var head := at(skeleton, "Head")
	var torso := neck - pelvis
	var neck_line := head - neck
	if torso.length() > 0.001 and neck_line.length() > 0.001:
		var bend := rad_to_deg(torso.angle_to(neck_line))
		if bend > NECK_MAX_DEG:
			out.append("neck %.0f deg" % bend)
	# hand_inside
	for side in ["l", "r"]:
		var hand := at(skeleton, "hand_" + side)
		var t := clampf((hand - pelvis).dot(torso) / maxf(torso.length_squared(), 1e-6), 0.0, 1.0)
		var d := hand.distance_to(pelvis + torso * t)
		if d < HAND_TORSO_CLEARANCE:
			out.append("hand_%s inside torso %.3f" % [side, d])
	return out
