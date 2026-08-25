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
