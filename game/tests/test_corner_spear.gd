extends GdUnitTestSuite
## Roman's corner Spear is thrown only at a man hanging in a corner: it is a
## tier of its own on the roster (not part of any draw), and try_corner_spear()
## refuses everywhere else.

const MATCH := "res://scenes/match.tscn"

func _roman_vs_cody() -> Node:
	var scene: Node = auto_free(load(MATCH).instantiate())
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	add_child(scene)
	return scene

func test_romans_roster_carries_the_corner_move_and_cody_has_none() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	assert_object(roman.corner_move).is_not_null()
	assert_str(String(roman.corner_move.animation_pair_id)).is_equal("running_corner_spear")
	assert_object(cody.corner_move).is_null()
	assert_bool(PairedRecipes.RECIPES.has("running_corner_spear")).is_true()
	# Not in the shared running pool: it cannot be drawn in the open ring.
	for move: MoveDef in [roman.running_attack_move] + roman.running_attack_move_pool:
		assert_str(String(move.animation_pair_id)).is_not_equal("running_corner_spear")

func test_it_is_refused_unless_the_man_is_trapped_in_a_corner() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	assert_bool(cody.is_corner_trapped()).is_false()
	assert_bool(roman.try_corner_spear()).is_false()
	assert_bool(cody.try_corner_spear()).is_false()
	assert_int(roman.fsm.current_state).is_not_equal(WrestlerFSM.State.GRAPPLE_HOLD)

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
