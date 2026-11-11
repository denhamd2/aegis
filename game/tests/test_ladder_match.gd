extends GdUnitTestSuite
## The Ladder match and TLC (gauntlet/refs/ladder_match.md): the belt hung
## over the ring, a ladder stood up under it, climbed, and the belt tugged off
## its hook to win; knocked off the ladder first and it springs back; no
## pinfalls.

var _scene: Node


func after_test() -> void:
	_scene = null


func _match(mode := MatchRules.Mode.LADDER) -> Node:
	_scene = auto_free(load("res://scenes/match.tscn").instantiate())
	TitleScreen.configure_match(_scene, Roster.by_id("roman"), Roster.by_id("cody"), 1,
			false, mode)
	for part in ["Arena", "LightRig"]:
		_scene.get_node(part).free()
	_scene.entrances = false
	add_child(_scene)
	return _scene


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ladder_under_prize(by: WrestlerController) -> WeaponActor:
	var stock := WeaponStock.of(by)
	var ladder := stock.pull(WeaponCatalog.by_id(&"ladder"))
	var yaw := 0.0
	ladder.set_up_at(WrestlerController.ladder_under_prize(Vector3.ZERO, yaw), yaw, "Ladder_Open")
	return ladder


func test_the_rules() -> void:
	for mode: int in [MatchRules.Mode.LADDER, MatchRules.Mode.TLC]:
		var n := Node.new()
		MatchRules.set_mode(n, mode)
		assert_bool(MatchRules.prize_hangs(n)).is_true()
		assert_bool(MatchRules.pins_count(n)).is_false()
		assert_bool(MatchRules.no_holds_barred(n)).is_true()
		assert_bool(MatchRules.caged(n)).is_false()
		assert_bool(MatchRules.ladders_in_play(n)).is_true()
		n.free()
	var tlc := Node.new()
	MatchRules.set_mode(tlc, MatchRules.Mode.TLC)
	assert_bool(MatchRules.tables_and_chairs(tlc)).is_true()
	tlc.free()
	assert_str(MatchRules.label(MatchRules.Mode.LADDER)).is_equal("LADDER")
	assert_str(MatchRules.label(MatchRules.Mode.TLC)).is_equal("TLC")


func test_the_belt_hangs_over_the_ring_out_of_reach_from_the_mat() -> void:
	var scene := _match()
	await _ticks(2)
	var prize := scene.get_node_or_null("HangingPrize") as HangingPrize
	assert_object(prize).is_not_null()
	# Above anyone's reach from the canvas (2.3 m with his arms up), within
	# it from the ladder's top (ladder.glb's top 3.01 m, + ~2 m).
	assert_float(HangingPrize.AT.y).is_between(4.3, 5.1)
	assert_bool(prize.reachable_from(Vector3(0.1, 2.8, 0.1))).is_true()
	assert_bool(prize.reachable_from(Vector3(1.2, 2.8, 0.0))).is_false()


func test_a_ladder_stood_up_near_the_belt_goes_under_it() -> void:
	for yaw: float in [0.0, 1.1, -2.4]:
		var at := WrestlerController.ladder_under_prize(Vector3(0.7, 0.0, -0.4), yaw)
		var basis := Basis(Vector3.UP, yaw)
		var mount := at + basis * Vector3(0.0, 0.0, -WrestlerController.LADDER_TOP_IN)
		assert_float(Vector2(mount.x, mount.z).length()).is_less(0.01)


