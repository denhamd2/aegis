class_name WeaponGrip
extends SkeletonModifier3D
## A weapon in his hands (No Holds Barred; gauntlet/refs/weapons_nhb.md).
##
## Runs after the animation and the other modifiers each frame:
##   - carrying (stood, walking, running) a two-handed weapon, his right hand
##     comes in front of his chest, so a chair or a can is held, not trailed;
##   - a two-handed weapon has his LEFT hand on its grip_l marker always --
##     through the carry and through every swing clip;
##   - then the weapon itself is put in the right hand (WeaponActor.follow_hand)
##     -- here, so it is where the hand is this frame, after every pose.
##
## FootPlant's two-bone solve, as SellClutch uses it. Presentation only: the
## match never reads anything back from here (ARCHITECTURE.md).

## Ticks the carry pose eases in and out over.
const EASE_TICKS := 10
## The carry: the right hand's target off the chest, in his own frame.
const CARRY_FORWARD := 0.34
const CARRY_DOWN := 0.16
const CARRY_RIGHT := 0.08

## Game bone names, resolved by the controller.
var bones := {
	"upperarm_r": "upperarm_r", "lowerarm_r": "lowerarm_r", "hand_r": "hand_r",
	"upperarm_l": "upperarm_l", "lowerarm_l": "lowerarm_l", "hand_l": "hand_l",
	"spine_03": "spine_03",
	"index_01_r": "index_01_r", "pinky_01_r": "pinky_01_r",
	"index_01_l": "index_01_l", "pinky_01_l": "pinky_01_l",
}
## Palm solves per hand: the arm is solved for the wrist, so the palm's miss
## is measured and the wrist target moved by it, until it is under this.
const PALM_TRIES := 3
const PALM_CLOSE := 0.004
const HAND_SEAT_EPSILON := 0.01
var wrestler: Node3D
var weapon: WeaponActor = null
var _ids := {}
var _carry := 0.0
## The take: the weapon eases from where it lay into the closed fist over
## LIFT_TICKS, the hand held on it, so whatever the reach left between palm
## and grip closes as a lift and never as a jump.
const LIFT_TICKS := 10
var _lift_from := Transform3D()
var _lift := 1.0
## The squat lift: a heavy thing comes up level, as it lay, carried up by the
## point between his hands -- it does not turn with his wrist (the steps, so
## turned, tipped in between his legs). Held level while _level_on (the lift
## action), then eased into the carry over EASE_TICKS.
var _level := 0.0
var _level_on := false
var _level_from := Transform3D()
var _level_mid := Vector3.INF
var _reach_target: WeaponActor = null
var _reach := 0.0
var _reach_both := false
var _two := 0.0
## The swing under way (WeaponCatalog.SWING_PATHS), where it is in it at this
## tick (-1: none), and how far one tick moves it.
var _path: Array = []
var _t := -1.0
var _dt := 0.0


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for key: String in bones:
		_ids[key] = sk.find_bone(bones[key])


## A pickup under way: his hands onto `target`'s grips where it lies on the
## floor, by `weight` (0-1, eased), the left as well when `both`. The right
## fist is turned to the grip as it lies, so on the take the weapon is in his
## hand where it already was. null ends it.
func reach(target: WeaponActor, weight: float, both: bool) -> void:
	_reach_target = target
	_reach = weight if target else 0.0
	_reach_both = both


## The weapon has just been taken off the floor from `from` (its transform
## where it lay): ease it into the hand from there (see LIFT_TICKS).
func lift_from(from: Transform3D) -> void:
	_lift_from = from
	_lift = 0.0


## A heavy thing just taken off the floor from `from`: lifted level (see
## _level). end_level() when the lift is done.
func lift_level(from: Transform3D) -> void:
	_level_from = from
	_level_on = true
	_level = 1.0
	_level_mid = Vector3.INF


func end_level() -> void:
	_level_on = false


