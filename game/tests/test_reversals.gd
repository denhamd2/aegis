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


func _reversal_pair(swapped: bool) -> Array[WrestlerController]:
	const WRESTLER := preload("res://scenes/wrestler.tscn")
	var a: WrestlerController = auto_free(WRESTLER.instantiate())
	var b: WrestlerController = auto_free(WRESTLER.instantiate())
	for wrestler: WrestlerController in [a, b]:
		add_child(wrestler)
		wrestler.set_physics_process(false)
		wrestler.is_ai = false
	var striker := b if swapped else a
	var defender := a if swapped else b
	striker.opponent = defender
	defender.opponent = striker
	striker.global_position = Vector3.ZERO
	defender.global_position = Vector3(0.0, 0.0, -0.75)
	return [striker, defender]


func test_read_jab_parries_real_contact_in_either_slot() -> void:
	var jab := load("res://resources/moves/strike_jab.tres") as MoveDef
	for swapped: bool in [false, true]:
		var pair := _reversal_pair(swapped)
		var striker := pair[0]
		var defender := pair[1]
		striker._start_move(WrestlerFSM.State.STRIKE, jab)
		for tick in jab.startup_frames:
			defender._read_reversal({"reversal": tick == jab.reversal_window_start - WrestlerController.REVERSAL_LEAD})
			striker._process_active_move({})
		var before := defender.combat.health()
		striker._process_active_move({})
		defender._resolve_reversible_contact()
		defender._resolve_pending_hits()
		assert_float(defender.combat.health()).is_equal(before)
		assert_int(defender.reversals_landed).is_equal(1)
		assert_object(defender._active_move).is_same(WrestlerController.REVERSAL_MOVE)
		assert_int(defender.fsm.current_state).is_equal(WrestlerFSM.State.STRIKE)


func test_read_does_not_transfer_to_a_restarted_jab() -> void:
	var pair := _reversal_pair(false)
	var striker := pair[0]
	var defender := pair[1]
	var jab := load("res://resources/moves/strike_jab.tres") as MoveDef
	striker._start_move(WrestlerFSM.State.STRIKE, jab)
	striker._move_ticks_remaining = jab.total_frames() - jab.startup_frames
	defender._read_reversal({"reversal": true})
	assert_object(defender._reversal_striker).is_same(striker)
	striker._start_move(WrestlerFSM.State.STRIKE, jab)
	striker._move_ticks_remaining = jab.total_frames() - jab.startup_frames
	striker._process_active_move({})
	defender._resolve_reversible_contact()
	defender._resolve_pending_hits()
	assert_int(defender.reversals_landed).is_equal(0)
	assert_int(defender.fsm.current_state).is_equal(WrestlerFSM.State.HIT_REACT)


func test_early_read_locks_out_a_second_attempt_and_hit_still_resolves() -> void:
	var pair := _reversal_pair(true)
	var striker := pair[0]
	var defender := pair[1]
	var jab := load("res://resources/moves/strike_jab.tres") as MoveDef
	striker._start_move(WrestlerFSM.State.STRIKE, jab)
	defender._read_reversal({"reversal": true})
	assert_int(defender._reversal_lockout).is_equal(WrestlerController.REVERSAL_LOCKOUT)
	var after_miss := defender.combat.stamina
	striker._move_ticks_remaining = jab.total_frames() - jab.startup_frames
	defender._read_reversal({"reversal": true})
	striker._process_active_move({})
	defender._resolve_reversible_contact()
	defender._resolve_pending_hits()
	assert_float(defender.combat.stamina).is_equal(after_miss)
	assert_int(defender.reversals_landed).is_equal(0)
	assert_int(defender.fsm.current_state).is_equal(WrestlerFSM.State.HIT_REACT)


## Close the same physics tick through the referee in both node orders. The
## last valid frame also catches using the already-incremented strike clock.
func test_contact_tick_read_parries_in_either_processing_order() -> void:
	var jab := load("res://resources/moves/strike_jab.tres") as MoveDef
	for swapped: bool in [false, true]:
		var pair := _reversal_pair(swapped)
		var striker := pair[0]
		var defender := pair[1]
		var referee: MatchReferee = auto_free(MatchReferee.new())
		referee.wrestler_a = defender if swapped else striker
		referee.wrestler_b = striker if swapped else defender
		striker._start_move(WrestlerFSM.State.STRIKE, jab)
		striker._move_ticks_remaining = jab.total_frames() - jab.reversal_window_end
		var health_before := defender.combat.health()
		if swapped:
			defender._read_reversal({"reversal": true})
			striker._process_active_move({})
		else:
			striker._process_active_move({})
			defender._read_reversal({"reversal": true})
		assert_int(defender.reversals_landed).is_equal(0)
		referee._resolve_tick()
		assert_int(defender.reversals_landed).is_equal(1)
		assert_float(defender.combat.health()).is_equal(health_before)
		assert_int(defender.strike_frame()).is_equal(0)
		assert_object(defender._active_move).is_same(WrestlerController.REVERSAL_MOVE)
		referee._resolve_tick()
		assert_int(defender.reversals_landed).is_equal(1)


func test_ai_reaction_uses_the_original_frame_after_contact_is_queued() -> void:
	var pair := _reversal_pair(false)
	var striker := pair[0]
	var defender := pair[1]
	var jab := load("res://resources/moves/strike_jab.tres") as MoveDef
	var ai := defender.ai
	ai.target = striker
	ai._reversal_decided = true
	ai._reversal_intent = true
	ai._reversal_roll_frame = jab.startup_frames
	striker._start_move(WrestlerFSM.State.STRIKE, jab)
	striker._move_ticks_remaining = jab.total_frames() - jab.startup_frames
	assert_bool(ai._roll_reversal()).is_true()
	striker._process_active_move({})
	assert_int(striker.strike_frame()).is_equal(jab.startup_frames + 1)
	assert_bool(ai._roll_reversal()).is_true()
