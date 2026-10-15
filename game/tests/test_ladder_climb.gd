extends GdUnitTestSuite

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func _wrestler() -> WrestlerController:
	var w: WrestlerController = WRESTLER_SCENE.instantiate()
	MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
	auto_free(w)
	add_child(w)
	return w


func _upright_ladder(w: WrestlerController) -> WeaponActor:
	var ladder := WeaponStock.of(w).pull(WeaponCatalog.by_id(&"ladder"))
	ladder.set_up_at(Vector3.ZERO, 0.0, "Ladder_Open")
	return ladder


func after_test() -> void:
	var stock := get_node_or_null("WeaponStock")
	if stock:
		stock.free()


func test_climbing_moves_up_and_returns_to_idle_at_the_base() -> void:
	var w := _wrestler()
	var ladder := _upright_ladder(w)
	w.global_position = Vector3(0.0, 0.0, -WrestlerController.LADDER_FRONT_OFFSET)
	assert_bool(ladder.is_climbable_ladder()).is_true()
	assert_bool(w._weapon_input({"weapon": true})).is_true()
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.LADDER_CLIMB)
	for i in 60:
		w._tick_ladder_climb({"move": Vector2(0.0, -1.0)})
	assert_float(w.ladder_climb_progress()).is_greater(0.2)
	for i in 180:
		if w.fsm.current_state != WrestlerFSM.State.LADDER_CLIMB:
			break
		w._tick_ladder_climb({"move": Vector2(0.0, 1.0)})
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.IDLE)
	assert_float(w.global_position.y).is_equal_approx(WrestlerController.FLOOR_LEVEL, 0.01)
	assert_bool(ladder.is_climbable_ladder()).is_true()


func test_a_hit_tips_the_ladder_and_the_climber_falls_to_down() -> void:
	var w := _wrestler()
	var ladder := _upright_ladder(w)
	w.global_position = Vector3(0.0, 0.0, -WrestlerController.LADDER_FRONT_OFFSET)
	assert_bool(w.begin_ladder_climb(ladder)).is_true()
	for i in 45:
		w._tick_ladder_climb({"move": Vector2(0.0, -1.0)})
	w._begin_ladder_fall()
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.LADDER_FALL)
	assert_bool(ladder.is_climbable_ladder()).is_false()
	for i in 90:
		await get_tree().physics_frame
		if w.fsm.current_state == WrestlerFSM.State.DOWN:
			break
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)


func test_a_carried_ladder_can_be_set_upright() -> void:
	var w := _wrestler()
	var ladder := WeaponStock.of(w).pull(WeaponCatalog.by_id(&"ladder"))
	w.take_weapon(ladder)
	assert_bool(w._weapon_input({"grapple": true, "set_ladder_upright": true})).is_true()
	assert_str(w._weapon_action).is_equal("set_up_upright")
	for i in 44:
		w._tick_weapon_action({})
	assert_bool(ladder.is_climbable_ladder()).is_true()
	assert_bool(ladder.global_position.x < RingBuilder.MAT_HALF).is_true()


func test_a_ladder_can_be_set_up_outside_and_folded_to_slide_under_the_ropes() -> void:
	var w := _wrestler()
	w.outside_ring = true
	w.global_position = Vector3(WrestlerController.DECK_KEEP_OUT + 0.2,
			WrestlerController.FLOOR_LEVEL, 0.0)
	var ladder := WeaponStock.of(w).pull(WeaponCatalog.by_id(&"ladder"))
	w.take_weapon(ladder)
	assert_bool(w._weapon_input({"grapple": true})).is_true()
	assert_str(w._weapon_action).is_equal("set_up_upright")
	for i in WrestlerController.WEAPON_ACTION_TICKS["set_up_upright"]:
		w._tick_weapon_action({})
	assert_bool(ladder.is_climbable_ladder()).is_true()
	assert_bool(ladder.global_position.x > RingBuilder.MAT_HALF).is_true()

	# Picking up the open set piece folds it to its carried ladder state. The
	# existing slide input then sends it through the bottom rope into the ring.
	w.global_position = ladder.global_position + Vector3(0.0, 0.0, -0.4)
	assert_bool(w._weapon_input({"weapon": true})).is_true()
	assert_str(w._weapon_action).is_equal("pickup_heavy")
	for i in WrestlerController.WEAPON_ACTION_TICKS["pickup_heavy"]:
		w._tick_weapon_action({})
	assert_bool(w.has_weapon()).is_true()
	assert_str(ladder.state_root).is_equal("Ladder_Closed")
	assert_bool(w.can_slide_weapon_into_ring()).is_true()
	assert_bool(w._weapon_input({"throw": true})).is_true()
	assert_str(w._weapon_action).is_equal("slide")
	for i in WrestlerController.WEAPON_ACTION_TICKS["slide"]:
		w._tick_weapon_action({})
	assert_int(ladder.mode).is_equal(WeaponActor.Mode.SLIDING)
	for i in 60:
		await get_tree().physics_frame
	assert_int(ladder.mode).is_equal(WeaponActor.Mode.FLOOR)
	assert_float(ladder.global_position.x).is_less(WrestlerController.RING_KEEP_IN)


func test_ladder_climb_states_have_authored_animation_clips() -> void:
	var w := _wrestler()
	assert_bool(w.anim_player.has_animation("strikes/ladder_climb")).is_true()
	assert_bool(w.anim_player.has_animation("strikes/ladder_fall")).is_true()


func test_top_of_ladder_aerial_has_paired_move_pose_and_landing_sell() -> void:
	var move := load("res://resources/moves/ladder_aerial.tres") as MoveDef
	assert_object(move).is_not_null()
	assert_str(String(move.animation_pair_id)).is_equal("ladder_aerial")
	assert_bool(move.leaves_defender_down).is_true()
	assert_bool(PairedRecipes.RECIPES.has("ladder_aerial")).is_true()
	assert_bool(PairedRecipes.RECIPES["ladder_aerial"]["authored"].has("attacker")).is_true()
	assert_bool(PairedRecipes.RECIPES["ladder_aerial"]["authored"].has("defender")).is_true()
	var trajectory: Dictionary = PairedRecipes.TRAJECTORIES["ladder_aerial"]
	assert_float(trajectory["attacker"]["pos"][0][2]).is_greater(1.2)
	assert_float(trajectory["attacker"]["pos"][-1][2]).is_equal_approx(0.0, 0.001)
	assert_str(String(ImpactSell.move_profile(move))).is_equal("ladder_aerial")