## One physics tick: `carrying` while he stands or moves with it (not mid
## swing, not mid throw), so the carry pose lets the swing clip have the arm.
func advance(carrying: bool, path: Array = [], t := -1.0, dt := 0.0) -> void:
	_path = path
	_t = t
	_dt = dt
	var holding := weapon != null and weapon.mode == WeaponActor.Mode.HELD
	var has_carry := holding and not (WeaponCatalog.CARRY.get(String(weapon.def.id), []) as Array).is_empty()
	_carry = move_toward(_carry, 1.0 if holding and carrying and has_carry else 0.0, 1.0 / EASE_TICKS)
	# a one-hand carry gets its second hand only for the swing itself
	var swinging := not path.is_empty() and t >= 0.0
	_lift = minf(_lift + 1.0 / LIFT_TICKS, 1.0)
	if not _level_on:
		_level = move_toward(_level, 0.0, 1.0 / EASE_TICKS)
	var want_two := holding and weapon.def.two_handed \
			and (swinging or not weapon.def.id in WeaponCatalog.ONE_HAND_CARRY)
	_two = move_toward(_two, 1.0 if want_two else 0.0, 1.0 / EASE_TICKS)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or wrestler == null:
		return
	for key: String in _ids:
		if int(_ids[key]) < 0 and not key.contains("_01_"):   # fingers are optional
			return
	var to_sk := sk.global_transform.affine_inverse()
	var fwd := (to_sk.basis * -wrestler.global_transform.basis.z).normalized()
	if _reach > 0.0 and is_instance_valid(_reach_target):
		# the palm onto the grip without wrenching the wrist round to the way
		# the grip lies (for a thing flat on the floor that turn put the hand
		# out of reach): the take's lift turns the weapon into the fist instead
		_hand_to(sk, ["upperarm_r", "lowerarm_r", "hand_r"], to_sk * _reach_target.global_marker("grip_r"),
				fwd, _reach, false)
		if _reach_both and _reach_target.has_marker("grip_l"):
			_hand_to(sk, ["upperarm_l", "lowerarm_l", "hand_l"],
					to_sk * _reach_target.global_marker("grip_l"), fwd, _reach)
		return
	if weapon == null or weapon.mode != WeaponActor.Mode.HELD:
		return
	# Where the weapon goes: in the hand (as the clip has it), eased toward
	# its carry when he is just standing or moving with it.
	var in_hand := WeaponActor.grip_frame(wrestler) * weapon.marker("grip_r").affine_inverse()
	var placed := in_hand
	if _carry > 0.0:
		var w := _carry * _carry * (3.0 - 2.0 * _carry)
		var anchor := WeaponCatalog.carry_anchor(weapon.def)
		var carry: Array = WeaponCatalog.carry_transform(weapon.def, wrestler.global_transform,
				weapon.marker(anchor))
		if carry[1]:
			var c: Transform3D = carry[0]
			placed = Transform3D(in_hand.basis.slerp(c.basis.orthonormalized(), w).orthonormalized(),
					in_hand.origin.lerp(c.origin, w))
	var on_path := not _path.is_empty() and _t >= 0.0
	if on_path:
		var t := clampf(_t + _dt * Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
		placed = WeaponCatalog.path_transform(weapon, _path, _chest(sk), t, placed)
	if _level > 0.0:
		var mid := (_palm(sk, "r") + _palm(sk, "l")) * 0.5
		mid = sk.global_transform * mid
		if _level_mid == Vector3.INF:
			_level_mid = mid
		var level := Transform3D(_level_from.basis, _level_from.origin + (mid - _level_mid))
		var k := _level * _level * (3.0 - 2.0 * _level)
		placed = Transform3D(placed.basis.orthonormalized().slerp(level.basis.orthonormalized(), k),
				placed.origin.lerp(level.origin, k))
	var lifting := _lift < 1.0 or _level > 0.0
	if _lift < 1.0:
		var k := _lift * _lift * (3.0 - 2.0 * _lift)
		placed = Transform3D(_lift_from.basis.orthonormalized().slerp(placed.basis.orthonormalized(), k),
				_lift_from.origin.lerp(placed.origin, k))
	weapon.global_transform = placed
	if lifting:
		# the hand stays on it as it comes up into the fist
		_hand_to(sk, ["upperarm_r", "lowerarm_r", "hand_r"], to_sk * weapon.global_marker("grip_r"), fwd, 1.0)
	elif _carry > 0.0 or on_path:
		# his right hand onto its grip, the fist turned to it
		var hand_weight := 1.0 if on_path else _carry
		var left_weight := maxf(_two, _level)
		# The authored path describes where the strike lands. If its handle
		# targets are outside the arm chains' reach, translate the prop a little
		# toward the solved palms while preserving its orientation and strike
		# arc. Averaging both hands keeps long two-handed props centred instead
		# of fixing one wrist by pulling the other off its grip.
		for correction in (10 if on_path else 1):
			_hand_to(sk, ["upperarm_r", "lowerarm_r", "hand_r"],
					to_sk * weapon.global_marker("grip_r"), fwd, hand_weight)
			if left_weight > 0.0:
				_hand_to(sk, ["upperarm_l", "lowerarm_l", "hand_l"],
						to_sk * weapon.global_marker("grip_l"), fwd, left_weight)
			if not on_path:
				break
			var correction_world := sk.global_transform * _palm(sk, "r") \
					- weapon.global_marker("grip_r").origin
			var hands := 1.0
			if left_weight > 0.0 and weapon.has_marker("grip_l"):
				correction_world += sk.global_transform * _palm(sk, "l") \
						- weapon.global_marker("grip_l").origin
				hands += 1.0
			correction_world /= hands
			if correction_world.length() < HAND_SEAT_EPSILON:
				break
			weapon.global_position += correction_world * 0.85


## Reaches `chain`'s hand to `target` (skeleton space): its PALM onto the
## grip, not its wrist -- the two-bone solve places the hand bone's root, a
## hand's length short of where a handle sits in a fist (the weapon then hung
## 13 cm off every hand: test_weapon_grip_contact). So it solves, measures
## where the palm landed, moves the wrist target by the miss and solves again.
## The right fist is also turned so its knuckle line runs along the grip's +Y.
## Weighted by `weight` (eased).
func _hand_to(sk: Skeleton3D, chain: Array, target: Transform3D, fwd: Vector3, weight: float,
		turn := true) -> void:
	var w := weight * weight * (3.0 - 2.0 * weight)
	var ids := [_ids[chain[0]], _ids[chain[1]], _ids[chain[2]]]
	var side := "r" if chain[2] == "hand_r" else "l"
	var hand := sk.get_bone_global_pose(ids[2])
	var goal := _palm(sk, side).lerp(target.origin, w)
	var aim := hand.origin + (goal - _palm(sk, side))
	for i in PALM_TRIES:
		FootPlant._solve_leg(sk, ids, Transform3D(hand.basis, aim), fwd)
		if side == "r" and turn:
			_turn_fist(sk, ids[2], target, w)
		var miss := goal - _palm(sk, side)
		if miss.length() < PALM_CLOSE:
			break
		aim += miss


## The palm's centre in skeleton space: between wrist and knuckles, in from the
## back of the hand (WeaponActor.grip_frame's point, either hand).
func _palm(sk: Skeleton3D, side: String) -> Vector3:
	var hand := sk.get_bone_global_pose(_ids["hand_" + side]).origin
	var i := int(_ids.get("index_01_" + side, -1))
	var p := int(_ids.get("pinky_01_" + side, -1))
	if i < 0 or p < 0:
		return hand
	var index := sk.get_bone_global_pose(i).origin
	var pinky := sk.get_bone_global_pose(p).origin
	var knuckles := (index + pinky) * 0.5
	var fingers := (knuckles - hand).normalized()
	var across := (index - pinky).normalized() * (1.0 if side == "r" else -1.0)
	var back := fingers.cross(across).normalized()
	return knuckles - back * WeaponActor.PALM_IN + fingers * WeaponActor.PALM_TOWARD_FINGERS


## Turns the right fist onto the grip: the rotation taking the hand's grip
## frame (knuckle line, back of the hand) to the weapon's grip_r marker.
func _turn_fist(sk: Skeleton3D, bone: int, target: Transform3D, w: float) -> void:
	var s := sk.global_basis.orthonormalized()
	var want := s * target.basis.orthonormalized()
	var have := WeaponActor.grip_frame(wrestler).basis.orthonormalized()
	var turn := Quaternion.IDENTITY.slerp((want * have.inverse()).get_rotation_quaternion(), w)
	var turn_sk := s.inverse() * Basis(turn) * s
	var hg := sk.get_bone_global_pose(bone)
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	sk.set_bone_pose_rotation(bone, (pg.basis.orthonormalized().inverse()
			* (turn_sk * hg.basis.orthonormalized())).get_rotation_quaternion())


## His chest, in the world: at spine_03 as the clip moves it (the step in,
## the crouch), square to the way he faces. Swing paths ride this. Not the
## chest's own turn: the clips lean 30-45 degrees and twist 60 into a swing,
## and a path that leant with them would hit his own knees -- the path keys
## carry the turn themselves.
func _chest(sk: Skeleton3D) -> Transform3D:
	var g := sk.get_bone_global_pose(_ids["spine_03"])
	return Transform3D(wrestler.global_basis.orthonormalized(), sk.global_transform * g.origin)
