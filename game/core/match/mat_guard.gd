class_name MatGuard
extends SkeletonModifier3D
## No hand, foot, finger or toe through the canvas.
##
## The paired clips are authored and linted on the base mannequin
## (tests/test_pose_lint.gd keeps them above the mat there). On the roster's
## own bodies -- longer arms, other proportions -- a thrown man landing with a
## hand flat on the mat put it under the canvas: tools/probe/move_qa --roster
## measured Cody's right thumb up to 0.29 m down, and the ball of a foot in
## places, on 29 of 47 paired moves.
##
## Each limb is checked once the rest of the stack has posed it: the lowest
## point of the hand or foot and everything under it (fingers, toes). Below the
## mat, the whole limb swings up about its shoulder or hip, the least turn that
## puts that point back on the surface. The lift grows with the penetration and
## goes with it, so there is nothing to pop.
##
## Only inside the ring, over the canvas: on the floor or the apron there is
## no canvas under him. Presentation only (ARCHITECTURE.md): bones on the
## model, nothing read back into the match.

## The canvas top in the world, and the deepest a joint may sit under it: a
## toe or knuckle a centimetre or two into the canvas is the canvas giving
## under a planted foot, and a guard at the surface itself would lift every
## standing leg off FootPlant's plant.
const MAT_Y := 0.0
const GIVE := 0.02
## The deck at mat height: the canvas (RingBuilder.MAT_HALF, 3.0) and the
## apron round it (RingBuilder.APRON_OUT, 3.2). A point past it is over the
## floor, with nothing to go through. Checked per point, not per body: a man
## thrown into the ropes lies half on the deck.
const DECK_HALF := 3.2
## A body below this is off the ring, on the floor.
const ON_RING_Y := -0.2
## How finely a swing is searched: steps each way out to a quarter turn.
const SWING_STEPS := 18

## Game bone names (resolved by the controller): limb root, the joint in the
## middle (the elbow or knee is a point that can go under too), the end.
var chains := [
	["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"],
	["thigh_l", "calf_l", "foot_l"], ["thigh_r", "calf_r", "foot_r"],
]
var wrestler: Node3D
## Lifts applied, for the probes.
var lifts := 0

var _roots: Array[int] = []
var _mids: Array[int] = []
var _points: Array[PackedInt32Array] = []
## The points under the elbow or knee: what a bend there can move.
var _mid_points: Array[PackedInt32Array] = []


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for chain: Array in chains:
		var root := sk.find_bone(chain[0])
		var mid := sk.find_bone(chain[1])
		var end := sk.find_bone(chain[2])
		if root < 0 or mid < 0 or end < 0:
			continue
		# Everything under the shoulder or hip, not only under the hand or
		# foot: a rig's helper bones hang off the limb where they like (Roman's
		# H_Toe_* are not under his foot bone, and were the last toes left in
		# the mat).
		var points := PackedInt32Array()
		_collect(sk, root, points)
		var below_mid := PackedInt32Array()
		_collect(sk, mid, below_mid)
		_roots.append(root)
		_mids.append(mid)
		_points.append(points)
		_mid_points.append(below_mid)


## Every bone under `bone` that has skin: finger and toe joints, not the
## importer's end markers (*_leaf, *_stub), which are points past the tip.
static func _collect(sk: Skeleton3D, bone: int, into: PackedInt32Array) -> void:
	for c in sk.get_bone_children(bone):
		var n := sk.get_bone_name(c)
		if not (n.contains("leaf") or n.ends_with("_stub")):
			into.append(c)
		_collect(sk, c, into)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _roots.is_empty():
		return
	var at := wrestler.global_position if wrestler else sk.global_position
	if at.y < ON_RING_Y:
		return
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var up := (inv.basis * Vector3.UP).normalized()
	var side := (inv.basis * (wrestler.global_basis.x if wrestler else Vector3.RIGHT)).normalized()
	for i in _roots.size():
		# The shoulder or hip first; if that joint is itself too low to swing
		# the limb clear, the elbow or knee bends it the rest of the way.
		for pass_i in 2:
			var joint := _roots[i] if pass_i == 0 else _mids[i]
			var moved := _points[i] if pass_i == 0 else _mid_points[i]
			var low := _lowest(sk, xf, _points[i])
			if low == Vector3.INF or (xf * low).y >= MAT_Y - GIVE:
				break
			if pass_i == 1:
				low = _lowest(sk, xf, moved)
				if low == Vector3.INF:
					break
			if _swing_clear(sk, xf, joint, moved, low, up, side):
				lifts += 1


## Turns `joint` (its whole limb below with it) about the axis that swings
## `low` straight up, by the least angle that puts every one of `moved` on
## the limit. Every point, not only the lowest: on a shoulder lying on the mat
## with the forearm folded back under it (Cody's landing on Dragon Twist
## Cutter), the turn that lifts the hand drives the elbow 4 cm into the canvas.
## Searched both ways in 5 degree steps out to a quarter turn, then bisected;
## when nothing clears, the turn that leaves the limb highest. True when it
## turned.
func _swing_clear(sk: Skeleton3D, xf: Transform3D, joint: int, moved: PackedInt32Array,
		low: Vector3, up: Vector3, side: Vector3) -> bool:
	var pose := sk.get_bone_global_pose(joint)
	var pivot := pose.origin
	var from := low - pivot
	if from.length() < 1e-4:
		return false
	var axis := from.cross(up)
	if axis.length() < 1e-3 * from.length():
		# Straight down: swing it forward, about the body's own side axis.
		axis = side
	axis = axis.normalized()
	var limit := MAT_Y - GIVE
	var rel: Array[Vector3] = []
	for b in moved:
		rel.append(sk.get_bone_global_pose(b).origin - pivot)
	# The lowest of the limb's points over the deck, the limb turned by `angle`.
	var floor_at := func(angle: float) -> float:
		var r := Basis(axis, angle)
		var y := INF
		for v: Vector3 in rel:
			var w := xf * (pivot + r * v)
			if absf(w.x) > DECK_HALF or absf(w.z) > DECK_HALF:
				continue
			y = minf(y, w.y)
		return y
	var start: float = floor_at.call(0.0)
	if start >= limit:
		return false
	var step := PI * 0.5 / SWING_STEPS
	var best := 0.0
	var best_y := start
	for k in range(1, SWING_STEPS + 1):
		for sgn: float in [1.0, -1.0]:
			var a := sgn * k * step
			var y: float = floor_at.call(a)
			if y >= limit:
				var lo := sgn * (k - 1) * step
				var hi := a
				for _i in 8:
					var mid := (lo + hi) * 0.5
					if floor_at.call(mid) >= limit:
						hi = mid
					else:
						lo = mid
				_turn(sk, joint, pose, Basis(axis, hi))
				return true
			if y > best_y:
				best_y = y
				best = a
	if best == 0.0:
		return false
	_turn(sk, joint, pose, Basis(axis, best))
	return true


static func _turn(sk: Skeleton3D, joint: int, pose: Transform3D, by: Basis) -> void:
	sk.set_bone_global_pose(joint, Transform3D(by * pose.basis, pose.origin))


## The lowest of `points` over the deck, returned in skeleton space, or INF
## when none is over it.
static func _lowest(sk: Skeleton3D, xf: Transform3D, points: PackedInt32Array) -> Vector3:
	var best := Vector3.INF
	var best_y := INF
	for b in points:
		var p := sk.get_bone_global_pose(b).origin
		var w := xf * p
		if absf(w.x) > DECK_HALF or absf(w.z) > DECK_HALF:
			continue
		if w.y < best_y:
			best_y = w.y
			best = p
	return best
