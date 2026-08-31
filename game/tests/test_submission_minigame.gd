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

## Mirrors WrestlerController.begin_submission()'s current defender_rate.
const DEFENDER_RATE := 1.8

func test_defender_favored_near_threshold_floor() -> void:
	var result := _run(_attacker_rate_for_limb_damage(70.0), DEFENDER_RATE, true)
	assert_bool(result["defender_escaped"]).is_true()

func test_attacker_favored_near_full_damage() -> void:
	var result := _run(_attacker_rate_for_limb_damage(100.0), DEFENDER_RATE, true)
	assert_bool(result["defender_escaped"]).is_false()

func test_outcome_is_not_flat_across_gated_band() -> void:
	var any_defender_escape := false
	var any_attacker_win := false
	for limb_damage in [70.0, 80.0, 90.0, 100.0]:
		var result := _run(_attacker_rate_for_limb_damage(limb_damage), DEFENDER_RATE, true)
		if result["defender_escaped"]:
			any_defender_escape = true
		else:
			any_attacker_win = true
	assert_bool(any_defender_escape).is_true()
	assert_bool(any_attacker_win).is_true()

func test_defender_must_actually_hold_to_progress() -> void:
	var result := _run(_attacker_rate_for_limb_damage(70.0), DEFENDER_RATE, false)
	assert_bool(result["defender_escaped"]).is_false()
	assert_float(result["defender_progress"]).is_equal(0.0)

func _run(attacker_rate: float, defender_rate: float, defender_holds: bool) -> Dictionary:
	var minigame := SubmissionMinigame.new(attacker_rate, defender_rate)
	for t in range(1, MAX_TICKS + 1):
		minigame.tick(true, defender_holds)
		if minigame.attacker_wins():
			return {"defender_escaped": false, "defender_progress": minigame.defender_progress}
		if minigame.defender_escapes():
			return {"defender_escaped": true, "defender_progress": minigame.defender_progress}
	return {"defender_escaped": false, "defender_progress": minigame.defender_progress}
