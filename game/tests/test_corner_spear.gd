extends GdUnitTestSuite
## Roman's corner Spear and Cody's corner knee are thrown only at a man hanging
## in a corner: each is a tier of its own on the roster (not part of any draw),
## and try_corner_spear() refuses everywhere else.

const MATCH := "res://scenes/match.tscn"

func _roman_vs_cody() -> Node:
	var scene: Node = auto_free(load(MATCH).instantiate())
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	add_child(scene)
	return scene

func test_each_roster_carries_its_own_corner_move() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	assert_object(roman.corner_move).is_not_null()
	assert_str(String(roman.corner_move.animation_pair_id)).is_equal("running_corner_spear")
	# Cody's is the running knee (ff_moves_and_gameplay_plan.md, staples 4 and 7).
	assert_object(cody.corner_move).is_not_null()
	assert_str(String(cody.corner_move.animation_pair_id)).is_equal("running_corner_knee")
	for id: String in ["running_corner_spear", "running_corner_knee"]:
		assert_bool(PairedRecipes.RECIPES.has(id)).is_true()
		assert_str(PairedContacts.family(load("res://resources/moves/%s.tres" % id))).is_equal("none")
	# Not in the shared running pool: neither can be drawn in the open ring.
	for man: WrestlerController in [roman, cody]:
		for move: MoveDef in [man.running_attack_move] + man.running_attack_move_pool:
			assert_str(String(move.animation_pair_id)).is_not_equal(String(man.corner_move.animation_pair_id))

func test_it_is_refused_unless_the_man_is_trapped_in_a_corner() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	assert_bool(cody.is_corner_trapped()).is_false()
	assert_bool(roman.is_corner_trapped()).is_false()
	assert_bool(roman.try_corner_spear()).is_false()
	assert_bool(cody.try_corner_spear()).is_false()
	assert_int(roman.fsm.current_state).is_not_equal(WrestlerFSM.State.GRAPPLE_HOLD)
	assert_int(cody.fsm.current_state).is_not_equal(WrestlerFSM.State.GRAPPLE_HOLD)

func test_it_starts_on_a_man_trapped_in_a_corner() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	cody.global_position = Vector3(2.6, 0.0, 2.6)
	roman.global_position = Vector3(1.4, 0.0, 1.4)
	cody.fsm.transition_to(WrestlerFSM.State.STUNNED)
	cody._corner_trapped = true
	assert_bool(cody.is_corner_trapped()).is_true()
	assert_bool(roman.try_corner_spear()).is_true()
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.GRAPPLE_HOLD)
	assert_int(cody.fsm.current_state).is_equal(WrestlerFSM.State.GRAPPLE_HOLD)


## Cody's corner knee, played through: Roman trapped in the buckle takes the
## knee and ends up down, hurt, still in the ring and not knocked through the
## corner.
func test_codys_corner_knee_puts_the_man_in_the_buckle_down() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	roman.is_ai = false
	cody.is_ai = false
	var spot := WrestlerController.CORNER_SPOT
	roman.global_position = Vector3(spot, 0.0, spot)
	cody.global_position = Vector3(spot - 0.85, 0.0, spot - 0.85)
	roman.fsm.transition_to(WrestlerFSM.State.STUNNED)
	roman._corner_trapped = true
	var before := roman.combat.total_damage()
	assert_bool(cody.try_corner_spear()).is_true()
	assert_int(cody.fsm.current_state).is_equal(WrestlerFSM.State.GRAPPLE_HOLD)
	var down := false
	for i in 400:
		await get_tree().physics_frame
		if roman.fsm.current_state == WrestlerFSM.State.DOWN:
			down = true
			break
	assert_bool(down).override_failure_message("Roman never went down").is_true()
	assert_float(roman.combat.total_damage()).is_greater(before)
	# Pitched out of the corner onto his face, inside the ropes.
	assert_float(absf(roman.global_position.x)).is_less(3.0)
	assert_float(absf(roman.global_position.z)).is_less(3.0)
	assert_bool(roman.outside_ring).is_false()
