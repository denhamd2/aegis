extends GdUnitTestSuite
## Kickout contest end-to-end: WrestlerAI's rate-limited press policy driven
## against PinMinigame's fill meter, across the window fractions
## CombatSystem.kickout_window_fraction() actually produces. Regression
## test for the bug where the AI held "strike" every tick (unlike a human's
## just-pressed semantics) and PROGRESS_THRESHOLD was calibrated for a
## press-limited input that was never actually exercised — together making
## kickouts succeed ~100% of the time regardless of window size.

const PIN_TICKS := 180 # MatchReferee.PIN_COUNT_TICKS
const SEEDS := [1, 2, 3, 4, 5]

func test_narrow_window_mostly_fails_to_kick_out() -> void:
	var successes := _successes_across_seeds(0.05)
	assert_int(successes).is_less_equal(1)

func test_wide_window_mostly_kicks_out() -> void:
	var successes := _successes_across_seeds(1.0)
	assert_int(successes).is_greater_equal(4)

func test_realistic_knockdown_range_is_not_uniform() -> void:
	# window_fraction ~0.3-0.5 is what kickout_window_fraction() actually
	# produces across the range of attacker momentum at a fresh knockdown
	# (0.3 at max momentum, 0.5 at none — see combat_system.gd). The
	# original bug made every window in this band succeed ~100% of the
	# time regardless of momentum; this asserts real variety exists across
	# the band instead — not every window in it is a guaranteed escape —
	# and that a narrower window is never easier to escape than a wider one.
	var bands := [0.3, 0.35, 0.4, 0.45, 0.5]
	var successes := []
	for window in bands:
		successes.append(_successes_across_seeds(window))
	var all_maxed := true
	for count in successes:
		if count < SEEDS.size():
			all_maxed = false
	assert_bool(all_maxed).is_false()
	for i in range(1, successes.size()):
		assert_int(successes[i]).is_greater_equal(successes[i - 1])

func test_presses_are_rate_limited_not_held() -> void:
	var ai: WrestlerAI = auto_free(WrestlerAI.new())
	var minigame := PinMinigame.new(1.0, 1)
	var last_press := -1000
	for t in range(1, PIN_TICKS + 1):
		var pressed := ai._should_press_kickout(t, minigame)
		if pressed:
			assert_int(t).is_greater(ai.kickout_reaction_ticks)
			assert_int(t - last_press).is_greater_equal(ai.kickout_press_interval_ticks)
			last_press = t

func test_same_window_and_seed_is_deterministic() -> void:
	var outcome_a := _run(0.3, 3)
	var outcome_b := _run(0.3, 3)
	assert_bool(outcome_a["kicked_out"]).is_equal(outcome_b["kicked_out"])
	assert_array(outcome_a["press_ticks"]).is_equal(outcome_b["press_ticks"])

func _successes_across_seeds(window: float) -> int:
	var successes := 0
	for s in SEEDS:
		if _run(window, s)["kicked_out"]:
			successes += 1
	return successes

func _run(window: float, seed_value: int) -> Dictionary:
	var ai: WrestlerAI = auto_free(WrestlerAI.new())
	var minigame := PinMinigame.new(window, seed_value)
	var press_ticks := []
	var kicked_out := false
	for t in range(1, PIN_TICKS + 1):
		var pressed := ai._should_press_kickout(t, minigame)
		if pressed:
			press_ticks.append(t)
		if minigame.tick(t, pressed):
			kicked_out = true
			break
	return {"kicked_out": kicked_out, "press_ticks": press_ticks}
