extends GdUnitTestSuite
## A wrestler's own submission hold (Cody's Figure-Four): when the referee
## reaches for it, and that the contest waits for the hold to be locked.

const F4 := "res://resources/moves/submission_figure_four.tres"

func _cody() -> WrestlerController:
	var w: WrestlerController = auto_free(WrestlerController.new())
	w.submission_move = load(F4)
	return w

func test_taken_once_and_never_after_a_finisher() -> void:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	var cody := _cody()
	assert_bool(referee._wants_own_hold(cody)).is_true()
	cody.last_landed_tier = CombatSystem.Tier.POWER
	assert_bool(referee._wants_own_hold(cody)).is_true()
	cody.last_landed_tier = CombatSystem.Tier.SIGNATURE
	assert_bool(referee._wants_own_hold(cody)).is_true()
	# Put down by a finisher: that man is pinned.
	cody.last_landed_tier = CombatSystem.Tier.FINISHER
	assert_bool(referee._wants_own_hold(cody)).is_false()
	# Once a match.
	cody.last_landed_tier = -1
	cody._submission_move_used = true
	assert_bool(referee._wants_own_hold(cody)).is_false()

func test_no_hold_without_one() -> void:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	var w: WrestlerController = auto_free(WrestlerController.new())
	assert_bool(referee._wants_own_hold(w)).is_false()

## The application is 62 authored frames at 30 fps; startup_frames counts it
## in 60 Hz ticks, and the contest starts on the lock.
func test_lock_matches_the_authored_application() -> void:
	var move: MoveDef = load(F4)
	assert_int(move.startup_frames).is_equal(124)
	assert_str(String(move.animation_pair_id)).is_equal("figure_four")
	assert_float(move.damage_legs).is_greater(0.0)
	var recipe: Dictionary = StrikeRecipes.RECIPES["figure_four_attacker"]
	assert_float(recipe["seconds"]).is_equal(6.0)
	assert_bool(StrikeRecipes.RECIPES.has("figure_four_defender")).is_true()
