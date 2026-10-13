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
}
var wrestler: Node3D
var weapon: WeaponActor = null
var _ids := {}
var _carry := 0.0
var _two := 0.0


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for key: String in bones:
		_ids[key] = sk.find_bone(bones[key])


## One physics tick: `carrying` while he stands or moves with it (not mid
## swing, not mid throw), so the carry pose lets the swing clip have the arm.
func advance(carrying: bool) -> void:
	var holding := weapon != null and weapon.mode == WeaponActor.Mode.HELD
	var has_carry := holding and not (WeaponCatalog.CARRY.get(String(weapon.def.id), []) as Array).is_empty()
	_carry = move_toward(_carry, 1.0 if holding and carrying and has_carry else 0.0, 1.0 / EASE_TICKS)
	var want_two := holding and weapon.def.two_handed
	_two = move_toward(_two, 1.0 if want_two else 0.0, 1.0 / EASE_TICKS)


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or wrestler == null or weapon == null or weapon.mode != WeaponActor.Mode.HELD:
		return
	for key: String in _ids:
		if int(_ids[key]) < 0:
			return
	var to_sk := sk.global_transform.affine_inverse()
	var fwd := (to_sk.basis * -wrestler.global_transform.basis.z).normalized()
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
	weapon.global_transform = placed
	if _carry > 0.0:
		# his right hand onto its grip, the fist turned to it
		_hand_to(sk, ["upperarm_r", "lowerarm_r", "hand_r"], to_sk * weapon.global_marker("grip_r"), fwd, _carry)
	if _two > 0.0:
		_hand_to(sk, ["upperarm_l", "lowerarm_l", "hand_l"], to_sk * weapon.global_marker("grip_l"), fwd, _two)


## Reaches `chain`'s hand to `target` (skeleton space): the arm by the
## two-bone solve, then the hand turned so its knuckle line runs along the
## grip's +Y. Weighted by `weight` (eased).
func _hand_to(sk: Skeleton3D, chain: Array, target: Transform3D, fwd: Vector3, weight: float) -> void:
	var w := weight * weight * (3.0 - 2.0 * weight)
	var ids := [_ids[chain[0]], _ids[chain[1]], _ids[chain[2]]]
	var hand := sk.get_bone_global_pose(ids[2])
	FootPlant._solve_leg(sk, ids, Transform3D(hand.basis, hand.origin.lerp(target.origin, w)), fwd)
	if chain[2] != "hand_r":
		return
	# Turn the fist onto the grip: the rotation taking the hand's grip frame
	# (knuckle line, back of the hand) to the weapon's grip_r marker.
	var s := sk.global_basis.orthonormalized()
	var want := s * target.basis.orthonormalized()
	var have := WeaponActor.grip_frame(wrestler).basis.orthonormalized()
	var turn := Quaternion.IDENTITY.slerp((want * have.inverse()).get_rotation_quaternion(), w)
	var turn_sk := s.inverse() * Basis(turn) * s
	var hg := sk.get_bone_global_pose(ids[2])
	var parent := sk.get_bone_parent(ids[2])
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	sk.set_bone_pose_rotation(ids[2], (pg.basis.orthonormalized().inverse()
			* (turn_sk * hg.basis.orthonormalized())).get_rotation_quaternion())
