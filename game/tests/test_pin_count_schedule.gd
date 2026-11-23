extends GdUnitTestSuite
## The three-count's shape, pinned to gauntlet/refs/timings.md.
##
## Every number here is frame-stepped from one pinfall in
## wwe2k26_footage_02.mp4 (Byron Breakker vs Oba Femi, ~1093s), so this
## suite is what stops the count drifting off the only measurement of it
## the corpus has.

const TICKS_PER_SECOND := 60.0
## Onset-to-onset, measured: "1" -> "2" is ~1.25s and "2" -> "3" ~1.00s.
const MEASURED_SLAP_GAPS := [1.25, 1.00]
## Referee in position -> "1". The full cover -> "1" is 3.60s, but ~2.07s
## of that is the referee walking across the ring and this project has no
## referee actor, so a cover here starts where the footage has him already
## down. See match_referee.gd's COUNT_TICKS doc comment.
const MEASURED_LEAD_IN := 1.53
## On-screen duration of each digit: ~0.63-0.67s for "1", ~0.37-0.43s for
## "2". A count flashes and goes away rather than sitting there.
const MEASURED_VISIBLE := [0.65, 0.40]
## A frame of the 30fps source, either way, plus a tick of rounding.
const TOLERANCE := 0.05
const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")

func test_the_lead_in_matches_the_measured_one() -> void:
	assert_float(MatchReferee.COUNT_TICKS[0] / TICKS_PER_SECOND) \
		.is_equal_approx(MEASURED_LEAD_IN, TOLERANCE)

func test_the_slaps_land_on_the_measured_cadence() -> void:
	for i in MEASURED_SLAP_GAPS.size():
		var gap: float = (MatchReferee.COUNT_TICKS[i + 1] - MatchReferee.COUNT_TICKS[i]) \
			/ TICKS_PER_SECOND
		assert_float(gap).override_failure_message(
			"Slap %d to %d ran %f s against a measured %f s."
			% [i + 1, i + 2, gap, MEASURED_SLAP_GAPS[i]]
		).is_equal_approx(MEASURED_SLAP_GAPS[i], TOLERANCE)

## The count is uneven — the referee hangs on the first slap and speeds up
## into the third. An evenly-divided count is the one thing the reference
## says a three-count is not.
func test_the_count_is_not_evenly_spaced() -> void:
	var first: int = MatchReferee.COUNT_TICKS[1] - MatchReferee.COUNT_TICKS[0]
	var second: int = MatchReferee.COUNT_TICKS[2] - MatchReferee.COUNT_TICKS[1]
	assert_int(first).is_greater(second)

func test_each_digit_is_on_screen_for_the_measured_time() -> void:
	for i in MEASURED_VISIBLE.size():
		assert_float(MatchReferee.COUNT_VISIBLE_TICKS[i] / TICKS_PER_SECOND) \
			.is_equal_approx(MEASURED_VISIBLE[i], TOLERANCE)

## Each digit goes away before the next one arrives — a silent gap of
## ~0.55s in the footage. Without this the count reads as a number ticking
## over rather than three separate slaps.
func test_a_digit_clears_before_the_next_slap() -> void:
	for i in range(MatchReferee.COUNT_TICKS.size() - 1):
		assert_int(MatchReferee.COUNT_TICKS[i] + MatchReferee.COUNT_VISIBLE_TICKS[i]) \
			.is_less(MatchReferee.COUNT_TICKS[i + 1])

func test_the_fall_ends_on_the_third_slap() -> void:
	assert_int(MatchReferee.PIN_COUNT_TICKS).is_equal(MatchReferee.COUNT_TICKS[2])

## PinMinigame.PROGRESS_THRESHOLD is calibrated against how long a fall
## lasts: a longer count with an unchanged bar is a straightforwardly
## easier kickout. The two moved apart once already (the fall grew from 195
## ticks to the measured 227 and every kickout slid from after the second
## slap to before the first), so this guards the coupling rather than
## either number.
func test_the_kickout_bar_scales_with_the_fall() -> void:
	var expected := 12.0 * MatchReferee.PIN_COUNT_TICKS / 195.0
	assert_float(PinMinigame.PROGRESS_THRESHOLD).override_failure_message(
		"The fall is %d ticks but the kickout bar is %f, calibrated for a "
		% [MatchReferee.PIN_COUNT_TICKS, PinMinigame.PROGRESS_THRESHOLD]
		+ "195-tick fall at 12.0. Rescale it or kickouts move relative to "
		+ "the count."
	).is_equal_approx(expected, 0.5)


func _downed_pair() -> MatchReferee:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	referee.wrestler_a = auto_free(WRESTLER_SCENE.instantiate())
	referee.wrestler_b = auto_free(WRESTLER_SCENE.instantiate())
	add_child(referee.wrestler_a)
	add_child(referee.wrestler_b)
	referee.wrestler_a.position = Vector3(0.55, 0.0, 0.0)
	referee.wrestler_b.position = Vector3.ZERO
	referee.wrestler_b.fsm.current_state = WrestlerFSM.State.DOWN
	return referee


func _prime_kickout(defender: WrestlerController) -> void:
	defender._pin_minigame = PinMinigame.new(1.0, 1)
	defender._pin_minigame.progress = PinMinigame.PROGRESS_THRESHOLD - 1.0
	defender._kickout_input_this_tick = true


