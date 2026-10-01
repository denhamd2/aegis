class_name SellClutch
extends SkeletonModifier3D
## Selling (gauntlet/refs/animation_gap.md, Phase 4, "in-between behaviour"):
## a man holds the part that has taken the most.
##
## Coming up off the mat, and every so often standing between exchanges, his
## LEFT hand goes to it and he leans into it, then lets go:
##
##   head   hand to the forehead, head dropped a little
##   torso  hand on the ribs, hunched over them
##   legs   hand on the knee, bent down to it
##   arms   hand on the other shoulder
##
## WrestlerController decides when (sell()) and ticks it (advance()), off the
## match's own damage and tick count, so a replay sells the same way; this only
## draws it -- the lean on the spine, then the arm, with FootPlant's two-bone
## solve. Presentation only (ARCHITECTURE.md).

## Ticks a sell eases in and out over.
const EASE_TICKS := 10
## Lean into the hurt part, degrees forward through spine_02 and spine_03.
const LEAN_DEG := {"head": 6.0, "torso": 14.0, "legs": 26.0, "arms": 6.0}

## Game bone names, resolved by the controller.
var bones := {
	"spine_02": "spine_02", "spine_03": "spine_03", "Head": "Head",
	"spine_01": "spine_01", "thigh_l": "thigh_l", "calf_l": "calf_l",
	"upperarm_r": "upperarm_r",
	"upperarm_l": "upperarm_l", "lowerarm_l": "lowerarm_l", "hand_l": "hand_l",
}
## The body whose facing the hand's offsets are read in.
var wrestler: Node3D

var _ids := {}
var _part := ""
var _left := 0
var _weight := 0.0


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for key: String in bones:
		_ids[key] = sk.find_bone(bones[key])


## Hold `part` for `ticks` (eased in and out inside them).
func sell(part: String, ticks: int) -> void:
	if not LEAN_DEG.has(part):
		return
	_part = part
	_left = ticks


func is_selling() -> bool:
	return _weight > 0.0


func part() -> String:
	return _part


## One physics tick; `free` false (he is doing something) lets go at once.
func advance(free: bool) -> void:
	if not free:
		_left = 0
	if _left > 0:
		_left -= 1
		_weight = minf(1.0, _weight + 1.0 / EASE_TICKS) if _left > EASE_TICKS \
				else maxf(0.0, _weight - 1.0 / EASE_TICKS)
	else:
		_weight = maxf(0.0, _weight - 1.0 / EASE_TICKS)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _weight <= 0.0 or wrestler == null or _part == "":
		return
	for key: String in _ids:
		if int(_ids[key]) < 0:
			return
	var w := _weight * _weight * (3.0 - 2.0 * _weight)
	var to_sk := sk.global_transform.affine_inverse()
	var fwd := (to_sk.basis * -wrestler.global_transform.basis.z).normalized()
	var left := (to_sk.basis * -wrestler.global_transform.basis.x).normalized()
	var up := (to_sk.basis * Vector3.UP).normalized()
	# The lean first: the hand's target is on his own body, which moves with it.
	var lean := deg_to_rad(float(LEAN_DEG[_part])) * w * 0.5
	var axis := fwd.cross(up).normalized() # tipping about it takes the chest forward
	for key: String in ["spine_02", "spine_03"]:
		var id: int = _ids[key]
		var g := sk.get_bone_global_pose(id)
		var parent := sk.get_bone_parent(id)
		var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
		var turned := Transform3D(Basis(axis, -lean) * g.basis, g.origin)
		sk.set_bone_pose_rotation(id, (pg.basis.inverse() * turned.basis).get_rotation_quaternion())
	var at := func(key: String) -> Vector3:
		return sk.get_bone_global_pose(_ids[key]).origin
	var target: Vector3
	match _part:
		"head":
			target = at.call("Head") + fwd * 0.11 + up * 0.03 + left * 0.02
		"torso":
			target = at.call("spine_01") + fwd * 0.13 + left * 0.07 + up * 0.04
		"legs":
			target = (at.call("thigh_l") as Vector3).lerp(at.call("calf_l"), 0.85) + fwd * 0.09
		"arms":
			target = at.call("upperarm_r") + fwd * 0.07 + up * 0.02
	var ids := [_ids["upperarm_l"], _ids["lowerarm_l"], _ids["hand_l"]]
	var hand := sk.get_bone_global_pose(ids[2])
	FootPlant._solve_leg(sk, ids, Transform3D(hand.basis, hand.origin.lerp(target, w)))
