extends GdUnitTestSuite
## MatchReferee._break_tie_up_tie(): the explicit, seeded resolution for a
## tie-up where both wrestlers cross TieUpMinigame.PROGRESS_THRESHOLD on the
## exact same tick — a real, reachable case once entry-order bias is fixed
## (see wrestler_controller.gd's _wants_tie_up_this_tick doc comment) and
## two AI opponents mash on genuinely equal footing. Regression guard
## against silently falling back to "whichever branch an if/elif checks
## first" — the same shape as the original placeholder bug this session
## already fixed once (see test_tie_up_minigame.gd).

func test_same_seed_and_tick_is_deterministic() -> void:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	referee.wrestler_a = auto_free(WrestlerController.new())
	referee.wrestler_b = auto_free(WrestlerController.new())
	referee.match_seed = 3
	referee._tie_up_ticks = 42
	var first := referee._break_tie_up_tie()
	var second := referee._break_tie_up_tie()
	assert_object(first).is_same(second)

func test_both_wrestlers_can_win_across_seeds() -> void:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	referee.wrestler_a = auto_free(WrestlerController.new())
	referee.wrestler_b = auto_free(WrestlerController.new())
	var any_a := false
	var any_b := false
	for match_seed in range(1, 40):
		referee.match_seed = match_seed
		referee._tie_up_ticks = 1
		var winner := referee._break_tie_up_tie()
		if winner == referee.wrestler_a:
			any_a = true
		elif winner == referee.wrestler_b:
			any_b = true
	assert_bool(any_a).is_true()
	assert_bool(any_b).is_true()
