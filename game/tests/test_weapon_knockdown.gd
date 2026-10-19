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
