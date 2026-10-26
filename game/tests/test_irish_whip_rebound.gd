extends GdUnitTestSuite
## Off the ropes, the whipper's move (the owner, 25 Oct: "AI staples: Irish
## whips"). The man sent into the ropes comes back to be hit -- Roman's
## spinebuster, Cody's dropdown uppercut -- instead of the runner throwing a
## free running attack at the man who whipped him. And a whip into a corner
## traps him against the turnbuckle, where the corner offence starts.

const MATCH := "res://scenes/match.tscn"


func _roman_vs_cody() -> Node:
	var scene: Node = auto_free(load(MATCH).instantiate())
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	add_child(scene)
	return scene


## Puts `whipper` and `runner` in a hold and has `whipper` throw the whip.
func _whip(whipper: WrestlerController, runner: WrestlerController, corner := false) -> void:
	whipper.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	runner.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	whipper._begin_irish_whip(corner)


func test_roman_and_cody_carry_their_rebound_moves() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	var ids := func(moves: Array[MoveDef]) -> Array:
		return moves.map(func(m: MoveDef) -> String: return String(m.animation_pair_id))
	# Batch 2 of the FF library adds the Oklahoma Stampede: caught, carried.
	assert_array(ids.call(roman.rebound_moves)) \
		.contains_exactly(["ff_spinebuster_5", "power_samoan_drop", "power_powerslam",
				"ff_oklahoma_stampede"])
	assert_array(ids.call(cody.rebound_moves)) \
		.contains_exactly(["strike_dropdown_uppercut", "power_powerslam"])
	# What each does to a man whipped into the corner: Roman's clotheslines,
	# Cody's knife-edge chops.
	assert_str(String(roman.corner_strike_move.animation_pair_id)) \
		.is_equal("strike_corner_clothesline")
	assert_str(String(cody.corner_strike_move.animation_pair_id)).is_equal("strike_chop")
	assert_bool(cody.anim_player.has_animation("strikes/strike_chop")).is_true()


func test_the_whipper_catches_him_coming_off_the_ropes() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	roman.global_position = Vector3(-0.5, 0.0, 0.0)
	cody.global_position = Vector3(0.5, 0.0, 0.0)
	await get_tree().physics_frame
	_whip(roman, cody)
	assert_int(cody.fsm.current_state).is_equal(WrestlerFSM.State.IRISH_WHIP)
	var returned := false
	var caught := false
	for i in 150:
		await get_tree().physics_frame
		returned = returned or cody.is_whip_returning()
		# The runner has no say: he never throws his own running attack.
		assert_int(cody.fsm.current_state).is_not_equal(WrestlerFSM.State.RUNNING_ATTACK)
		if cody.is_whip_returning() and roman.try_rebound_move():
			caught = true
			break
	assert_bool(returned).is_true()
	assert_bool(caught).is_true()
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.GRAPPLE_HOLD)
	assert_int(cody.fsm.current_state).is_equal(WrestlerFSM.State.GRAPPLE_HOLD)
	assert_bool(roman._is_grapple_attacker).is_true()
	assert_int(cody._irish_whip_return_ticks_remaining).is_equal(0)


func test_a_rebound_strike_lands_as_he_arrives() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	cody.global_position = Vector3(0.5, 0.0, 0.0)
	roman.global_position = Vector3(-0.5, 0.0, 0.0)
	await get_tree().physics_frame
	_whip(cody, roman)
	# Cody's draw puts the uppercut first; fix it for the test.
	cody._rebound_pick = cody.rebound_moves[0]
	var thrown_at := -1.0
	var stood := 0
	var hit := false
	for i in 150:
		await get_tree().physics_frame
		# Cody is the AI here and throws it himself; ask too, in case not.
		if thrown_at < 0.0 and roman.is_whip_returning() \
				and cody.fsm.current_state != WrestlerFSM.State.STRIKE:
			cody.try_rebound_move()
		if thrown_at < 0.0 and cody.fsm.current_state == WrestlerFSM.State.STRIKE:
			thrown_at = (roman.global_position - cody.global_position).length()
			assert_str(String(cody._active_move.animation_pair_id)) \
				.is_equal("strike_dropdown_uppercut")
		if thrown_at > 0.0 and roman.fsm.current_state == WrestlerFSM.State.RUN \
				and Vector2(roman.velocity.x, roman.velocity.z).length() < 0.05:
			stood += 1
		if roman.fsm.current_state != WrestlerFSM.State.RUN and thrown_at > 0.0:
			hit = true
			break
	# Thrown before he arrives, and it lands: he is not left standing in
	# front of it waiting (the uppercut's startup is longer than his run).
	assert_float(thrown_at).is_greater(WrestlerController.REBOUND_STRIKE_MEET)
	assert_bool(hit).is_true()
	assert_int(stood).is_less_equal(3)
	assert_int(roman.fsm.current_state).is_not_equal(WrestlerFSM.State.RUNNING_ATTACK)


func test_whipped_into_a_corner_he_is_trapped_against_the_turnbuckle() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	roman.global_position = Vector3(0.0, 0.0, 0.0)
	cody.global_position = Vector3(1.0, 0.0, 0.5)
	await get_tree().physics_frame
	_whip(roman, cody, true)
	var trapped := false
	for i in 90:
		await get_tree().physics_frame
		if cody.is_corner_trapped():
			trapped = true
			break
	assert_bool(trapped).is_true()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var at := Vector2(cody.global_position.x, cody.global_position.z)
	assert_float(at.distance_to(Vector2(WrestlerController.CORNER_SPOT,
			WrestlerController.CORNER_SPOT))).is_less(0.35)


func test_the_corner_whip_goes_to_the_buckle_most_in_line() -> void:
	var dir := WrestlerController.corner_whip_dir(Vector3(1.0, 0.0, 0.5), Vector3(1.0, 0.0, 0.0))
	assert_float(dir.x).is_greater(0.0)
	assert_float(dir.z).is_greater(0.0)
	# Never the corner he is already in.
	var c := WrestlerController.CORNER_SPOT
	dir = WrestlerController.corner_whip_dir(Vector3(c, 0.0, c), Vector3(0.7, 0.0, 0.7))
	assert_float(dir.x + dir.z).is_less(1.0)
