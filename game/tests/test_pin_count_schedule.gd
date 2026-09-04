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
