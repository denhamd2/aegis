extends GdUnitTestSuite
## WrestlerAI._should_whip(): the AI's decision to whip instead of taking
## the normal grapple/power/signature/finisher escalation. Never rolls once
## already able to reach the power tier (see combat_system.gd's
## POWER_THRESHOLD); below that, a seeded coin flip deterministic per
## (match_seed, player_index, _grapple_attempts).

func _make_ai(momentum: float, match_seed: int, player_index: int, attempts: int) -> WrestlerAI:
	var ai: WrestlerAI = auto_free(WrestlerAI.new())
	ai.controller = auto_free(WrestlerController.new())
	ai.controller.combat = CombatSystem.new()
	ai.controller.combat.momentum = momentum
	ai._match_seed = match_seed
	ai._player_index = player_index
	ai._grapple_attempts = attempts
	return ai

func test_never_whips_at_or_above_power_threshold() -> void:
	for match_seed in range(1, 20):
		var ai := _make_ai(CombatSystem.POWER_THRESHOLD, match_seed, 0, 1)
		assert_bool(ai._should_whip()).is_false()

func test_same_seed_player_and_attempt_is_deterministic() -> void:
	var a := _make_ai(0.0, 7, 0, 3)
	var b := _make_ai(0.0, 7, 0, 3)
	assert_bool(a._should_whip()).is_equal(b._should_whip())

func test_both_outcomes_occur_across_attempts() -> void:
	var any_true := false
	var any_false := false
	for attempt in range(1, 60):
		var ai := _make_ai(0.0, 1, 0, attempt)
		if ai._should_whip():
			any_true = true
		else:
			any_false = true
	assert_bool(any_true).is_true()
	assert_bool(any_false).is_true()
