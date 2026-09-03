extends GdUnitTestSuite
## The match HUD and the read-only referee views it polls.
##
## There was no HUD at all before this: no CanvasLayer, Control or Label
## anywhere in the project, which also meant the evidence gate's
## hud_present check could never pass. gauntlet/refs/hud.md had been sitting
## there measured and unused the whole time.
##
## Whether the HUD *looks* right is not assertable and was checked by
## rendering a real match at four beats plus a forced pin and a live
## submission. What is assertable is the wiring and the numbers behind it.

const MATCH_SCENE := preload("res://scenes/match.tscn")
const HUD_SCENE := preload("res://scenes/match_hud.tscn")

func _make_referee() -> MatchReferee:
	return auto_free(MatchReferee.new())

func _make_wrestler() -> WrestlerController:
	var w: WrestlerController = auto_free(WrestlerController.new())
	w.fsm = auto_free(WrestlerFSM.new())
	w.combat = CombatSystem.new()
	return w

## The HUD only means anything if the shipped match actually has one.
func test_the_match_scene_has_a_hud_wired_to_both_wrestlers() -> void:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	var hud: MatchHUD = scene.get_node("MatchHUD/Draw")
	assert_object(hud.wrestler_a).is_same(scene.get_node("WrestlerA"))
	assert_object(hud.wrestler_b).is_same(scene.get_node("WrestlerB"))
	assert_object(hud.referee).is_same(scene.get_node("MatchReferee"))

func test_the_hud_covers_the_whole_viewport() -> void:
	var hud_root: CanvasLayer = auto_free(HUD_SCENE.instantiate())
	add_child(hud_root)
	var hud: MatchHUD = hud_root.get_node("Draw")
	assert_float(hud.anchor_right).is_equal(1.0)
	assert_float(hud.anchor_bottom).is_equal(1.0)

## The vitality bar and the kickout difficulty must not be able to tell the
## player different stories, so they share a denominator.
##
## This test used to assert that with a hardcoded MAX_LIMB_DAMAGE * 4.0 on
## the HUD's side, and stayed green after kickout_window_fraction() was
## rescaled to KICKOUT_DAMAGE_REFERENCE (200) -- because at 400 damage the
## window is clamped to its floor either way, so both halves passed while
## describing different scales. A test that cannot fail when the property
## it names becomes false is not testing it. It reads the constant now, and
## checks the scales agree somewhere they can actually disagree: partway
## along, where the clamp is not hiding the difference.
func test_the_vitality_bar_uses_the_same_scale_as_the_kickout_window() -> void:
	var combat := CombatSystem.new()
	var move := MoveDef.new()
	# Half of the scale the kickout window is measured against.
	move.damage_torso = CombatSystem.KICKOUT_DAMAGE_REFERENCE * 0.5
	combat.apply_damage(move)
	var bar := combat.total_damage() / CombatSystem.KICKOUT_DAMAGE_REFERENCE
	assert_float(bar).is_equal_approx(0.5, 0.0001)
	# The window's damage term is 1 - damage/KICKOUT_DAMAGE_REFERENCE, with
	# no momentum pressure and short of the clamp, so a half-depleted bar is
	# exactly a half-shrunk window. Against the old denominator the bar reads
	# 0.25 while the window reads 0.5, and the two openly disagree.
	assert_float(combat.kickout_window_fraction(0.0)).is_equal_approx(1.0 - bar, 0.0001)

## The bar has to move over the damage a match actually reaches, not over a
## range no wrestler ever occupies. Measured: wrestlers are knocked down
## between 101 and 184 total damage, and against the old 400 denominator
## that whole span rendered as 75%-54% health -- a man one hit from losing
## looked over half fit. Against the scale the match is really played on it
## reads 50%-92% depleted.
func test_the_bar_is_mostly_gone_by_the_time_a_wrestler_is_knocked_down() -> void:
	var combat := CombatSystem.new()
	var move := MoveDef.new()
	move.damage_torso = WrestlerController.KNOCKDOWN_DAMAGE
	combat.apply_damage(move)
	var depleted := combat.total_damage() / CombatSystem.KICKOUT_DAMAGE_REFERENCE
	assert_float(depleted).override_failure_message(
		"At the knockdown threshold the bar shows %.0f%% depleted." % (depleted * 100.0)
	).is_greater_equal(0.4)

func test_no_count_is_shown_outside_a_pin() -> void:
	assert_int(_make_referee().pin_count()).is_equal(0)

