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


# --- the getup in stages, the pick-up, the double-down -------------------------

func _two_men() -> Array:
	var scene: Node = auto_free(load(MATCH).instantiate())
	add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.is_ai = false
	b.is_ai = false
	return [scene, a, b]


func test_a_man_who_rises_on_his_own_does_it_in_stages() -> void:
	var men := await _two_men()
	var b: WrestlerController = men[2]
	await get_tree().physics_frame
	b.fsm.transition_to(WrestlerFSM.State.STUNNED)
	b.fsm.transition_to(WrestlerFSM.State.DOWN)
	b._move_ticks_remaining = 1
	b._process_down({})
	assert_int(b.fsm.current_state).is_equal(WrestlerFSM.State.GETUP)
	assert_int(b._move_ticks_remaining).is_equal(WrestlerController.GETUP_STAGED_TICKS)
	# The staged clip is the rise with a breath on his hands and knees in it.
	var staged: Animation = WrestlerController.STRIKE_CLIPS.get_animation("getup_staged")
	var rise: Animation = WrestlerController.STRIKE_CLIPS.get_animation("getup_rise")
	assert_float(staged.length).is_greater(rise.length + 0.9)
	assert_float(staged.length * 60.0).is_equal_approx(float(WrestlerController.GETUP_STAGED_TICKS), 1.0)


func test_a_man_worked_over_is_hauled_to_his_feet() -> void:
	var men := await _two_men()
	var a: WrestlerController = men[1]
	var b: WrestlerController = men[2]
	await get_tree().physics_frame
	b.fsm.transition_to(WrestlerFSM.State.STUNNED)
	b.fsm.transition_to(WrestlerFSM.State.DOWN)
	b._move_ticks_remaining = 600
	b.ground_attacks_taken = 1
	var head := WrestlerController.ground_target(b, "head")
	a.global_position = head + (-b.global_basis.z) * 0.6
	assert_bool(a.can_pickup(b)).is_false()   # not worked over yet
	b.ground_attacks_taken = WrestlerController.PICKUP_AFTER_ATTACKS
	assert_bool(a.can_pickup(b)).is_true()
	a.begin_pickup(b)
	assert_int(a.fsm.current_state).is_equal(WrestlerFSM.State.STRIKE)
	assert_int(b.fsm.current_state).is_equal(WrestlerFSM.State.GETUP)
	assert_int(b._move_ticks_remaining).is_equal(WrestlerController.PICKUP_TICKS)
	assert_bool(b.picked_up).is_true()
	assert_bool(a.can_pickup(b)).is_false()   # once a knockdown
	var hit := b.combat.wear
	for i in WrestlerController.PICKUP_TICKS + 4:
		await get_tree().physics_frame
	assert_float(b.combat.wear).is_equal(hit)   # a haul is not a blow
	assert_bool(b.fsm.current_state != WrestlerFSM.State.DOWN).is_true()
	assert_bool(b.fsm.current_state != WrestlerFSM.State.GETUP).is_true()


func test_a_kicked_out_finisher_leaves_both_men_selling() -> void:
	var men := await _two_men()
	var scene: Node = men[0]
	var a: WrestlerController = men[1]
	var b: WrestlerController = men[2]
	var referee: MatchReferee = scene.get_node("MatchReferee")
	await get_tree().physics_frame
	b.fsm.transition_to(WrestlerFSM.State.STUNNED)
	b.fsm.transition_to(WrestlerFSM.State.DOWN)
	b.knockdown_tier = CombatSystem.Tier.FINISHER
	a.fsm.transition_to(WrestlerFSM.State.PIN_ATTACKER)
	b.fsm.transition_to(WrestlerFSM.State.PIN_DEFENDER)
	referee._pinning = true
	referee._pin_attacker = a
	referee._pin_defender = b
	referee._end_pin(false)
	assert_int(a.fsm.current_state).is_equal(WrestlerFSM.State.GETUP)
	assert_int(a._move_ticks_remaining).is_equal(WrestlerController.GETUP_STAGED_TICKS)
	assert_int(b.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	assert_int(b._move_ticks_remaining).is_equal(WrestlerController.DOUBLE_DOWN_STIR_TICKS)


func test_a_kickout_of_a_lesser_move_leaves_the_pinner_on_his_feet() -> void:
	var men := await _two_men()
	var scene: Node = men[0]
	var a: WrestlerController = men[1]
	var b: WrestlerController = men[2]
	var referee: MatchReferee = scene.get_node("MatchReferee")
	await get_tree().physics_frame
	b.fsm.transition_to(WrestlerFSM.State.STUNNED)
	b.fsm.transition_to(WrestlerFSM.State.DOWN)
	b.knockdown_tier = CombatSystem.Tier.SIGNATURE
	a.fsm.transition_to(WrestlerFSM.State.PIN_ATTACKER)
	b.fsm.transition_to(WrestlerFSM.State.PIN_DEFENDER)
	referee._pinning = true
	referee._pin_attacker = a
	referee._pin_defender = b
	referee._end_pin(false)
	assert_int(a.fsm.current_state).is_equal(WrestlerFSM.State.IDLE)
