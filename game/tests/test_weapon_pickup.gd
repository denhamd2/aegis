extends GdUnitTestSuite
## Picking a weapon up off the floor (weapon animation plan, phase 2): he steps
## to it, the lift fits what it is, his hands close on its grips where it lies,
## and it leaves the floor from where it lay -- it never jumps into his hand.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")
## Palm to grip the tick before the take. A centimetre looser than a held
## weapon's 3: the take eases the weapon into the fist over LIFT_TICKS, which
## closes the last of it as the lift, not as a jump.
const CONTACT_M := 0.04
## The most the weapon may move per tick across the take: a lift, not a jump
## (a jump was 30 cm to over a metre in a tick).
const TAKE_MOVE_M := 0.03
## The palm, read the same way as the grip-contact gate reads it.
const PALM := preload("res://tests/test_weapon_grip_contact.gd")


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


func test_the_lift_fits_the_weapon() -> void:
	assert_str(WeaponCatalog.pickup_action(WeaponCatalog.by_id(&"frying_pan"))).is_equal("pickup")
	assert_str(WeaponCatalog.pickup_action(WeaponCatalog.by_id(&"baseball_bat"))).is_equal("pickup_two")
	assert_str(WeaponCatalog.pickup_action(WeaponCatalog.by_id(&"steel_chair"))).is_equal("pickup_two")
	assert_str(WeaponCatalog.pickup_action(WeaponCatalog.by_id(&"steel_steps"))).is_equal("pickup_heavy")
	assert_str(WeaponCatalog.pickup_action(WeaponCatalog.by_id(&"briefcase"))).is_equal("pickup")
	for def: WeaponDef in WeaponCatalog.all():
		var action := WeaponCatalog.pickup_action(def)
		assert_bool(WrestlerController.WEAPON_ACTION_CLIPS.has(action)).is_true()


## [right-hand miss as it is taken, left-hand miss, how far it moved on the
## take, where he ended up from where the grip lay] for one weapon lying 0.85 m
## in front of him.
func _pickup(id: StringName) -> Array:
	var w: WrestlerController = WRESTLER_SCENE.instantiate()
	MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
	add_child(w)
	await _ticks(2)
	var def := WeaponCatalog.by_id(id)
	var a := WeaponStock.of(w).pull(def)
	a.global_position = w.global_position - w.global_basis.z * 0.85 + Vector3.UP * 0.3
	a.drop()
	await _ticks(60)
	var action := WeaponCatalog.pickup_action(def)
	var at := int(WrestlerController.WEAPON_ACTION_AT[action])
	var out := [0.0, 0.0, 0.0, 0.0]
	var before := [Vector3.ZERO]
	var read := func() -> void:
		if w._weapon_action_ticks == at - 1:
			before[0] = a.global_position
			out[0] = PALM.palm(w, "r").distance_to(a.global_marker("grip_r").origin)
			if action != "pickup" and def.two_handed:
				out[1] = PALM.palm(w, "l").distance_to(a.global_marker("grip_l").origin)
		elif w._weapon_action_ticks == at + 1 and out[2] == 0.0:
			out[2] = a.global_position.distance_to(before[0]) / 2.0     # over two ticks
	w.skeleton.skeleton_updated.connect(read)
	w._weapon_target = a
	w.begin_weapon_action(action)
	await _ticks(int(WrestlerController.WEAPON_ACTION_TICKS[action]) + 2)
	w.skeleton.skeleton_updated.disconnect(read)
	assert_bool(w.has_weapon()).override_failure_message("%s was not picked up" % id).is_true()
	w.drop_weapon()
	a.queue_free()
	w.queue_free()
	await _ticks(1)
	return out


func test_his_hands_close_on_it_where_it_lies_and_it_does_not_jump() -> void:
	var report := []
	var bad := 0
	for id: StringName in [&"frying_pan", &"lead_pipe", &"baseball_bat", &"steel_chair",
			&"hockey_stick", &"trash_can", &"steel_steps", &"table", &"briefcase"]:
		var m: Array = await _pickup(id)
		var off: bool = m[0] > CONTACT_M or m[1] > CONTACT_M or m[2] > TAKE_MOVE_M
		if off:
			bad += 1
		report.append("%-14s hand r %4.1f l %4.1f cm, moved %4.1f cm a tick on the take%s" % [
				id, m[0] * 100, m[1] * 100, m[2] * 100, "  <--" if off else ""])
	print("\n".join(report))
	assert_int(bad).override_failure_message("\n".join(report)).is_equal(0)
