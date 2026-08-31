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
