extends GdUnitTestSuite
## The capture harness and the evidence gate it feeds.
##
## ARCHITECTURE.md describes this pipeline as the thing that validates a
## capture "before any critic sees it". None of it ran: configure(),
## on_tick() and finish() had no callers, nothing parsed run_capture.sh's
## arguments, no manifest was ever written, and run_capture.sh passed
## --headless alongside --write-movie, which renders nothing. Every
## invocation it ever had exited 2, "round is void".

const HARNESS := preload("res://core/capture/capture_harness.gd")

func _harness() -> Node:
	return auto_free(HARNESS.new())

func test_arguments_are_read_off_the_command_line() -> void:
	var args := PackedStringArray(["--capture-replay", "res://r.tres",
			"--capture-output", "/tmp/out"])
	assert_str(HARNESS._arg_value(args, "--capture-replay")).is_equal("res://r.tres")
	assert_str(HARNESS._arg_value(args, "--capture-output")).is_equal("/tmp/out")

func test_a_missing_argument_is_empty_not_an_error() -> void:
	assert_str(HARNESS._arg_value(PackedStringArray([]), "--capture-output")).is_equal("")

## A flag with nothing after it must not read past the end of the array.
func test_a_dangling_argument_is_empty() -> void:
	var args := PackedStringArray(["--capture-output"])
	assert_str(HARNESS._arg_value(args, "--capture-output")).is_equal("")

## Its own doc comment promises it "never runs implicitly during normal
## play", which is only true if it stays switched off without its arguments.
func test_the_harness_is_inert_without_its_arguments() -> void:
	assert_bool(_harness().is_capturing()).is_false()

## A match that ends by submission has no pinfall in it, and demanding a
## three_count frame anyway would void every capture this project can
## produce -- measured: zero pinfalls across 24 seeds. The manifest expects
## what the match could reach and names what it skipped.
func test_a_submission_finish_expects_four_beats_and_says_why() -> void:
	var harness := _harness()
	harness._saw_pin = true
	harness._finish_method = "submission"
	var expected: Dictionary = harness._expected_labels()
	assert_array(expected["expected"]).contains(["tie_up", "apex", "impact", "pin_start"])
	assert_int((expected["expected"] as Array).size()).is_equal(4)
	assert_str(expected["skipped"]["three_count"]).contains("submission")

func test_a_pinfall_finish_expects_every_beat() -> void:
	var harness := _harness()
	harness._saw_pin = true
	harness._finish_method = "pinfall"
	var expected: Dictionary = harness._expected_labels()
	assert_int((expected["expected"] as Array).size()).is_equal(5)
	assert_dict(expected["skipped"]).is_empty()

## The three beats every match must reach still void a capture that misses
## one, so the relaxation above cannot hide a broken capture.
func test_a_match_with_no_grapple_still_expects_the_core_beats() -> void:
	var harness := _harness()
	var expected: Dictionary = harness._expected_labels()
	assert_array(expected["expected"]).contains(["tie_up", "apex", "impact"])
	assert_str(expected["skipped"]["pin_start"]).contains("no pin attempt")

## hud_present is measured off the pixels, and its first version was wrong
## in the direction that matters: it looked for luma variance, and the
## negative test -- hide the HUD, the gate must fail -- passed anyway,
## because the bright ring mat against the dark hall measures 0.61 range in
## the corner probes with no HUD at all.
func test_a_frame_with_no_hud_is_reported_as_having_no_hud() -> void:
	assert_bool(_harness()._has_hud(_frame(false))).is_false()

func test_a_frame_with_the_vitality_bars_is_reported_as_having_a_hud() -> void:
	assert_bool(_harness()._has_hud(_frame(true))).is_true()

