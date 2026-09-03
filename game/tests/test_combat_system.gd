extends GdUnitTestSuite
## Kickout target sizing vs limb damage.

func test_kickout_window_shrinks_with_damage() -> void:
	var combat := CombatSystem.new()
	var full_window := combat.kickout_window_fraction(0.0)

	var move := MoveDef.new()
	move.damage_head = 50.0
	move.damage_torso = 50.0
	combat.apply_move(move)

	var damaged_window := combat.kickout_window_fraction(0.0)
	assert_float(damaged_window).is_less(full_window)

func test_kickout_window_shrinks_with_opponent_momentum() -> void:
	var combat := CombatSystem.new()
	var low_momentum_window := combat.kickout_window_fraction(0.0)
	var high_momentum_window := combat.kickout_window_fraction(100.0)
	assert_float(high_momentum_window).is_less(low_momentum_window)

func test_most_damaged_limb_defaults_to_head_when_untouched() -> void:
	var combat := CombatSystem.new()
	assert_int(combat.most_damaged_limb()).is_equal(CombatSystem.Limb.HEAD)

func test_most_damaged_limb_picks_the_higher_damage_limb() -> void:
	var combat := CombatSystem.new()
	var move := MoveDef.new()
	move.damage_legs = 40.0
	move.damage_arms = 10.0
	combat.apply_move(move)
	assert_int(combat.most_damaged_limb()).is_equal(CombatSystem.Limb.LEGS)

func test_can_power_is_false_below_threshold() -> void:
	var combat := CombatSystem.new()
	combat.momentum = CombatSystem.POWER_THRESHOLD - 1.0
	assert_bool(combat.can_power()).is_false()

func test_can_power_is_true_at_and_above_threshold() -> void:
	var combat := CombatSystem.new()
	# The gate is momentum *and* the rung below it (see tier_reached): a
	# wrestler who has not yet landed a grapple cannot open at the power tier
	# however full his meter is.
	combat.record_tier(CombatSystem.Tier.GRAPPLE)
	combat.momentum = CombatSystem.POWER_THRESHOLD
	assert_bool(combat.can_power()).is_true()
	combat.momentum = CombatSystem.SIGNATURE_THRESHOLD - 1.0
	assert_bool(combat.can_power()).is_true()

## The chain: each rung needs the one below it landed, not just the meter.
## Momentum is only read at a grapple and keeps rising between grapples, so
## arithmetic on a rising meter cannot order the chain by itself -- measured
## over ten AI-vs-AI seeds, every seed that reached a finisher had skipped
## the signature.
func test_a_full_meter_alone_opens_no_tier() -> void:
	var combat := CombatSystem.new()
	combat.momentum = CombatSystem.MOMENTUM_MAX
	assert_bool(combat.can_power()).is_false()
	assert_bool(combat.can_signature()).is_false()
	assert_bool(combat.can_finisher()).is_false()

func test_each_rung_needs_the_one_below_it() -> void:
	var combat := CombatSystem.new()
	combat.momentum = CombatSystem.MOMENTUM_MAX
	combat.record_tier(CombatSystem.Tier.GRAPPLE)
	assert_bool(combat.can_power()).is_true()
	assert_bool(combat.can_signature()).is_false()
	combat.record_tier(CombatSystem.Tier.POWER)
	assert_bool(combat.can_signature()).is_true()
	assert_bool(combat.can_finisher()).is_false()
	combat.record_tier(CombatSystem.Tier.SIGNATURE)
	assert_bool(combat.can_finisher()).is_true()

## A rung stays unlocked once earned -- the chain records how far a wrestler
## climbed this match, and spending the meter on a finisher does not send
## him back to square one.
func test_the_chain_does_not_fall_back() -> void:
	var combat := CombatSystem.new()
	combat.record_tier(CombatSystem.Tier.SIGNATURE)
	combat.record_tier(CombatSystem.Tier.GRAPPLE)
	assert_int(combat.tier_reached).is_equal(CombatSystem.Tier.SIGNATURE)

## Momentum is still the other half of the gate: a fully climbed chain with
## an empty meter opens nothing above the base grapple.
func test_the_chain_alone_does_not_pay_for_a_move() -> void:
	var combat := CombatSystem.new()
	combat.record_tier(CombatSystem.Tier.SIGNATURE)
	combat.momentum = 0.0
	assert_bool(combat.can_power()).is_false()
	assert_bool(combat.can_signature()).is_false()
	assert_bool(combat.can_finisher()).is_false()
