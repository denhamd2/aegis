class_name RopeReach
extends SkeletonModifier3D
## A man pinned or held near the ropes reaching for them -- the rope break
## (gauntlet/refs/animation_gap.md, Phase 4: position).
##
## MatchReferee decides that he can reach them (WrestlerController.
## rope_within_reach(), read off his origin, so the match stays deterministic)
## and when; this only draws it. Of his four limbs it takes the one whose root
## -- shoulder or hip -- is nearest the bottom rope on that side, and carries
## the hand or foot out to the nearest point of the rope over REACH_TICKS with
## the same two-bone solve FootPlant uses for a leg. Past arm's length the solve
## straightens the limb along the line to the rope, which is what a man
## stretching for it looks like. He keeps hold until he is back on his feet,
## then lets go over RELEASE_TICKS.
##
## Presentation only: bones on the model, nothing read back into the match.

## Blend in and out, in physics ticks.
const RELEASE_TICKS := 10
## Bottom rope (RingBuilder.ROPE_HEIGHT_BOTTOM), and the rope line.
const ROPE_HEIGHT := 0.5
const ROPE_LINE := 3.1

## Game bone names, resolved by the controller: root, middle, end.
var chains := {
	"arm_l": ["upperarm_l", "lowerarm_l", "hand_l"],
	"arm_r": ["upperarm_r", "lowerarm_r", "hand_r"],
	"leg_l": ["thigh_l", "calf_l", "foot_l"],
	"leg_r": ["thigh_r", "calf_r", "foot_r"],
}

## Outward unit normal of the rope side he is reaching for, or ZERO.
var _side := Vector3.ZERO
var _chain := ""
var _ticks := 1
var _t := 0
var _weight := 0.0
var _holding := false
var _ids := {}


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for key: String in chains:
		_ids[key] = (chains[key] as Array).map(func(b: String) -> int: return sk.find_bone(b))


## Reach for the ropes on `side` (outward normal), arriving in `ticks`.
func reach(side: Vector3, ticks: int) -> void:
	_side = side
	_chain = ""
	_ticks = maxi(1, ticks)
	_t = 0
	_holding = true


func is_reaching() -> bool:
	return _weight > 0.0


## One physics tick; `hold` false lets go.
func advance(hold: bool) -> void:
	if not hold:
		_holding = false
	if _holding:
		_t = mini(_t + 1, _ticks)
		var s := float(_t) / _ticks
		_weight = s * s * (3.0 - 2.0 * s)
	elif _weight > 0.0:
		_weight = maxf(0.0, _weight - 1.0 / RELEASE_TICKS)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _weight <= 0.0 or _side == Vector3.ZERO:
		return
	var to_sk := sk.global_transform.affine_inverse()
	if _chain == "":
		_chain = _pick_chain(sk)
		if _chain == "":
			return
	var ids: Array = _ids[_chain]
	if ids.has(-1):
		return
	var root_world := sk.global_transform * sk.get_bone_global_pose(ids[0]).origin
	var rope := _rope_point(root_world)
	var end := sk.get_bone_global_pose(ids[2])
	var target := Transform3D(end.basis, end.origin.lerp(to_sk * rope, _weight))
	FootPlant._solve_leg(sk, ids, target)


## The limb whose root is nearest the rope.
func _pick_chain(sk: Skeleton3D) -> String:
	var best := ""
	var best_d := INF
	for key: String in _ids:
		var ids: Array = _ids[key]
		if ids.has(-1):
			continue
		var root := sk.global_transform * sk.get_bone_global_pose(ids[0]).origin
		var d := root.distance_to(_rope_point(root))
		if d < best_d:
			best_d = d
			best = key
	return best


## Nearest point of the bottom rope on this side to `p` (world).
func _rope_point(p: Vector3) -> Vector3:
	var q := p
	if _side.x != 0.0:
		q.x = _side.x * ROPE_LINE
	else:
		q.z = _side.z * ROPE_LINE
	q.y = ROPE_HEIGHT
	return q
