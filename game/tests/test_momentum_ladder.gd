extends GdUnitTestSuite
## The momentum -> power -> signature -> finisher ladder, which
## ARCHITECTURE.md names as part of the core loop and which did not run.
##
## Measured over seven AI-vs-AI seeds before this: a winner earned 59-75
## momentum across a whole match, SIGNATURE_THRESHOLD was 60 and
## FINISHER_THRESHOLD was 100. Peak momentum equalled total momentum earned
## in every seed, which means nothing was ever spent -- the signature
## unlocked, when it unlocked at all, on the move that ended the fight, and
## the finisher never unlocked. Four authored moves and their paired
## animations could not appear in a match.
##
## These are the invariants that make that class of bug fail loudly instead
## of silently. They are shape checks, not feel claims: gauntlet/refs/
## measures nothing about how often a real wrestler should hit a signature.
##
## The power and finisher moves have since been removed for not reading on
## screen, so two of the four rungs are empty slots. The thresholds stay as
## they are -- they are the arithmetic of a meter, not of a moveset -- and
## the reachability checks below now assert that what is still wired can
## actually be reached.

const MOVES := "res://resources/moves/%s.tres"

func _move(name: String) -> MoveDef:
	return load(MOVES % name) as MoveDef

## The bug in one line. FINISHER_THRESHOLD was MOMENTUM_MAX, so a finisher
## needed a meter pinned at its ceiling -- and every tier below it spends
## momentum, so the ceiling is exactly what a wrestler who uses his moveset
## never reaches.
func test_no_tier_sits_at_the_meters_ceiling() -> void:
	assert_float(CombatSystem.FINISHER_THRESHOLD).override_failure_message(
		"The finisher unlocks at the top of the meter, so any wrestler who "
		+ "ever spends momentum can never reach it."
	).is_less(CombatSystem.MOMENTUM_MAX)

func test_the_tiers_are_ordered() -> void:
	assert_float(CombatSystem.POWER_THRESHOLD).is_less(CombatSystem.SIGNATURE_THRESHOLD)
	assert_float(CombatSystem.SIGNATURE_THRESHOLD).is_less(CombatSystem.FINISHER_THRESHOLD)

## The whole ladder has to fit inside the momentum one match affords, or a
## rung is decoration. This is the check that would have caught the original
## bug: 60 + 100 against 64 earned.
func test_the_whole_ladder_fits_inside_one_match() -> void:
	var climb := CombatSystem.SIGNATURE_THRESHOLD + CombatSystem.FINISHER_THRESHOLD
	assert_float(climb).override_failure_message(
		"Reaching a signature and then a finisher costs %.0f momentum, but a "
		% climb + "match earns a winner about %.0f."
		% CombatSystem.MOMENTUM_REFERENCE
	).is_less_equal(CombatSystem.MOMENTUM_REFERENCE)

## A wrestler cannot be charged more for a move than the momentum that
## unlocked it, or using it would drive the meter negative and the tier
## would gate on something the spend cannot honour.
func test_no_move_costs_more_than_the_tier_that_unlocks_it() -> void:
	for name: String in ["signature_backbreaker", "signature_neckbreaker"]:
		assert_float(_move(name).momentum_cost).override_failure_message(
			"%s costs more than SIGNATURE_THRESHOLD" % name
		).is_less_equal(CombatSystem.SIGNATURE_THRESHOLD)

## Spending a signature must not put the finisher out of reach for the rest
## of the match -- that is the shape the original numbers had, where a
## signature costing 60 sat one branch below a finisher needing 100.
func test_a_signature_does_not_price_the_finisher_out_of_the_match() -> void:
	var combat := CombatSystem.new()
	combat.momentum = CombatSystem.SIGNATURE_THRESHOLD
	combat.apply_momentum(_move("signature_backbreaker"))
	var still_needed := CombatSystem.FINISHER_THRESHOLD - combat.momentum
	var affordable := CombatSystem.MOMENTUM_REFERENCE - CombatSystem.SIGNATURE_THRESHOLD
	assert_float(still_needed).override_failure_message(
		"After a signature a wrestler needs %.0f more momentum for a finisher, "
		% still_needed + "and a match only affords about %.0f more." % affordable
	).is_less_equal(affordable)

## Every wired tier must actually have moves behind it, and every gate must
## open onto a tier that is wired. The power and finisher slots are empty
## now -- those moves were removed -- so what this asserts is that the two
## rungs left are reachable and that nothing gates on the two that are not:
## the meter has to unlock the signature by itself, or the man who lost the
## opening tie-up -- who carries no rung at all -- could never throw one.
func test_each_wired_tier_has_moves_and_is_reachable() -> void:
	var scene: Node = auto_free(load("res://scenes/match.tscn").instantiate())
	add_child(scene)
	for who: String in ["WrestlerA", "WrestlerB"]:
		var w: WrestlerController = scene.get_node(who)
		assert_object(w.grapple_move).is_not_null()
		assert_object(w.signature_move).is_not_null()
		assert_bool(w.is_finisher(w.signature_move)).is_false()
		assert_object(w.power_move).override_failure_message(
			"A power move is wired again; the ladder's gates assume that rung "
			+ "is empty (see CombatSystem.can_signature())."
		).is_null()
		assert_object(w.finisher_move).is_null()

		var combat := CombatSystem.new()
		combat.momentum = CombatSystem.SIGNATURE_THRESHOLD
		assert_bool(combat.can_signature()).override_failure_message(
			"An earned meter does not unlock the signature on its own, and "
			+ "no power move exists to unlock it instead -- so a wrestler "
			+ "who never won a tie-up can never throw one."
		).is_true()

## A move's tier is which slot it was drawn from, so the slots have to be
## unambiguous: tier_of() reads them back, and a move wired into two pools
## would answer with whichever is checked first. The chain gate
## (CombatSystem.tier_reached) is only as ordered as this mapping is.
func test_every_wired_move_reports_the_tier_it_was_wired_into() -> void:
	var scene: Node = auto_free(load("res://scenes/match.tscn").instantiate())
	add_child(scene)
	for who: String in ["WrestlerA", "WrestlerB"]:
		var w: WrestlerController = scene.get_node(who)
		var slots := {
			CombatSystem.Tier.GRAPPLE: [w.grapple_move] + w.grapple_move_pool,
			CombatSystem.Tier.SIGNATURE: [w.signature_move] + w.signature_move_pool,
		}
		for tier: int in slots:
			for move: MoveDef in slots[tier]:
				assert_int(w.tier_of(move)).override_failure_message(
					"%s reports tier %d but is wired into tier %d"
					% [move.resource_path, w.tier_of(move), tier]
				).is_equal(tier)
		# A strike is not a rung of the grapple chain, so it must not
		# advance it -- the meter it feeds is shared, the chain is not.
		assert_int(w.tier_of(w.strike_move)).is_equal(-1)
		assert_int(w.tier_of(w.running_attack_move)).is_equal(-1)
