extends GdUnitTestSuite
## Weapon moves marked as heavy knockdowns must drop the victim on contact,
## rather than leaving him upright through a long strike reaction.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func _wrestler() -> WrestlerController:
	var victim: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(victim)
	await get_tree().physics_frame
	await get_tree().process_frame
	return victim


func test_bats_signs_tables_and_chairs_start_the_fall_immediately() -> void:
	for id in [&"baseball_bat", &"stop_sign", &"table", &"steel_chair"]:
		var victim := await _wrestler()
		var move := WeaponCatalog.swing_move(WeaponCatalog.by_id(id))
		assert_bool(move.leaves_defender_down).override_failure_message(String(id)).is_true()
		victim._pending_hits.append(move)
		victim._resolve_pending_hits()
		assert_bool(victim._bumping).override_failure_message(String(id)).is_true()
		assert_int(victim.fsm.current_state).override_failure_message(String(id)) \
				.is_equal(WrestlerFSM.State.HIT_REACT)


func test_light_sheet_hit_remains_a_stagger_not_a_forced_knockdown() -> void:
	var victim := await _wrestler()
	var move := WeaponCatalog.swing_move(WeaponCatalog.by_id(&"cookie_sheet"))
	assert_bool(move.leaves_defender_down).is_false()
	victim._pending_hits.append(move)
	victim._resolve_pending_hits()
	assert_bool(victim._bumping).is_false()
	assert_int(victim.fsm.current_state).is_equal(WrestlerFSM.State.HIT_REACT)


## In proportion to the weapon (gauntlet/refs/nhb/weapon_review.md; the owner,
## 19 Oct): not every weapon from a frying pan to the steel steps drops him
## the same way.
func test_each_weapon_lands_in_proportion_to_what_it_is() -> void:
	var tier := func(id: StringName) -> int:
		return WeaponCatalog.impact_of(WeaponCatalog.by_id(id))
	assert_int(tier.call(&"inflatable_banana")).is_equal(WeaponCatalog.Impact.LIGHT)
	assert_int(tier.call(&"frying_pan")).is_equal(WeaponCatalog.Impact.ROCK)
	assert_int(tier.call(&"kendo_stick")).is_equal(WeaponCatalog.Impact.ROCK)
	assert_int(tier.call(&"steel_chair")).is_equal(WeaponCatalog.Impact.DROP)
	assert_int(tier.call(&"baseball_bat")).is_equal(WeaponCatalog.Impact.DROP)
	assert_int(tier.call(&"lead_pipe")).is_equal(WeaponCatalog.Impact.DROP)
	assert_int(tier.call(&"barbed_wire_chair")).is_equal(WeaponCatalog.Impact.DROP)
	assert_int(tier.call(&"sledgehammer")).is_equal(WeaponCatalog.Impact.WIPEOUT)
	assert_int(tier.call(&"steel_steps")).is_equal(WeaponCatalog.Impact.WIPEOUT)
	assert_int(tier.call(&"rpg")).is_equal(WeaponCatalog.Impact.WIPEOUT)
	assert_int(tier.call(&"knife")).is_equal(WeaponCatalog.Impact.BLADE)
	assert_int(tier.call(&"sword")).is_equal(WeaponCatalog.Impact.BLADE)
	assert_int(tier.call(&"handgun")).is_equal(WeaponCatalog.Impact.FATAL)
	# only what should drop him on its own does
	assert_bool(WeaponCatalog.swing_move(WeaponCatalog.by_id(&"frying_pan")).leaves_defender_down).is_false()
	assert_bool(WeaponCatalog.swing_move(WeaponCatalog.by_id(&"lead_pipe")).leaves_defender_down).is_true()
	# and the heaviest keep him down longest
	assert_float(float(WeaponCatalog.IMPACT_DOWN_SCALE[WeaponCatalog.Impact.WIPEOUT])) \
			.is_greater(float(WeaponCatalog.IMPACT_DOWN_SCALE[WeaponCatalog.Impact.DROP]))


## Put down by a weapon, he stays down for the man who did it to play to the
## crowd (the owner, 20 Oct: the victim was up and attacking him mid-pose).
## No quick rise -- automatic, mashed or fired up -- inside the hold, which is
## longer than any taunt, and longer for the heavier weapons.
func test_a_weapon_victim_stays_down_through_the_attackers_taunt() -> void:
	var longest_taunt := 0
	for t: Array in WrestlerController.TAUNTS.values():
		longest_taunt = maxi(longest_taunt, int(t[1]))
	assert_int(int(WrestlerController.WEAPON_DOWN_HOLD[WeaponCatalog.Impact.DROP])) \
			.is_greater(longest_taunt)
	assert_int(int(WrestlerController.WEAPON_DOWN_HOLD[WeaponCatalog.Impact.WIPEOUT])) \
			.is_greater(int(WrestlerController.WEAPON_DOWN_HOLD[WeaponCatalog.Impact.DROP]))
	for id: StringName in [&"steel_chair", &"sledgehammer"]:
		var victim := await _wrestler()
		victim._pending_hits.append(WeaponCatalog.swing_move(WeaponCatalog.by_id(id)))
		victim._resolve_pending_hits()
		var guard := 0
		while victim.fsm.current_state != WrestlerFSM.State.DOWN and guard < 200:
			victim._physics_process(1.0 / 60.0)
			guard += 1
		assert_int(victim.fsm.current_state).override_failure_message(String(id)) \
				.is_equal(WrestlerFSM.State.DOWN)
		var impact := WeaponCatalog.impact_of(WeaponCatalog.by_id(id))
		assert_int(victim.weapon_down_impact).is_equal(impact)
		# mashing the whole time, and fired up for good measure
		var hold := int(WrestlerController.WEAPON_DOWN_HOLD[impact])
		for i in hold - 2:
			victim._process_down({"strike": true})
		assert_int(victim.fsm.current_state).override_failure_message(
				"%s rose inside the hold" % id).is_equal(WrestlerFSM.State.DOWN)