func test_both_kickout_paths_score_one_near_fall_after_two() -> void:
	for automatic: bool in [false, true]:
		var referee := _downed_pair()
		var defender := referee.wrestler_b
		referee.cover_now(referee.wrestler_a, defender)
		var outcomes: Array[WrestlerController] = []
		referee.near_fall.connect(func(w: WrestlerController) -> void:
			assert_bool(referee.is_pin_active()).is_false()
			outcomes.append(w))
		if automatic:
			referee._pin_ticks = MatchReferee.NEAR_FALL_KICKOUT_TICK - 1
		else:
			referee._pin_ticks = MatchReferee.COUNT_TICKS[1]
			_prime_kickout(defender)
		referee._tick_pin()
		assert_array(outcomes).is_equal([defender])
		assert_int(referee.near_falls).is_equal(1)
		assert_int(referee.pin_count()).is_equal(0)


func test_a_kickout_before_the_second_slap_scores_no_near_fall() -> void:
	var referee := _downed_pair()
	referee.cover_now(referee.wrestler_a, referee.wrestler_b)
	referee._pin_ticks = MatchReferee.COUNT_TICKS[1] - 1
	_prime_kickout(referee.wrestler_b)
	referee._tick_pin()
	assert_bool(referee.is_pin_active()).is_false()
	assert_int(referee.near_falls).is_equal(0)


func test_three_beats_input_on_the_deciding_tick() -> void:
	var referee := _downed_pair()
	referee._finished[referee.wrestler_b] = MoveDef.new()
	referee.cover_now(referee.wrestler_a, referee.wrestler_b)
	referee._pin_ticks = MatchReferee.PIN_COUNT_TICKS - 1
	_prime_kickout(referee.wrestler_b)
	referee._tick_pin()
	assert_bool(referee.is_match_over()).is_true()
	assert_int(referee.pin_count()).is_equal(3)
	assert_int(referee.near_falls).is_equal(0)


func test_rope_contact_uses_the_settled_cover_and_reports_after_release() -> void:
	var referee := _downed_pair()
	var defender := referee.wrestler_b
	referee.cover_now(referee.wrestler_a, defender)
	defender.position.x = 1.8
	defender.look_at(defender.position + Vector3.RIGHT)
	var breaks: Array[WrestlerController] = []
	referee.rope_break.connect(func(w: WrestlerController, was_pin: bool) -> void:
		assert_bool(was_pin).is_true()
		assert_bool(referee.is_pin_active()).is_false()
		assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
		breaks.append(w))
	referee._pin_ticks = MatchReferee.ROPE_REACH_START_TICK - 1
	referee._tick_pin()
	assert_vector(referee._rope_side).is_equal(Vector3.RIGHT)
	assert_bool(defender.rope_reach._holding).is_true()
	for tick in MatchReferee.ROPE_REACH_TICKS:
		referee._tick_pin()
	assert_array(breaks).is_equal([defender])
	assert_int(referee.rope_breaks).is_equal(1)
	assert_int(referee.pin_count()).is_equal(0)
	assert_int(referee.near_falls).is_equal(0)
	assert_bool(defender.rope_reach._holding).is_true()


func test_a_lost_rope_reach_fades_without_breaking_the_cover() -> void:
	var referee := _downed_pair()
	var defender := referee.wrestler_b
	defender.position.x = 1.8
	defender.look_at(defender.position + Vector3.RIGHT)
	referee.cover_now(referee.wrestler_a, defender)
	referee._pin_ticks = MatchReferee.ROPE_REACH_START_TICK - 1
	referee._tick_pin()
	assert_bool(defender.rope_reach._holding).is_true()
	defender.position.x = 1.0
	for tick in MatchReferee.ROPE_REACH_TICKS:
		referee._tick_pin()
	assert_bool(referee.is_pin_active()).is_true()
	assert_int(referee.rope_breaks).is_equal(0)
	assert_bool(defender.rope_reach._holding).is_false()


func test_a_submission_break_releases_the_hold_before_reporting() -> void:
	var referee := _downed_pair()
	var attacker := referee.wrestler_a
	var defender := referee.wrestler_b
	attacker.submission_move = load("res://resources/moves/submission_figure_four.tres")
	defender.position.x = 1.8
	defender.look_at(defender.position + Vector3.RIGHT)
	referee._start_own_hold(attacker, defender)
	attacker._submission_lock_ticks = 0
	var breaks: Array[WrestlerController] = []
	referee.rope_break.connect(func(w: WrestlerController, was_pin: bool) -> void:
		assert_bool(was_pin).is_false()
		assert_bool(referee.is_submission_active()).is_false()
		assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
		breaks.append(w))
	referee._submission_fight_ticks = MatchReferee.SUBMISSION_ROPE_REACH_AFTER - 1
	for tick in MatchReferee.ROPE_REACH_TICKS + 1:
		referee._tick_submission()
	assert_array(breaks).is_equal([defender])
	assert_bool(defender.rope_reach._holding).is_true()


func test_scripted_cover_respects_stipulations_and_body_placement() -> void:
	var referee := _downed_pair()
	var defender := referee.wrestler_b
	MatchRules.set_mode(referee, MatchRules.Mode.LADDER)
	referee.cover_now(referee.wrestler_a, defender)
	assert_bool(referee.is_pin_active()).is_false()
	MatchRules.set_mode(referee, MatchRules.Mode.ONE_ON_ONE)
	defender.position.x = 2.4
	defender.look_at(defender.position + Vector3.RIGHT)
	referee.wrestler_a.position = Vector3(2.3, 0.0, 0.6)
	referee.cover_now(referee.wrestler_a, defender)
	assert_bool(referee.is_pin_active()).is_false()
	defender.look_at(defender.position + Vector3.LEFT)
	referee.cover_now(referee.wrestler_a, defender)
	assert_bool(referee.is_pin_active()).is_true()