func test_up_the_ladder_under_it_he_pulls_the_belt_down_and_wins() -> void:
	var scene := _match()
	await _ticks(2)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	var referee := scene.get_node("MatchReferee") as MatchReferee
	cody.set_physics_process(false)
	cody.global_position = Vector3(-2.2, 0, 2.2)
	var won: Array = []
	referee.match_won.connect(func(w: WrestlerController, how: String) -> void: won.append([w, how]))
	var ladder := _ladder_under_prize(roman)
	await _ticks(1)
	roman.is_ai = false
	roman.fsm.transition_to(WrestlerFSM.State.IDLE)
	roman.global_position = ladder.global_transform * Vector3(0, 0, -WrestlerController.LADDER_FRONT_OFFSET)
	assert_bool(roman.begin_ladder_climb(ladder)).is_true()
	roman.set_physics_process(false)
	var prize := HangingPrize.of(roman)
	for i in 600:
		roman._tick_ladder_climb({"move": Vector2(0.0, -1.0)})
		await _ticks(1)
		if not won.is_empty():
			break
	assert_bool(roman.is_unhooking() or prize.won_by == roman).is_true()
	assert_object(prize.won_by).is_same(roman)
	assert_int(won.size()).is_equal(1)
	assert_object(won[0][0]).is_same(roman)
	assert_str(won[0][1]).is_equal("ladder")


func test_knocked_off_before_he_has_it_it_springs_back() -> void:
	var scene := _match()
	await _ticks(2)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	cody.set_physics_process(false)
	var ladder := _ladder_under_prize(roman)
	await _ticks(1)
	roman.fsm.transition_to(WrestlerFSM.State.IDLE)
	roman.global_position = ladder.global_transform * Vector3(0, 0, -WrestlerController.LADDER_FRONT_OFFSET)
	assert_bool(roman.begin_ladder_climb(ladder)).is_true()
	roman.set_physics_process(false)
	var prize := HangingPrize.of(roman)
	for i in 400:
		roman._tick_ladder_climb({"move": Vector2(0.0, -1.0)})
		await _ticks(1)
		if prize.unhook > 40:
			break
	assert_int(prize.unhook).is_greater(40)
	# The other man at the ladder tips it.
	cody.fsm.transition_to(WrestlerFSM.State.IDLE)
	cody.global_position = ladder.global_position + Vector3(1.0, 0, 0)
	assert_bool(cody.can_tip_ladder()).is_true()
	assert_bool(cody.tip_ladder()).is_true()
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.LADDER_FALL)
	assert_int(prize.unhook).is_equal(0)
	assert_object(prize.won_by).is_null()


func test_no_pinfalls_in_a_ladder_match() -> void:
	var scene := _match()
	await _ticks(2)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	var referee := scene.get_node("MatchReferee") as MatchReferee
	assert_bool(MatchRules.pins_count(referee)).is_false()
	assert_bool(referee._wants_own_hold(roman)).is_false()
	cody.global_position = Vector3(0, 0, 0)
	roman.global_position = Vector3(0.6, 0, 0.3)
	cody.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	cody.fsm.transition_to(WrestlerFSM.State.DOWN)
	cody._move_ticks_remaining = 100000
	cody.set_physics_process(false)
	roman.is_ai = false
	await _ticks(60)
	assert_int(roman.fsm.current_state).is_not_equal(WrestlerFSM.State.PIN_ATTACKER)


func test_tlc_lays_tables_ladders_and_chairs_round_the_ring() -> void:
	var scene := _match(MatchRules.Mode.TLC)
	await _ticks(2)
	var stock := WeaponStock.of(scene.get_node("WrestlerA"))
	var ids := {}
	for a in stock.tlc_actors:
		ids[a.def.id] = int(ids.get(a.def.id, 0)) + 1
		# On the floor outside the ring.
		assert_bool(absf(a.global_position.x) > RingBuilder.MAT_HALF \
				or absf(a.global_position.z) > RingBuilder.MAT_HALF).is_true()
	assert_int(int(ids.get(&"table", 0))).is_equal(2)
	assert_int(int(ids.get(&"ladder", 0))).is_equal(2)
	assert_int(int(ids.get(&"steel_chair", 0))).is_equal(4)
	assert_object(scene.get_node_or_null("HangingPrize")).is_not_null()


func test_a_ladder_in_a_ladder_match_does_not_wear_out() -> void:
	var scene := _match()
	await _ticks(2)
	var ladder := WeaponStock.of(scene.get_node("WrestlerA")).pull(WeaponCatalog.by_id(&"ladder"))
	assert_int(ladder.match_lifetime_limit).is_greater(60 * 60 * 30)
