extends GdUnitTestSuite
## Frame data and getup pacing, pinned to gauntlet/refs/timings.md.
##
## Every number this suite asserts against is frame-stepped from
## wwe2k26_footage_01.mp4 at native 30fps. What it guards is not that the
## constants are correct in some absolute sense — it is that the ones with
## a measurement behind them cannot drift away from it silently, which is
## how this project has lost three constants already.

const TICKS_PER_SECOND := 60.0
## Rise-start to a standing fighting stance, default: 366.07s -> 368.20s.
const MEASURED_RISE := 2.10
## The same rise when the wrestler triggers a quick recovery himself:
## 330.43s -> 331.57s, with an "R1 INSTANT RECOVERY" prompt on screen.
const MEASURED_RISE_FAST := 1.14
## Jab windup-begin to first contact: 668.300s -> 668.433s.
const MEASURED_JAB_STARTUP := 0.133
## The isolated heavy strike: windup start 230.333s, contact 230.633s,
## guard reset ~231.367s (settled by ~231.433s).
const MEASURED_HEAVY_STARTUP := 0.300
const MEASURED_HEAVY_RECOVERY := 0.767
## A frame of the 30fps source either way, plus a tick of rounding. The
## heavy strike's recovery is quoted as a 0.73-0.80s range in timings.md,
## so it gets the wider band its own measurement carries.
const TOLERANCE := 0.05
const RECOVERY_TOLERANCE := 0.10

const JAB: MoveDef = preload("res://resources/moves/strike_jab.tres")
const HEAVY: MoveDef = preload("res://resources/moves/running_attack_clothesline.tres")

func test_the_default_rise_matches_the_measured_one() -> void:
	assert_float(WrestlerController.GETUP_RISE_TICKS / TICKS_PER_SECOND) \
		.is_equal_approx(MEASURED_RISE, TOLERANCE)

func test_the_input_driven_rise_matches_the_measured_one() -> void:
	assert_float(WrestlerController.GETUP_RISE_FAST_TICKS / TICKS_PER_SECOND) \
		.is_equal_approx(MEASURED_RISE_FAST, TOLERANCE)

## The whole point of carrying two numbers. timings.md is explicit that the
## pair is a real two-speed mechanic and not sample variance, so collapsing
## them back to one value is the regression to guard.
func test_pressing_up_is_meaningfully_faster_than_waiting() -> void:
	assert_int(WrestlerController.GETUP_RISE_FAST_TICKS).override_failure_message(
		"The input-driven rise is not faster than the default one, so "
		+ "pressing up buys the wrestler nothing."
	).is_less(WrestlerController.GETUP_RISE_TICKS)

## The rise is a separate quantity from how long a wrestler lies prone.
## Conflating the two is exactly the mistake timings.md made when it
## compared its measured animation durations against GETUP_TICKS.
func test_the_prone_timer_is_not_the_rise() -> void:
	assert_int(WrestlerController.GETUP_TICKS).is_not_equal(
		WrestlerController.GETUP_RISE_TICKS)

func test_a_wrestler_who_presses_up_gets_the_fast_rise() -> void:
	var w := _downed_wrestler()
	w._process_down({"strike": true})
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.GETUP)
	assert_int(w._move_ticks_remaining).is_equal(WrestlerController.GETUP_RISE_FAST_TICKS)

func test_a_wrestler_whose_timer_runs_out_gets_the_default_rise() -> void:
	var w := _downed_wrestler()
	w._move_ticks_remaining = 1
	w._process_down({})
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.GETUP)
	assert_int(w._move_ticks_remaining).is_equal(WrestlerController.GETUP_RISE_TICKS)

func test_the_jabs_startup_matches_the_measured_jab() -> void:
	assert_float(JAB.startup_frames / TICKS_PER_SECOND) \
		.is_equal_approx(MEASURED_JAB_STARTUP, TOLERANCE)

func test_the_heavy_strikes_startup_matches_the_measured_heavy_strike() -> void:
	assert_float(HEAVY.startup_frames / TICKS_PER_SECOND) \
		.is_equal_approx(MEASURED_HEAVY_STARTUP, TOLERANCE)

## Video cannot separate active frames from recovery frames — a hitbox has
## no visual signature — so the measured quantity is contact to
## fight-ready, which is both of them together.
func test_the_heavy_strikes_recovery_matches_the_measured_one() -> void:
	var contact_to_ready := (HEAVY.active_frames + HEAVY.recovery_frames) / TICKS_PER_SECOND
	assert_float(contact_to_ready).override_failure_message(
		"A heavy strike returns to guard in %f s against a measured "
		% contact_to_ready
		+ "0.73-0.80s. That recovery is what makes it a commitment rather "
		+ "than a jab."
	).is_equal_approx(MEASURED_HEAVY_RECOVERY, RECOVERY_TOLERANCE)

## The corpus has two strike instances and they differ by more than 2x in
## startup, so a heavy strike sharing a jab's frame data is wrong by
## construction — whatever the numbers happen to be.
func test_a_heavy_strike_is_not_paced_like_a_jab() -> void:
	assert_int(HEAVY.startup_frames).is_greater(JAB.startup_frames)
	assert_int(HEAVY.recovery_frames).is_greater(JAB.recovery_frames)

## A reversal window has to sit inside the move it belongs to, or the
## defender is being asked to read a frame that never plays. Both strikes
## had their startup moved by measurement, so this guards the consequence.
func test_every_strikes_reversal_window_stays_inside_the_move() -> void:
	for move: MoveDef in [JAB, HEAVY]:
		assert_int(move.reversal_window_end).override_failure_message(
			"%s's reversal window ends at %d but the move is only %d ticks."
			% [move.resource_path.get_file(), move.reversal_window_end,
				move.total_frames()]
		).is_less_equal(move.total_frames())

func _downed_wrestler() -> WrestlerController:
	var w: WrestlerController = auto_free(WrestlerController.new())
	w.fsm = auto_free(WrestlerFSM.new())
	w.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	w.fsm.transition_to(WrestlerFSM.State.DOWN)
	w._move_ticks_remaining = WrestlerController.GETUP_TICKS
	return w
