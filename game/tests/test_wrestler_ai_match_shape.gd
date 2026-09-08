extends GdUnitTestSuite
## The shape of an AI match: one grapple to open it, strikes for the rest
## of it.
##
## This replaces the whip and reversal suites, whose mechanics were removed
## along with the paired animations they played. What it guards is the
## thing a viewer actually sees -- that the two men lock up once and then
## trade punches and kicks -- against the two ways it can silently stop
## being true: an AI that never grapples at all (every match opens with a
## jab, and the grapple animations are dead content), or one that keeps
## grappling (the old behaviour, measured at four tie-ups and as few as
## four strikes in a match).

func _make_pair(distance: float) -> WrestlerAI:
	var ai: WrestlerAI = auto_free(WrestlerAI.new())
	var attacker: WrestlerController = auto_free(WrestlerController.new())
	var defender: WrestlerController = auto_free(WrestlerController.new())
	for w in [attacker, defender]:
		# global_position is deferred to the physics server, which only
		# exists inside a SceneTree -- outside it the writes below no-op and
		# every distance reads as zero.
		add_child(w)
		w.fsm = auto_free(WrestlerFSM.new())
		w.combat = CombatSystem.new()
	attacker.global_position = Vector3.ZERO
	defender.global_position = Vector3(distance, 0.0, 0.0)
	ai.controller = attacker
	ai.target = defender
	return ai

## In range, nothing landed yet: lock up.
func test_the_first_close_range_decision_is_a_grapple() -> void:
	var ai := _make_pair(1.0)
	var input := ai.poll_input()
	assert_bool(input.get("grapple", false)).override_failure_message(
		"The AI's opening decision was not a tie-up, so a match can begin "
		+ "without the grapple it is supposed to open with."
	).is_true()
	assert_bool(input.get("strike", false)).is_false()

## And it is the *only* one: once a grapple has landed, the AI strikes.
func test_after_a_grapple_lands_the_ai_only_strikes() -> void:
	var ai := _make_pair(1.0)
	ai.controller.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	for _i in 20:
		ai._cooldown = 0
		var input := ai.poll_input()
		assert_bool(input.get("grapple", false)).override_failure_message(
			"The AI asked for another tie-up after the opening grapple."
		).is_false()
		assert_bool(input.get("strike", false)).is_true()

## Either man's grapple ends the opening -- they were both in the same
## lock-up, and only one of them could win it. Without this the loser of
## the tie-up would spend the rest of the match trying to start another.
func test_the_opponents_grapple_also_ends_the_opening() -> void:
	var ai := _make_pair(1.0)
	ai.target.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	ai._cooldown = 0
	var input := ai.poll_input()
	assert_bool(input.get("grapple", false)).is_false()
	assert_bool(input.get("strike", false)).is_true()

## A strike still costs its cooldown, so the AI cannot machine-gun them.
func test_strikes_are_rate_limited() -> void:
	var ai := _make_pair(1.0)
	ai.controller.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	assert_bool(ai.poll_input().get("strike", false)).is_true()
	assert_bool(ai.poll_input().get("strike", false)).override_failure_message(
		"The AI threw two strikes on consecutive ticks."
	).is_false()

## Out of range it closes, whether or not the opening grapple has happened.
func test_out_of_range_it_only_closes() -> void:
	for landed: bool in [false, true]:
		var ai := _make_pair(3.0)
		if landed:
			ai.controller.combat.record_tier(CombatSystem.Tier.GRAPPLE)
		var input := ai.poll_input()
		assert_bool(input.get("strike", false)).is_false()
		assert_bool(input.get("grapple", false)).is_false()
		assert_vector(input.get("move", Vector2.ZERO)).is_not_equal(Vector2.ZERO)

## Nothing is pressed in a hold any more: the attacker used to roll for an
## Irish whip here, which would have spent the match's one grapple on a
## move that is not a grapple.
func test_a_grapple_hold_asks_for_nothing() -> void:
	var ai := _make_pair(1.0)
	ai.controller.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	ai.controller._is_grapple_attacker = true
	assert_dict(ai.poll_input()).is_empty()
