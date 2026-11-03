extends GdUnitTestSuite
## The owner, 3 Nov:
## - "the ladder climbing animation doesn't work" -- he glided up it in one
##   pose, the clip played once and froze;
## - the sells: a lariat "knocked down with force to the mat", weapons sold
##   "appropriate for the force of each weapon", through a table "writhe in
##   agony whilst on the floor".

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func _pair() -> Array[WrestlerController]:
	var out: Array[WrestlerController] = []
	for i in 2:
		var w: WrestlerController = WRESTLER_SCENE.instantiate()
		w.player_index = i
		auto_free(w)
		add_child(w)
		out.append(w)
	out[0].opponent = out[1]
	out[1].opponent = out[0]
	for w in out:
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
	return out


# --- The climb ----------------------------------------------------------------

func test_each_hand_and_boot_holds_its_rung_then_goes_up_two() -> void:
	var rungs := {}
	var moves := 0
	var last := WrestlerController.ladder_limb_rung(1.0, 0.0).x
	for i in 400:
		var want := 1.0 + float(i) * 0.02
		var at := WrestlerController.ladder_limb_rung(want, 0.0)
		if at.y == 0.0:
			# holding: on a rung, not between two
			assert_float(at.x).is_equal_approx(roundf(at.x), 0.0001)
			rungs[int(roundf(at.x))] = true
		# never down the ladder on the way up, never far from where he is
		assert_float(at.x).is_greater_equal(last - 0.0001)
		assert_float(absf(at.x - want)).is_less_equal(WrestlerController.LADDER_STEP + 0.01)
		if at.x > last + 0.0001 and is_equal_approx(last, roundf(last)):
			moves += 1
		last = at.x
	# rung over rung, two at a time: the even rungs for this pair
	for r: int in rungs:
		assert_int(r % 2).is_equal(0)
	assert_int(moves).is_greater_equal(3)


func test_the_two_pairs_take_turns() -> void:
	# Right hand with the left boot, then the left hand with the right boot:
	# never both hands off their rungs at once.
	for i in 400:
		var want := 1.0 + float(i) * 0.02
		var right := WrestlerController.ladder_limb_rung(want, 0.0)
		var left := WrestlerController.ladder_limb_rung(want, 1.0)
		assert_bool(right.y > 0.0 and left.y > 0.0).override_failure_message(
				"both hands reaching at rung %.2f" % want).is_false()


func after_test() -> void:
	var stock := get_node_or_null("WeaponStock")
	if stock:
		stock.free()


func test_he_goes_up_the_ladder_off_the_canvas() -> void:
	# Measured from the arena floor 1.1 m under the canvas, with gravity
	# zeroing the climb's velocity, he never left the mat.
	var pair := _pair()
	var roman := pair[0]
	MatchRules.set_mode(roman, MatchRules.Mode.NO_HOLDS_BARRED)
	var ladder := WeaponStock.of(roman).pull(WeaponCatalog.by_id(&"ladder"))
	ladder.set_up_at(Vector3.ZERO, 0.0, "Ladder_Open")
	roman.global_position = Vector3(0.0, 0.0, -WrestlerController.LADDER_FRONT_OFFSET)
	await get_tree().physics_frame
	var start_y := roman.global_position.y
	assert_bool(roman.begin_ladder_climb(ladder)).is_true()
	assert_float(roman.global_position.y).is_equal_approx(start_y, 0.01)
	for i in 120:
		roman._tick_ladder_climb({"move": Vector2(0.0, -1.0)})
		await get_tree().physics_frame
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.LADDER_CLIMB)
	var top := ladder.global_marker("top").origin.y
	assert_float(roman.global_position.y).override_failure_message(
			"still at %.2f after two seconds up a ladder topped at %.2f" % [
			roman.global_position.y, top]).is_greater(start_y + 1.0)
	assert_float(roman.global_position.y).is_less(top)


func test_off_a_tall_ladder_the_dive_still_lands_on_the_mat() -> void:
	assert_float(GrappleRig.ladder_dive_lift(0.0)).is_equal(1.0)
	assert_float(GrappleRig.ladder_dive_lift(GrappleRig.LADDER_DIVE_FALL_FROM)).is_equal(1.0)
	assert_float(GrappleRig.ladder_dive_lift(GrappleRig.LADDER_DIVE_LAND_AT)).is_equal(0.0)
	assert_float(GrappleRig.ladder_dive_lift(1.4)).is_equal(0.0)


func test_the_climb_clip_loops() -> void:
	assert_bool(bool(StrikeRecipes.RECIPES["ladder_climb"].get("loop", false))).is_true()


# --- The sells ----------------------------------------------------------------

func test_a_lariat_puts_him_down_hard() -> void:
	var move: MoveDef = load("res://resources/moves/running_attack_clothesline.tres")
	assert_bool(move.leaves_defender_down).is_true()
	var pair := _pair()
	var cody := pair[1]
	pair[0].global_position = Vector3(0.0, 0.0, 0.0)
	cody.global_position = Vector3(0.0, 0.0, 1.0)
	cody._pending_hits.append(move)
	cody._resolve_pending_hits()
	assert_bool(cody._bumping).is_true()
	assert_int(cody.fsm.current_state).is_equal(WrestlerFSM.State.HIT_REACT)
	var node := (cody.anim_tree.tree_root as AnimationNodeStateMachine).get_node("HIT_REACT") \
			as AnimationNodeAnimation
	var clip := String(node.animation)
	assert_bool(clip == WrestlerController.BUMP_LARIAT_CLIP).override_failure_message(clip).is_true()
	# carried back with it
	assert_float(cody.velocity.z).is_greater(0.0)


func test_the_heaviest_weapons_wipe_him_out_and_the_sharp_ones_leave_him_writhing() -> void:
	assert_int(WeaponCatalog.impact_of(WeaponCatalog.by_id(&"sledgehammer"))) \
			.is_equal(WeaponCatalog.Impact.WIPEOUT)
	for id: StringName in [&"barbed_wire_chair", &"barbed_wire_bat", &"board_with_nails",
			&"light_tubes"]:
		assert_bool(WeaponCatalog.cuts(WeaponCatalog.by_id(id))) \
				.override_failure_message(String(id)).is_true()
	for id: StringName in [&"steel_chair", &"kendo_stick", &"sledgehammer"]:
		assert_bool(WeaponCatalog.cuts(WeaponCatalog.by_id(id))) \
				.override_failure_message(String(id)).is_false()


func test_a_writhe_owed_is_dropped_once_he_is_up() -> void:
	var pair := _pair()
	var cody := pair[1]
	cody._writhe_in = WrestlerController.WRITHE_AFTER
	cody._tick_sell()
	assert_int(cody._writhe_in).is_equal(0)


func test_down_he_lies_still_then_writhes() -> void:
	var pair := _pair()
	var cody := pair[1]
	cody._writhe_in = 2
	cody._tick_writhe()
	assert_int(cody._writhe_in).is_equal(1)
	cody._tick_writhe()
	assert_int(cody._writhe_in).is_equal(0)
	assert_bool(StrikeRecipes.RECIPES.has("down_writhe")).is_true()
	assert_bool(bool(StrikeRecipes.RECIPES["down_writhe"].get("loop", false))).is_true()
