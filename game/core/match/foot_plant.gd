class_name FootPlant
extends SkeletonModifier3D
## Feet that step instead of skating (gauntlet/refs/animation_gap.md, Phase 2
## "walk-in").
##
## Before a paired move GrappleRig carries both men from where they stood into
## the places the move starts from. Measured over four seeded matches that is
## a median 0.41 m and up to 1.5 m, turning up to 124 degrees, and it used to
## happen in a sixth of a second with the feet glued to the hold pose: two men
## gliding across the canvas on rails. It happens in every direction -- a
## running move backs the attacker off 0.6-0.7 m straight BEHIND him, the
## defender is often drawn sideways -- and the rig has one forward step clip,
## so no clip can cover it. This does it procedurally instead:
##
##   * each foot is PLANTED in the world and stays there while the body moves
##     over it (two-bone IK on thigh -> calf -> foot);
##   * the feet take turns to STEP: a scheduled swing lifts one foot off its
##     plant and sets it down where the animation now wants it, the leading
##     foot first;
##   * the last step lands as the walk-in ends, so both feet are back on the
##     animated pose when the paired clip takes over.
##
## Presentation only: it moves three bones per leg on the model and reads
## nothing back into the match, so the replay hash cannot see it
## (ARCHITECTURE.md's cosmetic-systems rule).

## The most one foot travels in one step. A set-up step is short and quick,
## and past this the stance leg cannot reach the body moving over it.
const MAX_STRIDE := 0.40
## A foot displaced less than this does not step at all -- the IK carries it.
const MIN_STEP := 0.05
## A swing shorter than this many ticks is a flicker, not a step.
const MIN_SWING_TICKS := 5
## Peak lift of a swinging foot. A shuffle keeps its feet low.
const LIFT := 0.08
## The share of a swing spent lifting off before the foot travels, and again
## setting down after it arrives.
const PEEL := 0.2
## How far in front of the clip's knee the IK pole sits, metres: a tie-break
## for a near-straight leg, not a new bend -- at 0.3 the knee swung off the
## clip's line whenever a lock engaged mid-stride.
const POLE_REACH := 0.05
## Ticks to hand the feet back to the animation after the walk-in.
const RELEASE_TICKS := 6

## Game bone names, resolved by the controller (a model can rename them).
var legs: Array = [
	["thigh_l", "calf_l", "foot_l"],
	["thigh_r", "calf_r", "foot_r"],
]

var _ids: Array = []            # [[thigh, calf, foot], ...] bone indices
var _active := false
var _tick := 0
var _ticks := 0
var _swings := 0
var _first := 0
var _release := 0
var _plant: Array = [Transform3D(), Transform3D()]      # world, per foot
var _lift_from: Array = [Transform3D(), Transform3D()]  # world, swing start
var _swinging: Array = [false, false]


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for leg: Array in legs:
		var ids := []
		for bone: String in leg:
			ids.append(sk.find_bone(bone))
		if ids.has(-1):
			_ids.clear()
			return
		_ids.append(ids)


func is_walking() -> bool:
	return _active


## Starts a walk-in: the body will be carried from `from` to `to` (world) over
## `ticks` physics ticks. Plants both feet where they are and works out how
## many steps it takes. `end_feet`, when given, is where each foot must be at
## the end in the body's own frame -- the stance of the pose the walk-in
## blends into, which is not the one the feet are in now.
func begin(from: Transform3D, to: Transform3D, ticks: int, end_feet := []) -> void:
	var sk := get_skeleton()
	if sk == null or _ids.size() != 2 or ticks <= 0:
		return
	var travel := to.origin - from.origin
	travel.y = 0.0
	var widest := 0.0
	var lead := [0.0, 0.0]
	for side in 2:
		var foot := sk.global_transform * sk.get_bone_global_pose(_ids[side][2])
		_plant[side] = foot
		_swinging[side] = false
		# Where this foot must end up, as the animation now holds it.
		var home_end: Vector3 = to * (end_feet[side] if end_feet.size() == 2
				else from.affine_inverse() * foot.origin)
		var moved := home_end - foot.origin
		moved.y = 0.0
		widest = maxf(widest, moved.length())
		lead[side] = (foot.origin - from.origin).dot(travel.normalized()) \
				if travel.length() > MIN_STEP else moved.length()
	_first = 0 if lead[0] >= lead[1] else 1
	_swings = 0
	if widest > MIN_STEP:
		_swings = 2 * int(ceil(widest / MAX_STRIDE))
		var most := maxi(2, (ticks / MIN_SWING_TICKS) & ~1)
		_swings = mini(_swings, most)
	_ticks = ticks
	_tick = 0
	_release = 0
	_active = true


## One physics tick of the walk-in. GrappleRig's presentation tick calls this
## (through WrestlerController) while it carries the body.
func advance() -> void:
	if _active:
		_tick += 1
		if _tick >= _ticks:
			_active = false
			_release = RELEASE_TICKS
	elif _release > 0:
		_release -= 1


