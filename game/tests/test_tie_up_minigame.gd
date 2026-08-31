extends GdUnitTestSuite
## Tie-up contest: WrestlerAI's rate-limited mash policy driven against
## TieUpMinigame. Regression test for the fixed placeholder, which resolved
## every tie-up by a hardcoded "lower player_index wins" rule regardless of
## either wrestler's actual behavior.

func test_more_frequent_presser_wins() -> void:
	var minigame := TieUpMinigame.new()
	var a := WrestlerAI.new()
	for t in range(1, 200):
		var a_pressed := a._should_press_tie_up(t)
		minigame.tick(a_pressed, false)
		if minigame.a_wins():
			break
	assert_bool(minigame.a_wins()).is_true()
	assert_bool(minigame.b_wins()).is_false()

func test_single_press_is_not_enough() -> void:
	var minigame := TieUpMinigame.new()
	minigame.tick(true, false)
	assert_bool(minigame.a_wins()).is_false()
	assert_bool(minigame.b_wins()).is_false()

func test_same_input_sequence_is_deterministic() -> void:
	var outcome_a := _run_both_mashing()
	var outcome_b := _run_both_mashing()
	assert_bool(outcome_a["a_wins"]).is_equal(outcome_b["a_wins"])
	assert_bool(outcome_a["b_wins"]).is_equal(outcome_b["b_wins"])
	assert_int(outcome_a["ticks"]).is_equal(outcome_b["ticks"])

func _run_both_mashing() -> Dictionary:
	var minigame := TieUpMinigame.new()
	var a := WrestlerAI.new()
	var b := WrestlerAI.new()
	b.tie_up_reaction_ticks = 4 # gives b a head start so the race isn't a tie
	var t := 0
	for i in range(1, 200):
		t = i
		minigame.tick(a._should_press_tie_up(i), b._should_press_tie_up(i))
		if minigame.a_wins() or minigame.b_wins():
			break
	return {"a_wins": minigame.a_wins(), "b_wins": minigame.b_wins(), "ticks": t}
