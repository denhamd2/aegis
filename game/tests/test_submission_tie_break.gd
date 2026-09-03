extends GdUnitTestSuite
## MatchReferee._break_submission_tie(): the explicit, seeded resolution
## for a hold where both rings break on the same tick.
##
## Reachable, not hypothetical. The referee only starts a hold in a narrow
## band of limb damage around WrestlerController.SUBMISSION_ESCAPE_LIMB,
## and the two rates mirror each other around exactly that value — so a
## limb sitting on the crossover makes them identical. Two of ten measured
## AI-vs-AI seeds landed there. Left to _tick_submission()'s if/elif, "the
## attacker wins every dead heat" would be a rule nobody chose, hidden in
## the checking order: the same shape as the tie-up bug this project
## already fixed once (see test_match_referee_tie_break.gd).

func _referee(match_seed: int, finish_choices: int) -> MatchReferee:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	referee.match_seed = match_seed
	referee._finish_choices = finish_choices
	return referee

func test_a_dead_heat_is_reachable_from_the_real_rates() -> void:
	var limb := WrestlerController.SUBMISSION_ESCAPE_LIMB
	var attacker_rate := 1.0 + limb / CombatSystem.MAX_LIMB_DAMAGE
	var defender_rate := 1.0 + (2.0 * WrestlerController.SUBMISSION_ESCAPE_LIMB - limb) \
		/ CombatSystem.MAX_LIMB_DAMAGE
	var minigame := SubmissionMinigame.new(attacker_rate, defender_rate)
	for _t in range(500):
		minigame.tick(true, true)
		if minigame.attacker_wins() or minigame.defender_escapes():
			break
	assert_bool(minigame.attacker_wins() and minigame.defender_escapes()) \
		.override_failure_message(
			"A limb exactly on the crossover no longer ties, so this "
			+ "suite is guarding a case that can't happen — check whether "
			+ "the rates still mirror around SUBMISSION_ESCAPE_LIMB."
		).is_true()

func test_same_seed_and_hold_is_deterministic() -> void:
	assert_bool(_referee(3, 2)._break_submission_tie()) \
		.is_equal(_referee(3, 2)._break_submission_tie())

func test_both_outcomes_happen_across_seeds() -> void:
	var any_tap := false
	var any_escape := false
	for match_seed in range(1, 40):
		if _referee(match_seed, 0)._break_submission_tie():
			any_tap = true
		else:
			any_escape = true
	assert_bool(any_tap).is_true()
	assert_bool(any_escape).is_true()

## Successive dead heats inside one match must not all resolve the same
## way — that would be the ordering bug again, just seeded.
func test_successive_holds_in_one_match_can_differ() -> void:
	var outcomes := {}
	for finish_choices in range(0, 12):
		outcomes[_referee(7, finish_choices)._break_submission_tie()] = true
	assert_int(outcomes.size()).is_equal(2)

## The tie-break must not move with the tie-up's own flip: two seeded
## decisions sharing a seed would lock together for the whole match.
func test_it_does_not_track_the_tie_up_flip() -> void:
	var agreements := 0
	for match_seed in range(1, 40):
		var referee := _referee(match_seed, 0)
		referee.wrestler_a = auto_free(WrestlerController.new())
		referee.wrestler_b = auto_free(WrestlerController.new())
		referee._tie_up_ticks = 0
		var tie_up_picked_a := referee._break_tie_up_tie() == referee.wrestler_a
		if referee._break_submission_tie() == tie_up_picked_a:
			agreements += 1
	assert_int(agreements).is_between(8, 31)
