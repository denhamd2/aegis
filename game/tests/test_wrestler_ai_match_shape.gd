extends GdUnitTestSuite
## The shape of an AI match: a grapple to open it, strikes through the
## middle, and a signature to finish before the cover.
##
## This replaces the whip and reversal suites, whose mechanics were removed
## along with the paired animations they played. What it guards is the
## thing a viewer actually sees -- that the two men lock up once and then
## trade punches and kicks -- against the two ways it can silently stop
## being true: an AI that never grapples at all (every match opens with a
## jab, and the grapple animations are dead content), or one that keeps
## grappling (the old behaviour, measured at four tie-ups and as few as
## four strikes in a match -- and again, at 5.5 tie-ups, when the signature
## was gated on a landed rung the tie-up loser could not earn).

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

## And it is the *only* one, while the opponent is still fresh: once a
## grapple has landed the AI strikes.
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

## The finish. A man worn down to within one signature of a knockdown is
## locked up rather than jabbed at, so the match ends on a signature and a
## cover instead of on whichever strike happened to land last.
func test_a_ripe_opponent_is_locked_up_for_the_signature() -> void:
	var ai := _make_pair(1.0)
	ai.controller.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	ai.controller.combat.momentum = CombatSystem.SIGNATURE_THRESHOLD
	ai.controller.signature_move = _signature()
	_damage(ai.target, WrestlerController.KNOCKDOWN_DAMAGE - _signature_damage())
	ai._cooldown = 0
	var input := ai.poll_input()
	assert_bool(input.get("grapple", false)).override_failure_message(
		"A finishable opponent was struck at instead of locked up, so the "
		+ "match can end on a jab."
	).is_true()
	assert_bool(input.get("strike", false)).is_false()

## One point short of ripe is not ripe: a signature thrown there leaves the
## man standing and spends the tie-up for nothing.
func test_an_opponent_a_hit_short_of_ripe_is_still_struck() -> void:
	var ai := _make_pair(1.0)
	ai.controller.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	ai.controller.combat.momentum = CombatSystem.SIGNATURE_THRESHOLD
	ai.controller.signature_move = _signature()
	_damage(ai.target, WrestlerController.KNOCKDOWN_DAMAGE - _signature_damage() - 1.0)
	ai._cooldown = 0
	var input := ai.poll_input()
	assert_bool(input.get("grapple", false)).is_false()
	assert_bool(input.get("strike", false)).is_true()

## Ripeness is measured from the last knockdown, not from the total. A man
## who has already been put down once and worked back up is a fresh
## opponent as far as the next knockdown is concerned.
func test_ripeness_resets_with_a_knockdown() -> void:
	var ai := _make_pair(1.0)
	ai.controller.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	ai.controller.combat.momentum = CombatSystem.SIGNATURE_THRESHOLD
	ai.controller.signature_move = _signature()
	_damage(ai.target, WrestlerController.KNOCKDOWN_DAMAGE)
	ai.target._damage_at_last_knockdown = ai.target.combat.total_damage()
	ai._cooldown = 0
	var input := ai.poll_input()
	assert_bool(input.get("grapple", false)).override_failure_message(
		"A man who has just been knocked down and got up reads as ripe, so "
		+ "the AI reaches for a signature that cannot put him down."
	).is_false()

## And a signature nobody can pay for is not reached for, however worn down
## the opponent is -- otherwise the tie-up resolves into a plain grapple
## and the finish is spent on the wrong move.
func test_a_ripe_opponent_is_struck_when_the_meter_is_short() -> void:
	var ai := _make_pair(1.0)
	ai.controller.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	ai.controller.combat.momentum = CombatSystem.SIGNATURE_THRESHOLD - 1.0
	ai.controller.signature_move = _signature()
	_damage(ai.target, WrestlerController.KNOCKDOWN_DAMAGE - _signature_damage())
	ai._cooldown = 0
	assert_bool(ai.poll_input().get("strike", false)).is_true()

## Ripeness is judged against the *weakest* signature in the pool, not the
## primary: the move is drawn by a seeded pick at the moment the grapple
## resolves, so reaching for one that cannot finish him is a coin flip on
## whether the finish works.
func test_ripeness_uses_the_weakest_signature_in_the_pool() -> void:
	var ai := _make_pair(1.0)
	ai.controller.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	ai.controller.combat.momentum = CombatSystem.SIGNATURE_THRESHOLD
	ai.controller.signature_move = _signature()
	var weak := MoveDef.new()
	weak.damage_torso = 4.0
	ai.controller.signature_move_pool = [weak]
	_damage(ai.target, WrestlerController.KNOCKDOWN_DAMAGE - _signature_damage())
	ai._cooldown = 0
	assert_bool(ai.poll_input().get("grapple", false)).override_failure_message(
		"Ripeness was judged on the primary signature, so a draw from the "
		+ "pool can leave the opponent standing."
	).is_false()

func _signature() -> MoveDef:
	return load("res://resources/moves/signature_backbreaker.tres")

func _signature_damage() -> float:
	var move := _signature()
	return move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs

func _damage(w: WrestlerController, total: float) -> void:
	var move := MoveDef.new()
	move.damage_torso = total
	w.combat.apply_damage(move)
