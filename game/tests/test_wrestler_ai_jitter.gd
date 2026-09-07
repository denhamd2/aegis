extends GdUnitTestSuite
## WrestlerAI.setup_jitter(): the fix for two AI-vs-AI opponents with
## identical exported tunables mashing tie-up on the exact same ticks
## forever (see match_referee.gd's tie-break comment and README's
## "AI-vs-AI has no tie-breaker" gap).

func test_same_match_seed_and_player_index_is_deterministic() -> void:
	var a1: WrestlerAI = auto_free(WrestlerAI.new())
	a1.setup_jitter(7, 0)
	var a2: WrestlerAI = auto_free(WrestlerAI.new())
	a2.setup_jitter(7, 0)
	assert_int(a1.tie_up_reaction_ticks).is_equal(a2.tie_up_reaction_ticks)
	assert_int(a1.tie_up_press_interval_ticks).is_equal(a2.tie_up_press_interval_ticks)

func test_different_player_index_same_seed_usually_diverges() -> void:
	# Not guaranteed different on every single seed (jitter is a small
	# discrete range), but across many seeds at least one should diverge --
	# the direct regression check for the original bug, where two identical
	# AI instances mashed on exactly the same ticks on every seed, always.
	var any_diverged := false
	for match_seed in range(1, 30):
		var a: WrestlerAI = auto_free(WrestlerAI.new())
		a.setup_jitter(match_seed, 0)
		var b: WrestlerAI = auto_free(WrestlerAI.new())
		b.setup_jitter(match_seed, 1)
		if a.tie_up_reaction_ticks != b.tie_up_reaction_ticks \
				or a.tie_up_press_interval_ticks != b.tie_up_press_interval_ticks:
			any_diverged = true
			break
	assert_bool(any_diverged).is_true()

func test_jitter_never_produces_a_non_positive_press_interval() -> void:
	for match_seed in range(1, 30):
		for player_index in range(2):
			var a: WrestlerAI = auto_free(WrestlerAI.new())
			a.setup_jitter(match_seed, player_index)
			assert_int(a.tie_up_press_interval_ticks).is_greater(0)
			assert_int(a.tie_up_reaction_ticks).is_greater(0)

## setup_jitter() alone made two AI opponents differ from *each other*, but
## each one still mashed at one fixed rate for the whole match -- so
## whoever drew the shorter interval won every tie-up in that match by an
## identical margin. The reachability probe caught it: across seeds 1-3 one
## wrestler took every tie-up in all three matches, and every resolution
## reported the same TieUpMinigame progress pair ((6,10) x4, (7,10) x3,
## (10,6) x5). Entry was neutral; the outcome was a constant.
##
## _roll_tie_up_timing() now re-rolls at each tie-up, so successive tie-ups
## in one match are separate contests.
func test_successive_tie_ups_in_one_match_are_not_identical() -> void:
	var ai: WrestlerAI = auto_free(WrestlerAI.new())
	ai.setup_jitter(7, 0)
	var seen := {}
	for attempt in range(1, 12):
		ai._tie_up_attempts = attempt
		ai._roll_tie_up_timing()
		seen["%d,%d" % [ai._this_tie_up_reaction, ai._this_tie_up_interval]] = true
	assert_int(seen.size()).override_failure_message(
		"every tie-up in a match rolled the same mash timing (%s) -- the "
		% str(seen.keys()) + "contest is decided once, not per tie-up"
	).is_greater(1)

## Still replay-safe: the per-tie-up roll is a pure function of
## (match_seed, player_index, attempt), so the same match replays the same.
func test_per_tie_up_roll_is_deterministic() -> void:
	var a: WrestlerAI = auto_free(WrestlerAI.new())
	var b: WrestlerAI = auto_free(WrestlerAI.new())
	for ai in [a, b]:
		ai.setup_jitter(11, 1)
	for attempt in range(1, 8):
		a._tie_up_attempts = attempt
		b._tie_up_attempts = attempt
		a._roll_tie_up_timing()
		b._roll_tie_up_timing()
		assert_int(a._this_tie_up_reaction).is_equal(b._this_tie_up_reaction)
		assert_int(a._this_tie_up_interval).is_equal(b._this_tie_up_interval)

## An unrolled AI (constructed directly in a unit test, never driven through
## poll_input) keeps using the exported baselines -- test_tie_up_minigame.gd
## depends on that.
func test_unrolled_ai_falls_back_to_the_exported_tunables() -> void:
	var ai: WrestlerAI = auto_free(WrestlerAI.new())
	assert_int(ai._this_tie_up_reaction).is_equal(-1)
	assert_int(ai._this_tie_up_interval).is_equal(-1)
	# First qualifying press lands one tick after the exported reaction
	# delay, exactly as it did before the per-tie-up roll existed.
	assert_bool(ai._should_press_tie_up(ai.tie_up_reaction_ticks)).is_false()
	assert_bool(ai._should_press_tie_up(ai.tie_up_reaction_ticks + 1)).is_true()
