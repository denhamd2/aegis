extends GdUnitTestSuite
## WrestlerAI.setup_jitter(): the fix for two AI-vs-AI opponents with
## identical exported tunables mashing tie-up on the exact same ticks
## forever (see match_referee.gd's tie-break comment and README's
## "AI-vs-AI has no tie-breaker" gap).

func test_same_match_seed_and_player_index_is_deterministic() -> void:
	var a1 := WrestlerAI.new()
	a1.setup_jitter(7, 0)
	var a2 := WrestlerAI.new()
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
		var a := WrestlerAI.new()
		a.setup_jitter(match_seed, 0)
		var b := WrestlerAI.new()
		b.setup_jitter(match_seed, 1)
		if a.tie_up_reaction_ticks != b.tie_up_reaction_ticks \
				or a.tie_up_press_interval_ticks != b.tie_up_press_interval_ticks:
			any_diverged = true
			break
	assert_bool(any_diverged).is_true()

func test_jitter_never_produces_a_non_positive_press_interval() -> void:
	for match_seed in range(1, 30):
		for player_index in range(2):
			var a := WrestlerAI.new()
			a.setup_jitter(match_seed, player_index)
			assert_int(a.tie_up_press_interval_ticks).is_greater(0)
			assert_int(a.tie_up_reaction_ticks).is_greater(0)
