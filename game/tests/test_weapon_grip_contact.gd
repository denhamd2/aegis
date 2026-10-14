extends GdUnitTestSuite
## Hands on the weapon (weapon animation plan, phase 1): for every weapon,
## carried and through its whole swing, the right palm is on its grip_r and --
## for a two-handed weapon -- the left palm on its grip_l. A hand that misses
## its grip by more than CONTACT_M is a weapon floating beside a fist, which
## is the defect this gate exists for.
##
## Measured palm to marker, not wrist to marker: the wrist is the hand bone's
## root, a hand's width from where a handle sits in it.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")
const CONTACT_M := 0.03
## Swings whose left hand still comes off the handle at full extension, and
## by how much (m) at worst: the old shared baseball swing reaching past the
## arm. Phase 3 (a swing per real motion) re-authors every one of these and
## empties this list; until then a weapon may not get WORSE than its entry,
## and nothing new may join it.
const KNOWN_SWING_SLIPS := {
	&"kendo_stick": 0.14,
	&"board_with_nails": 0.07, &"shovel": 0.16, &"hockey_stick": 0.10, &"crutch": 0.07,
	&"inflatable_banana": 0.07, &"trash_can": 0.15, &"light_tubes": 0.06,
	&"barbed_wire_board": 0.71, &"ring_bell": 0.08, &"frying_pan": 0.06,
	# the overhead slam and the thrust with wide things (phase 3), the spray (4)
	&"steel_steps": 0.12, &"championship_belt": 0.12, &"briefcase": 0.40, &"table": 0.36,
	&"ladder": 0.68, &"fire_extinguisher": 0.42,
}
## Carries a hand cannot quite close on, by how much: the folded table's far
## corner sits at the very end of his left arm's reach (4 cm at every carry
## height and distance tried). Phase 2's two-hand lift revisits it.
const KNOWN_CARRY_SLIPS := {&"table": 0.05}
## Ticks to let the carry settle before measuring it.
const SETTLE := 24


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		await get_tree().process_frame


## The palm's centre: between the wrist and the knuckles, in from the back of
## the hand -- either hand.
static func palm(w: WrestlerController, side: String) -> Vector3:
	var hand: Vector3 = w._bone_world("hand_" + side)
	var index: Vector3 = w._bone_world("index_01_" + side)
	var pinky: Vector3 = w._bone_world("pinky_01_" + side)
	var knuckles := (index + pinky) * 0.5
	var fingers := (knuckles - hand).normalized()
	var across := (index - pinky).normalized() * (1.0 if side == "r" else -1.0)
	var back := fingers.cross(across).normalized()
	return knuckles - back * WeaponActor.PALM_IN + fingers * WeaponActor.PALM_TOWARD_FINGERS


## [carry miss r, carry miss l, swing miss r, swing miss l] in metres for one
## weapon (l is 0 for a one-handed weapon). Read on the skeleton's
## skeleton_updated signal: the pose with every modifier applied, the weapon
## placed with it -- what is drawn, not what the animation alone said.
func _misses(id: StringName) -> Array:
	# One at a time, gone before the next: two men left standing on the same
	# spot shove each other about and every reading after the first is wrong.
	var w: WrestlerController = WRESTLER_SCENE.instantiate()
	MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
	add_child(w)
	await _ticks(2)
	var def := WeaponCatalog.by_id(id)
	var a := WeaponStock.of(w).pull(def)
	var out := [0.0, 0.0, 0.0, 0.0]
	var phase := [-1]          # -1 settling, 0 carry, 2 swing
	var read := func() -> void:
		if phase[0] < 0 or not w.has_weapon():
			return
		out[phase[0]] = maxf(out[phase[0]], _miss(w, a, "r"))
		# the second hand is read once it has arrived: easing onto the handle
		# through the wind-up is the hand travelling, not a hand off it
		if def.two_handed and w.weapon_grip._two >= 0.999:
			out[phase[0] + 1] = maxf(out[phase[0] + 1], _miss(w, a, "l"))
	w.skeleton.skeleton_updated.connect(read)
	w.take_weapon(a)
	await _ticks(SETTLE)
	phase[0] = 0
	await _ticks(4)
	if def.swing != WeaponDef.Swing.POUR:
		phase[0] = 2
		var swing := WeaponCatalog.swing_move(def)
		w._play_strike_clip(swing)
		w._start_move(WrestlerFSM.State.STRIKE, swing)
		await _ticks(swing.total_frames())
	phase[0] = -1
	w.skeleton.skeleton_updated.disconnect(read)
	w.drop_weapon()
	a.queue_free()
	w.queue_free()
	await _ticks(1)
	return out


func _miss(w: WrestlerController, a: WeaponActor, side: String) -> float:
	return palm(w, side).distance_to(a.global_marker("grip_" + side).origin)


func test_every_hand_is_on_its_grip() -> void:
	var report := []
	var bad := 0
	for def: WeaponDef in WeaponCatalog.all():
		if def.glb == "":
			continue
		var m: Array = await _misses(def.id)
		var carry := maxf(m[0], m[1])
		var swing := maxf(m[2], m[3])
		var allowed := maxf(CONTACT_M, float(KNOWN_SWING_SLIPS.get(def.id, 0.0)))
		var off := carry > maxf(CONTACT_M, float(KNOWN_CARRY_SLIPS.get(def.id, 0.0))) or swing > allowed
		if off:
			bad += 1
		report.append("%-20s carry r %4.0f l %4.0f  swing r %4.0f l %4.0f cm%s" % [
			def.id, m[0] * 100, m[1] * 100, m[2] * 100, m[3] * 100, "  <--" if off else ""])
	print("\n".join(report))
	assert_int(bad).override_failure_message("%d weapons with a hand off its grip:\n%s" % [
			bad, "\n".join(report)]).is_equal(0)