## A mat-bright lower half against a dark upper one: the exact image that
## fooled the variance check.
func _frame(with_hud: bool) -> Image:
	var w := 960
	var h := 540
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.02, 0.02, 0.03))
	img.fill_rect(Rect2i(0, int(h * 0.55), w, h), Color(0.72, 0.74, 0.80))
	if not with_hud:
		return img
	var probe_w := int(w * HARNESS.HUD_PROBE_WIDTH)
	var probe_h := int(h * HARNESS.HUD_PROBE_HEIGHT)
	var margin_x := int(w * HARNESS.HUD_PROBE_MARGIN)
	var margin_y := int(h * HARNESS.HUD_PROBE_MARGIN)
	for x: int in [margin_x, w - margin_x - probe_w]:
		img.fill_rect(Rect2i(x, h - margin_y - probe_h, probe_w, probe_h),
				Color(0.06, 0.06, 0.08))
		img.fill_rect(Rect2i(x, h - margin_y - probe_h, probe_w, int(probe_h * 0.4)),
				Color(0.24, 0.72, 0.28))
	return img

## The invariant that makes *both* finishes reachable.
##
## Originally this asserted a wrestler goes down before any limb qualifies
## for a submission -- true when the submission threshold was 70, and the
## fix that made pins happen at all. It is deliberately false now: the
## thresholds are arranged to overlap, so that between the first knockdown
## and the point where an attacker just covers a spent opponent there is a
## range where either finish is legal and a seeded choice decides. Without
## that overlap one finish is unreachable, which this project has now
## measured in both directions -- 12 of 12 seeds submission, then 12 of 12
## pinfall.
func test_both_finishes_are_reachable() -> void:
	var move: MoveDef = load("res://resources/moves/grapple_hiptoss.tres")
	# The worst limb's share of each hit, so the crossing point can be
	# derived exactly rather than stepped to in 28-damage chunks -- landing
	# whole moves is too coarse to tell two thresholds 12 apart from each
	# other.
	var per_hit := move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs
	var worst_share := maxf(maxf(move.damage_head, move.damage_torso),
			maxf(move.damage_arms, move.damage_legs)) / per_hit
	var total_when_submissions_open := MatchReferee.SUBMISSION_LIMB_THRESHOLD / worst_share

	# A wrestler is knocked down before submissions become an option, so the
	# earliest knockdowns are covers.
	assert_float(WrestlerController.KNOCKDOWN_DAMAGE).override_failure_message(
		("Submissions open at %.0f total damage, at or before the %.0f "
		+ "knockdown -- so no knockdown is ever just a cover")
		% [total_when_submissions_open, WrestlerController.KNOCKDOWN_DAMAGE]
	).is_less(total_when_submissions_open)

	# And submissions become an option before the attacker starts simply
	# covering a spent opponent, so there is a range where both are legal.
	assert_float(total_when_submissions_open).override_failure_message(
		("Submissions only open at %.0f total damage, past the %.0f where "
		+ "the attacker covers instead -- so a tap-out can never happen")
		% [total_when_submissions_open, MatchReferee.PIN_PREFERENCE_DAMAGE]
	).is_less(MatchReferee.PIN_PREFERENCE_DAMAGE)

## And a hold has to be both escapable and winnable inside that range: the
## defender works free below SUBMISSION_ESCAPE_LIMB and taps above it, so
## that value must sit above the damage at which holds start being applied.
## A flat 1.8 defender rate, left over from the old 70 threshold, put it
## above the whole band and made every hold an escape.
func test_a_submission_can_both_be_escaped_and_won() -> void:
	assert_float(WrestlerController.SUBMISSION_ESCAPE_LIMB).override_failure_message(
		"Every submission is escapable; a tap-out can never happen"
	).is_greater(MatchReferee.SUBMISSION_LIMB_THRESHOLD)
	assert_float(WrestlerController.SUBMISSION_ESCAPE_LIMB).override_failure_message(
		"Every submission is a tap-out; nobody ever works free"
	).is_less(CombatSystem.MAX_LIMB_DAMAGE)
