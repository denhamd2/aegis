extends GdUnitTestSuite
## Phase 4 reversals and stamina (gauntlet/refs/animation_gap.md): the window
## a strike can be read in, what a read costs, and the counter it plays.


func test_a_strike_can_be_read_from_just_before_its_window_to_its_end() -> void:
	var jab: MoveDef = load("res://resources/moves/strike_jab.tres")
	var opens := jab.reversal_window_start - WrestlerController.REVERSAL_LEAD
	assert_bool(WrestlerController.in_reversal_window(jab, opens - 1)).is_false()
	assert_bool(WrestlerController.in_reversal_window(jab, opens)).is_true()
	assert_bool(WrestlerController.in_reversal_window(jab, jab.reversal_window_end)).is_true()
	assert_bool(WrestlerController.in_reversal_window(jab, jab.reversal_window_end + 1)).is_false()


func test_a_move_with_no_window_cannot_be_read() -> void:
	var counter: MoveDef = WrestlerController.REVERSAL_MOVE
	for frame in range(0, counter.total_frames()):
		assert_bool(WrestlerController.in_reversal_window(counter, frame)).is_false()


func test_every_strike_carries_a_window_ending_by_its_last_contact_frame() -> void:
	for name in ["strike_jab", "strike_cross", "strike_kick", "strike_kick_heavy",
			"strike_bionic_elbow", "strike_dropdown_uppercut"]:
		var m: MoveDef = load("res://resources/moves/%s.tres" % name)
		assert_int(m.reversal_window_end).override_failure_message(name).is_greater(0)
		assert_int(m.reversal_window_end).override_failure_message(name) \
				.is_less_equal(m.startup_frames + m.active_frames)


func test_the_counter_lands_on_its_authored_contact_frame() -> void:
	# Parry_Counter's counter punch is keyed at frame 9 of 30 fps: tick 18.
	assert_int(WrestlerController.REVERSAL_MOVE.startup_frames).is_equal(18)
	assert_str(String(WrestlerController.REVERSAL_MOVE.animation_pair_id)).is_equal("strike_parry")


func test_stamina_is_spent_and_won_back_within_its_range() -> void:
	var c := CombatSystem.new()
	assert_float(c.stamina).is_equal(CombatSystem.STAMINA_MAX)
	c.spend_stamina(0.3)
	assert_float(c.stamina).is_equal_approx(0.7, 1e-6)
	c.spend_stamina(5.0)
	assert_float(c.stamina).is_equal(0.0)
	c.regen_stamina(5.0)
	assert_float(c.stamina).is_equal(CombatSystem.STAMINA_MAX)
