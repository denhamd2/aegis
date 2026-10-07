extends GdUnitTestSuite
## Match flow to 2K26 (gauntlet/refs/match_engine_2k26.md, section 3): a man
## stays down longer after the bigger move, and the man in control covers
## after the big ones rather than after every knockdown.

const MATCH := "res://scenes/match.tscn"


func test_down_time_grows_with_the_move_that_put_him_down() -> void:
	var strike := WrestlerController.down_ticks_for(-1)
	var power := WrestlerController.down_ticks_for(CombatSystem.Tier.POWER)
	var sig := WrestlerController.down_ticks_for(CombatSystem.Tier.SIGNATURE)
	var finisher := WrestlerController.down_ticks_for(CombatSystem.Tier.FINISHER)
	assert_int(strike).is_equal(WrestlerController.DOWN_TICKS_STRIKE)
	assert_int(power).is_equal(WrestlerController.DOWN_TICKS_POWER)
	assert_int(sig).is_equal(WrestlerController.DOWN_TICKS_POWER)
	assert_int(finisher).is_equal(WrestlerController.DOWN_TICKS_FINISHER)
	assert_bool(strike < power and power < finisher).is_true()
	# 2K26's man stays down 5-27 s.
	assert_float(strike / 60.0).is_greater_equal(5.0)
	assert_float(finisher / 60.0).is_less_equal(27.0)


func test_a_knockdown_records_its_tier_and_sets_the_down_time() -> void:
	var scene: Node = auto_free(load(MATCH).instantiate())
	add_child(scene)
	var w: WrestlerController = scene.get_node("WrestlerB")
	w._go_down(CombatSystem.Tier.SIGNATURE)
	assert_int(w.knockdown_tier).is_equal(CombatSystem.Tier.SIGNATURE)
	assert_int(w._move_ticks_remaining).is_equal(WrestlerController.DOWN_TICKS_POWER)


func test_the_referee_covers_after_big_moves_but_not_every_knockdown() -> void:
	var scene: Node = auto_free(load(MATCH).instantiate())
	add_child(scene)
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var w: WrestlerController = scene.get_node("WrestlerB")
	var flow := MatchFlow.new()
	auto_free(flow)
	w.flow = flow
	flow.tick = 100 * 60   # the middle of the match, not the finish
	w.knockdown_tier = -1
	assert_bool(referee.wants_cover(w)).is_false()
	w.knockdown_tier = CombatSystem.Tier.SIGNATURE
	assert_bool(referee.wants_cover(w)).is_true()
	w.knockdown_tier = -1
	flow.tick = 500 * 60   # the finish
	assert_bool(referee.wants_cover(w)).is_true()
