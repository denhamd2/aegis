extends GdUnitTestSuite
## WrestlerController._process_grapple_hold()'s momentum-gated move tier
## ladder (grapple_move -> power_move -> signature_move -> finisher_move).
## No test previously covered this at all, not even the pre-existing
## signature/finisher split -- this is new coverage added alongside the new
## power_move rung (see combat_system.gd's POWER_THRESHOLD/can_power()).

func _make_move(id: StringName) -> MoveDef:
	var move := MoveDef.new()
	move.animation_pair_id = id
	return move

func _make_grappling_pair() -> Array:
	var attacker: WrestlerController = auto_free(WrestlerController.new())
	var defender: WrestlerController = auto_free(WrestlerController.new())
	for w in [attacker, defender]:
		w.fsm = auto_free(WrestlerFSM.new())
		w.combat = CombatSystem.new()
	attacker.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	defender.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	attacker.opponent = defender
	attacker._is_grapple_attacker = true
	attacker.grapple_move = _make_move(&"grapple")
	attacker.power_move = _make_move(&"power")
	attacker.signature_move = _make_move(&"signature")
	attacker.finisher_move = _make_move(&"finisher")
	return [attacker, defender]

## The tier ladder is gated on the rung below it as well as on momentum
## (CombatSystem.tier_reached), so a test that only sets the meter is
## testing half the gate. Callers pass the rung this wrestler has already
## landed; the default is the whole chain, which is the pre-chain behaviour
## these threshold cases were written against.
func _selected_move_id(attacker: WrestlerController, defender: WrestlerController,
		momentum: float, tier_reached: int = CombatSystem.Tier.SIGNATURE) -> StringName:
	attacker.combat.momentum = momentum
	attacker.combat.tier_reached = tier_reached
	attacker._process_grapple_hold({})
	# _active_move is set before GrappleRig dispatch/resolution and (with no
	# grapple_rig assigned here, so the synchronous else-branch runs) is left
	# holding the selected move afterward -- simpler and less fragile than
	# capturing move_landed through a lambda closure.
	var id: StringName = attacker._active_move.animation_pair_id
	# Reset back to GRAPPLE_HOLD for the next call in the same test.
	attacker.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	defender.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	return id

func test_below_power_threshold_selects_base_grapple() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.POWER_THRESHOLD - 1.0)
	assert_str(id).is_equal(&"grapple")

func test_at_power_threshold_selects_power_move() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.POWER_THRESHOLD)
	assert_str(id).is_equal(&"power")

func test_at_signature_threshold_selects_signature_move() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.SIGNATURE_THRESHOLD)
	assert_str(id).is_equal(&"signature")

func test_at_finisher_threshold_selects_finisher_move() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.FINISHER_THRESHOLD)
	assert_str(id).is_equal(&"finisher")

func test_missing_power_move_falls_back_to_base_grapple() -> void:
	var pair := _make_grappling_pair()
	pair[0].power_move = null
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.POWER_THRESHOLD)
	assert_str(id).is_equal(&"grapple")

## The chain half of the gate: momentum alone must not skip a rung.
##
## This is the bug the chain exists for. The signature band is 8 wide
## (SIGNATURE_THRESHOLD to FINISHER_THRESHOLD) and a wrestler earns 10-20
## between two consecutive grapples, so a full meter used to select a
## finisher from a man who had never thrown a signature -- measured over ten
## AI-vs-AI seeds, every seed that reached a finisher had skipped the
## signature entirely.
func test_a_full_meter_does_not_skip_the_signature() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.MOMENTUM_MAX,
		CombatSystem.Tier.POWER)
	assert_str(id).override_failure_message(
		"A wrestler who has never landed a signature selected a finisher."
	).is_equal(&"signature")

func test_a_full_meter_does_not_skip_the_power_move() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.MOMENTUM_MAX,
		CombatSystem.Tier.GRAPPLE)
	assert_str(id).is_equal(&"power")

## And the bottom of the chain: a wrestler's first grapple is a grapple,
## whatever his meter says. Strikes feed the same meter, so without this a
## match that opened with three jabs opened its grapple chain at the power
## tier and the four base grapple moves never played.
func test_the_first_grapple_of_a_match_is_a_grapple() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.MOMENTUM_MAX, -1)
	assert_str(id).is_equal(&"grapple")

## Landing a rung is what unlocks the next one, and it is recorded when the
## move resolves rather than when it is chosen -- a grapple that gets
## reversed was never thrown.
func test_landing_a_rung_unlocks_the_one_above_it() -> void:
	var pair := _make_grappling_pair()
	var attacker: WrestlerController = pair[0]
	attacker.combat.momentum = CombatSystem.MOMENTUM_MAX
	assert_bool(attacker.combat.can_power()).is_false()
	attacker.combat.record_tier(attacker.tier_of(attacker.grapple_move))
	assert_bool(attacker.combat.can_power()).is_true()
	assert_bool(attacker.combat.can_signature()).is_false()
	attacker.combat.record_tier(attacker.tier_of(attacker.power_move))
	assert_bool(attacker.combat.can_signature()).is_true()
	assert_bool(attacker.combat.can_finisher()).is_false()
	attacker.combat.record_tier(attacker.tier_of(attacker.signature_move))
	assert_bool(attacker.combat.can_finisher()).is_true()

## A strike is not a rung of the grapple chain, so throwing one cannot
## advance it.
func test_a_strike_is_not_a_rung() -> void:
	var pair := _make_grappling_pair()
	var attacker: WrestlerController = pair[0]
	attacker.strike_move = _make_move(&"strike")
	assert_int(attacker.tier_of(attacker.strike_move)).is_equal(-1)
	attacker.combat.record_tier(attacker.tier_of(attacker.strike_move))
	assert_int(attacker.combat.tier_reached).is_equal(-1)
