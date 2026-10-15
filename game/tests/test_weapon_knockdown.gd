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