## The count follows timings.md's frame-stepped schedule, which is uneven:
## "1" to "2" is ~1.25s and "2" to "3" ~1.00s. An evenly divided count is
## the one shape the reference says a real one does not have.
func test_the_count_follows_the_measured_cadence() -> void:
	var referee := _make_referee()
	referee._pinning = true
	referee._pin_defender = _make_wrestler()
	var seen: Array[int] = []
	for tick in MatchReferee.PIN_COUNT_TICKS:
		referee._pin_ticks += 1
		referee._update_count()
		seen.append(referee.pin_count())
	for i in MatchReferee.COUNT_TICKS.size():
		var at: int = MatchReferee.COUNT_TICKS[i]
		assert_int(seen[at - 1]).override_failure_message(
			"Count %d should be up at tick %d" % [i + 1, at]).is_equal(i + 1)

## Each digit pops in, holds for its measured time, then goes away before
## the next arrives -- "1" for ~0.65s, "2" for ~0.40s, with a silent gap.
func test_each_digit_goes_away_before_the_next_arrives() -> void:
	var referee := _make_referee()
	referee._pinning = true
	referee._pin_defender = _make_wrestler()
	var blanks := 0
	for tick in MatchReferee.COUNT_TICKS[1]:
		referee._pin_ticks += 1
		referee._update_count()
		if referee._pin_ticks > MatchReferee.COUNT_TICKS[0] and referee.pin_count() == 0:
			blanks += 1
	assert_int(blanks).override_failure_message(
		"The first digit never leaves the screen before the second"
	).is_greater(0)

## The intervals themselves, against the measurement rather than the code.
func test_the_measured_intervals_are_uneven() -> void:
	var first: int = MatchReferee.COUNT_TICKS[1] - MatchReferee.COUNT_TICKS[0]
	var second: int = MatchReferee.COUNT_TICKS[2] - MatchReferee.COUNT_TICKS[1]
	assert_float(first / 60.0).is_equal_approx(1.25, 0.02)
	assert_float(second / 60.0).is_equal_approx(1.00, 0.02)

## The third count and the end of the pin land on the same tick: _tick_pin()
## sees 180 ticks, declares the pinfall and clears _pinning in one call. A
## count derived live from _pinning would therefore show "3" for zero frames
## -- the winning count, the one that matters most, would never be on
## screen. Confirmed by rendering: before this it captured a "2".
func test_the_winning_count_stays_on_screen_after_the_pinfall() -> void:
	var referee := _make_referee()
	referee._pinning = false
	referee._pin_count_shown = 3
	assert_int(referee.pin_count()).is_equal(3)

func test_a_kickout_clears_the_count() -> void:
	var referee := _make_referee()
	var attacker := _make_wrestler()
	var defender := _make_wrestler()
	attacker.fsm.current_state = WrestlerFSM.State.PIN_ATTACKER
	defender.fsm.current_state = WrestlerFSM.State.PIN_DEFENDER
	referee._pinning = true
	referee._pin_attacker = attacker
	referee._pin_defender = defender
	referee._pin_count_shown = 2
	referee._end_pin(false)
	assert_int(referee.pin_count()).is_equal(0)

func test_no_hold_meter_outside_a_submission() -> void:
	var referee := _make_referee()
	assert_bool(referee.is_submission_active()).is_false()
	assert_vector(referee.submission_progress()).is_equal(Vector2.ZERO)

func test_the_hold_meter_reports_both_sides_as_fractions() -> void:
	var referee := _make_referee()
	var defender := _make_wrestler()
	defender._submission_minigame = SubmissionMinigame.new(1.0, 2.0)
	# Ticked to a quarter of the break point rather than a fixed 25 ticks:
	# BREAK_POINT is derived from a measured hold duration (see
	# submission_minigame.gd) and moved once already, which broke this
	# assertion. The fractions the HUD reports are what is under test here,
	# not how long a hold runs.
	defender._submission_minigame.tick(true, true, int(SubmissionMinigame.BREAK_POINT / 4.0))
	referee._submissioning = true
	referee._submission_defender = defender
	var progress := referee.submission_progress()
	assert_float(progress.x).is_equal_approx(0.25, 0.0001)
	assert_float(progress.y).is_equal_approx(0.50, 0.0001)

## The HUD is allowed to read gameplay state only because it can never write
## it. Drawing a frame must leave the match exactly as it found it.
func test_drawing_the_hud_changes_no_gameplay_state() -> void:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.combat.momentum = 42.0
	var before := [a.fsm.current_state, b.fsm.current_state, a.combat.momentum,
			b.combat.momentum, a.combat.total_damage(), b.combat.total_damage(),
			a.global_position, b.global_position]
	var hud: MatchHUD = scene.get_node("MatchHUD/Draw")
	hud._draw()
	var after := [a.fsm.current_state, b.fsm.current_state, a.combat.momentum,
			b.combat.momentum, a.combat.total_damage(), b.combat.total_damage(),
			a.global_position, b.global_position]
	assert_array(after).is_equal(before)