func _process_modification() -> void:
	if not _active and _release <= 0:
		return
	var sk := get_skeleton()
	if sk == null or _ids.size() != 2:
		return
	var weight := 1.0 if _active else float(_release) / float(RELEASE_TICKS)
	var span := float(_ticks) / float(maxi(_swings, 1))
	var now := float(_tick) + Engine.get_physics_interpolation_fraction()
	for side in 2:
		var home := sk.global_transform * sk.get_bone_global_pose(_ids[side][2])
		var want: Transform3D = _plant[side]
		if _active and _swings > 0:
			# Which swing is under way, and is it this foot's?
			var i := mini(int(now / span), _swings - 1)
			var mine := (i % 2 == 0) == (side == _first)
			if mine:
				if not _swinging[side]:
					_swinging[side] = true
					_lift_from[side] = _plant[side]
				var s := clampf((now - i * span) / span, 0.0, 1.0)
				# Up, across, down: the foot clears the mat before it travels
				# and is over its mark before it lands, as a real step peels
				# off the heel -- travelling from the first tick drags the toe
				# along the canvas for the first and last few centimetres.
				var h := clampf((s - PEEL) / (1.0 - 2.0 * PEEL), 0.0, 1.0)
				var e := h * h * (3.0 - 2.0 * h)
				var from: Transform3D = _lift_from[side]
				want = GrappleRig.blend_transforms(from, home, e)
				want.origin += Vector3.UP * LIFT * sin(PI * s)
				_plant[side] = want if s < 1.0 else home
			elif _swinging[side]:
				# Its swing just ended: it lands where the animation wanted it.
				_swinging[side] = false
				_plant[side] = home
				want = home
		elif not _active:
			want = _plant[side]
		var target := GrappleRig.blend_transforms(home, want, weight)
		_solve_leg(sk, _ids[side], sk.global_transform.affine_inverse() * target)


## Where `anim` puts each foot on its first frame, in skeleton space: forward
## kinematics over the clip's own tracks, rest pose where it has none. For
## planning the steps into a pose before it is on screen.
func first_frame_feet(anim: Animation) -> Array:
	var sk := get_skeleton()
	if sk == null or _ids.size() != 2 or anim == null:
		return []
	var tracks := {}
	for t in anim.get_track_count():
		var bone := String(anim.track_get_path(t).get_concatenated_subnames())
		if bone != "":
			tracks["%s/%d" % [bone, anim.track_get_type(t)]] = t
	var out := []
	for side in 2:
		var chain := []
		var b: int = _ids[side][2]
		while b >= 0:
			chain.push_front(b)
			b = sk.get_bone_parent(b)
		var g := Transform3D.IDENTITY
		for bone: int in chain:
			var rest := sk.get_bone_rest(bone)
			var bone_name := sk.get_bone_name(bone)
			var pos := rest.origin
			var rot := rest.basis.get_rotation_quaternion()
			var scl := rest.basis.get_scale()
			var key := "%s/%d" % [bone_name, Animation.TYPE_POSITION_3D]
			if tracks.has(key):
				pos = anim.position_track_interpolate(tracks[key], 0.0)
			key = "%s/%d" % [bone_name, Animation.TYPE_ROTATION_3D]
			if tracks.has(key):
				rot = anim.rotation_track_interpolate(tracks[key], 0.0)
			key = "%s/%d" % [bone_name, Animation.TYPE_SCALE_3D]
			if tracks.has(key):
				scl = anim.scale_track_interpolate(tracks[key], 0.0)
			g = g * Transform3D(Basis(rot).scaled_local(scl), pos)
		out.append(g.origin)
	return out


## Two-bone IK in skeleton space: thigh and calf turn so the ankle lands on
## `target`, the knee toward a POLE -- where the clip has the knee, pushed
## `forward` (skeleton space) -- and the foot takes the target's orientation.
##
## It used to bend in the leg's current plane, (knee - hip) x (ankle - hip).
## A leg near straight has almost no plane, and the knee flipped side to side
## from one tick to the next: the calves were the bones that kicked hardest in
## tools/probe/transition_pops.tscn --world once FootLock had the legs.
static func _solve_leg(sk: Skeleton3D, ids: Array, target: Transform3D,
		forward := Vector3.ZERO) -> void:
	var tg := sk.get_bone_global_pose(ids[0])
	var cg := sk.get_bone_global_pose(ids[1])
	var fg := sk.get_bone_global_pose(ids[2])
	var h := tg.origin
	var k := cg.origin
	var a := fg.origin
	var l1 := h.distance_to(k)
	var l2 := k.distance_to(a)
	var to := target.origin - h
	if l1 < 1e-4 or l2 < 1e-4 or to.length() < 1e-4:
		return
	var d := clampf(to.length(), absf(l1 - l2) + 1e-3, (l1 + l2) * 0.999)
	var dir := to.normalized()
	var perp := Vector3.ZERO
	if forward != Vector3.ZERO:
		var pole := k + forward.normalized() * POLE_REACH - h
		perp = pole - dir * pole.dot(dir)
	if perp.length() < 1e-4:
		var n := (k - h).cross(a - h)
		if n.length() < 1e-6:
			n = tg.basis.x
		perp = dir.cross(n.normalized())
	perp = perp.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var knee := h + dir * l1 * cos_a + perp * l1 * sqrt(1.0 - cos_a * cos_a)
	var r1 := Quaternion((k - h).normalized(), (knee - h).normalized())
	var a1 := h + r1 * (a - h)
	var ankle := h + dir * d
	var r2 := Quaternion((a1 - knee).normalized(), (ankle - knee).normalized())
	sk.set_bone_global_pose(ids[0], Transform3D(Basis(r1) * tg.basis, h))
	sk.set_bone_global_pose(ids[1], Transform3D(Basis(r2 * r1) * cg.basis, knee))
	# The foot's orientation from the target, at the scale the bone already has.
	var scale := fg.basis.get_scale()
	sk.set_bone_global_pose(ids[2], Transform3D(
			target.basis.orthonormalized().scaled_local(scale), ankle))
