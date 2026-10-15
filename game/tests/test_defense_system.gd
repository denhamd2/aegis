extends GdUnitTestSuite

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")

func test_only_quick_basic_strikes_are_guardable() -> void:
	var jab: MoveDef = load("res://resources/moves/strike_jab.tres")
	var heavy: MoveDef = load("res://resources/moves/strike_kick_heavy.tres")
	var finisher: MoveDef = load("res://resources/moves/finisher_cross_rhodes.tres")
	assert_bool(DefenseSystem.is_guardable_strike(jab)).is_true()
	assert_bool(DefenseSystem.is_guardable_strike(heavy)).is_false()
	assert_bool(DefenseSystem.is_guardable_strike(finisher)).is_false()
	assert_bool(DefenseSystem.is_guardable_strike(jab, true)).is_false()


func test_a_health_lead_and_stamina_make_a_block_more_effective() -> void:
	var trailing := DefenseSystem.blocked_damage_scale(0.3, 0.8, 1.0)
	var even := DefenseSystem.blocked_damage_scale(0.6, 0.6, 1.0)
	var leading := DefenseSystem.blocked_damage_scale(0.9, 0.4, 1.0)
	var exhausted := DefenseSystem.blocked_damage_scale(0.9, 0.4, 0.0)
	assert_float(leading).is_less(even)
	assert_float(even).is_less(trailing)
	assert_float(exhausted).is_greater(leading)
	assert_float(leading).is_greater_equal(0.4)


func test_ai_is_more_likely_to_guard_when_ahead_and_fresh() -> void:
	var behind := DefenseSystem.ai_guard_chance(0.35, 0.8, 0.8)
	var even := DefenseSystem.ai_guard_chance(0.6, 0.6, 0.8)
	var ahead := DefenseSystem.ai_guard_chance(0.9, 0.4, 0.8)
	var tired := DefenseSystem.ai_guard_chance(0.9, 0.4, 0.1)
	assert_float(ahead).is_greater(even)
	assert_float(even).is_greater(behind)
	assert_float(ahead).is_greater(tired)
	assert_float(behind).is_greater_equal(0.06)


func test_guard_reduces_a_facing_basic_strike_without_knocking_down() -> void:
	var defender: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	var striker: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(defender)
	add_child(striker)
	defender.opponent = striker
	striker.opponent = defender
	defender.global_position = Vector3.ZERO
	striker.global_position = Vector3(0.0, 0.0, -0.8)
	defender._guarding = true
	var jab: MoveDef = load("res://resources/moves/strike_jab.tres")
	assert_bool(defender._take_guarded_strike(striker, jab)).is_true()
	assert_float(defender.combat.wear).is_equal_approx(3.5, 0.01)
	assert_int(defender.guard_blocks).is_equal(1)
	assert_int(defender._pending_hits.size()).is_equal(0)
