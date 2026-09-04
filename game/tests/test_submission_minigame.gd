extends GdUnitTestSuite
## Submission contest: WrestlerController.begin_submission()'s rates driven
## against SubmissionMinigame across the CombatSystem.SUBMISSION_LIMB_THRESHOLD
## .. MAX_LIMB_DAMAGE band MatchReferee actually gates a submission to.
## Regression test for the bug where a flat 0.9 defender_rate lost the race
## to submission_break_rate()'s theoretical floor of 1.0 every single time,
## regardless of which limb or how damaged it was — SubmissionMinigame has
## no RNG, so a given rate pair always produces the same outcome; the bug
## made every reachable rate pair resolve the same losing way for the
## defender.

const MAX_TICKS := 500 # generous upper bound; a real race resolves well under 200

## Mirrors CombatSystem.submission_break_rate()'s formula directly, so this
## suite tracks the real gated range (see match_referee.gd's
## SUBMISSION_LIMB_THRESHOLD) without needing a live CombatSystem/MatchReferee.
func _attacker_rate_for_limb_damage(limb_damage: float) -> float:
	return 1.0 + limb_damage / CombatSystem.MAX_LIMB_DAMAGE

## Mirrors WrestlerController.begin_submission()'s defender_rate. It was a
## flat 1.8 here long after the code stopped using one, which is the worst
## thing a mirror can be: the suite went on passing against a formula the
## game no longer ran. It slopes the other way from the attacker's now,
## around the same SUBMISSION_ESCAPE_LIMB crossover.
func _defender_rate_for_limb_damage(limb_damage: float) -> float:
	return 1.0 + (2.0 * WrestlerController.SUBMISSION_ESCAPE_LIMB - limb_damage) \
		/ CombatSystem.MAX_LIMB_DAMAGE

func _race_at(limb_damage: float, defender_holds: bool = true) -> Dictionary:
	return _run(_attacker_rate_for_limb_damage(limb_damage),
		_defender_rate_for_limb_damage(limb_damage), defender_holds)

func test_defender_escapes_a_limb_below_the_crossover() -> void:
	var result := _race_at(WrestlerController.SUBMISSION_ESCAPE_LIMB - 5.0)
	assert_bool(result["defender_escaped"]).is_true()

func test_attacker_taps_a_limb_above_the_crossover() -> void:
	var result := _race_at(WrestlerController.SUBMISSION_ESCAPE_LIMB + 5.0)
	assert_bool(result["defender_escaped"]).is_false()

func test_attacker_favored_near_full_damage() -> void:
	var result := _race_at(CombatSystem.MAX_LIMB_DAMAGE)
	assert_bool(result["defender_escaped"]).is_false()

func test_outcome_is_not_flat_across_gated_band() -> void:
	var any_defender_escape := false
	var any_attacker_win := false
	for limb_damage in [55.0, 70.0, 85.0, 100.0]:
		if _race_at(limb_damage)["defender_escaped"]:
			any_defender_escape = true
		else:
			any_attacker_win = true
	assert_bool(any_defender_escape).is_true()
	assert_bool(any_attacker_win).is_true()

## The defect the mirrored slope was written for: with a flat defender rate
## the margin was the same sliver at every limb the referee actually gates
## a hold to, so a photo finish was the only outcome the game could
## produce. The loser's ring should end further from breaking the more
## damaged the limb is.
func test_the_margin_widens_with_the_damage() -> void:
	var near := _race_at(WrestlerController.SUBMISSION_ESCAPE_LIMB + 5.0)
	var far := _race_at(CombatSystem.MAX_LIMB_DAMAGE)
	assert_float(far["loser_progress"]).override_failure_message(
		"A destroyed limb finished no more decisively than a barely-hurt "
		+ "one, so every submission is a photo finish again."
	).is_less(near["loser_progress"])

## A hold has to last about as long as the one hold anyone has measured:
## gauntlet/refs/timings.md frame-stepped 2.5s (150 ticks at 60Hz) from
## applied to the referee's break signal. Bounded loosely on both sides --
## it is one instance of a rope-break cycle, not a settled constant.
func test_a_hold_runs_about_as_long_as_the_measured_one() -> void:
	for limb_damage in [55.0, 70.0, 85.0, 100.0]:
		var ticks: int = _race_at(limb_damage)["ticks"]
		assert_int(ticks).override_failure_message(
			"A hold at limb damage %f resolved in %d ticks; the measured "
			% [limb_damage, ticks]
			+ "hold ran ~150."
		).is_between(100, 200)

func test_defender_must_actually_hold_to_progress() -> void:
	var result := _race_at(WrestlerController.SUBMISSION_ESCAPE_LIMB - 5.0, false)
	assert_bool(result["defender_escaped"]).is_false()
	assert_float(result["defender_progress"]).is_equal(0.0)

func _run(attacker_rate: float, defender_rate: float, defender_holds: bool) -> Dictionary:
	var minigame := SubmissionMinigame.new(attacker_rate, defender_rate)
	for t in range(1, MAX_TICKS + 1):
		minigame.tick(true, defender_holds)
		if minigame.attacker_wins():
			return _result(false, t, minigame)
		if minigame.defender_escapes():
			return _result(true, t, minigame)
	return _result(false, MAX_TICKS, minigame)

## loser_progress is how close the losing side came to breaking the other's
## ring — the margin the race was decided by, which is the quantity
## test_the_margin_widens_with_the_damage() is about.
func _result(defender_escaped: bool, ticks: int, minigame: SubmissionMinigame) -> Dictionary:
	return {
		"defender_escaped": defender_escaped,
		"ticks": ticks,
		"defender_progress": minigame.defender_progress,
		"loser_progress": minigame.attacker_progress if defender_escaped \
			else minigame.defender_progress,
	}
