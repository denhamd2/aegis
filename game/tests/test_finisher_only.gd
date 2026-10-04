extends GdUnitTestSuite
## Only a finisher wins (MatchReferee.can_be_finished): a cover straight off
## the pinning man's finisher can count three; any other cover is a near-fall,
## kicked out just before the third slap. And the finisher is shot as a
## sequence (MatchCamera.finish_shot_for).

var _scene: Node


func before_test() -> void:
	_scene = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(_scene, pair[0], pair[1], 3)
	_scene.entrances = false
	add_child(_scene)
	# The match is in its finish: before FINISH_FROM a finisher is only a
	# near-fall (MatchFlow; tests/test_match_flow.gd covers that gate).
	(_scene.get_node("MatchFlow") as MatchFlow).tick = int(MatchFlow.FINISH_FROM * 60.0)


func after_test() -> void:
	_scene.queue_free()


func test_the_near_fall_comes_after_two_and_before_three() -> void:
	assert_int(MatchReferee.NEAR_FALL_KICKOUT_TICK).is_greater(MatchReferee.COUNT_TICKS[1])
	assert_int(MatchReferee.NEAR_FALL_KICKOUT_TICK).is_less(MatchReferee.PIN_COUNT_TICKS)


func test_only_the_finisher_makes_a_cover_winnable() -> void:
	var referee: MatchReferee = _scene.get_node("MatchReferee")
	var a: WrestlerController = _scene.get_node("WrestlerA")
	var b: WrestlerController = _scene.get_node("WrestlerB")
	assert_bool(referee.can_be_finished(b)).is_false()
	a.move_landed.emit(a, b, a.strike_move)
	assert_bool(referee.can_be_finished(b)).is_false()
	a.move_landed.emit(a, b, a.finisher_move)
	assert_bool(referee.can_be_finished(b)).is_true()
	# A strike after it (the finisher kicked out of) takes it away again.
	a.move_landed.emit(a, b, a.strike_move)
	assert_bool(referee.can_be_finished(b)).is_false()


## The loophole the owner hit: Cross Rhodes kicked out of, then a tope (dive
## damage never "lands" a move), then the cover -- it counted three.
func test_damage_by_any_path_shuts_the_finisher_window() -> void:
	var referee: MatchReferee = _scene.get_node("MatchReferee")
	var a: WrestlerController = _scene.get_node("WrestlerA")
	var b: WrestlerController = _scene.get_node("WrestlerB")
	a.move_landed.emit(a, b, a.finisher_move)
	# The finisher's own damage keeps it open.
	b.combat.apply_damage(a.finisher_move)
	assert_bool(referee.can_be_finished(b)).is_true()
	# A dive's damage, which emits no move_landed, shuts it.
	b.combat.apply_damage(load(DiveSpot.TOPE_MOVE) as MoveDef)
	assert_bool(referee.can_be_finished(b)).is_false()


func test_getting_up_shuts_the_finisher_window() -> void:
	var referee: MatchReferee = _scene.get_node("MatchReferee")
	var a: WrestlerController = _scene.get_node("WrestlerA")
	var b: WrestlerController = _scene.get_node("WrestlerB")
	a.move_landed.emit(a, b, a.finisher_move)
	b.fsm.state_changed.emit(WrestlerFSM.State.GETUP, WrestlerFSM.State.IDLE)
	assert_bool(referee.can_be_finished(b)).is_false()


func test_each_man_has_a_finisher_to_win_with() -> void:
	for n in ["WrestlerA", "WrestlerB"]:
		var w: WrestlerController = _scene.get_node(n)
		assert_object(w.finisher_move).override_failure_message(n).is_not_null()
		assert_bool(w.is_finisher(w.finisher_move)).is_true()


func test_the_finisher_is_three_shots_in_order() -> void:
	assert_int(MatchCamera.finish_shot_for(0.0)).is_equal(0)
	assert_int(MatchCamera.finish_shot_for(MatchCamera.FINISH_SETUP_END - 0.01)).is_equal(0)
	assert_int(MatchCamera.finish_shot_for(MatchCamera.FINISH_SETUP_END + 0.01)).is_equal(1)
	assert_int(MatchCamera.finish_shot_for(MatchCamera.FINISH_IMPACT_END + 0.01)).is_equal(2)
	# The landing, and its shake, fall inside the impact shot.
	assert_float(MatchCamera.FINISH_IMPACT_AT).is_between(
			MatchCamera.FINISH_SETUP_END, MatchCamera.FINISH_IMPACT_END)
	# The setup is a close on a long lens, the impact a spectacle wide.
	assert_float(MatchCamera.FINISH_SETUP_FOV.y).is_less(30.0)
	assert_float(MatchCamera.FINISH_IMPACT_FOV).is_greater(50.0)
