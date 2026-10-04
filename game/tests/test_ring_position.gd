extends GdUnitTestSuite
## Phase 4, position (gauntlet/refs/animation_gap.md): the corner and the
## ropes. A man knocked back into a corner is trapped against the buckle; a man
## pinned or held within reach of the ropes gets to them and the referee breaks
## it -- after two, before three, and never under a finisher.


func _body(at: Vector3, facing: Vector3) -> Node3D:
	var n: Node3D = auto_free(Node3D.new())
	add_child(n)
	n.global_position = at
	n.look_at(at + facing, Vector3.UP)
	return n


func test_a_blow_toward_a_corner_traps_him_in_it() -> void:
	var spot := WrestlerController.corner_behind(Vector3(2.2, 0, 2.1), Vector3(1.4, 0, 1.3))
	assert_bool(spot.is_finite()).is_true()
	assert_vector(spot).is_equal_approx(Vector3(2.6, 0, 2.6), Vector3.ONE * 1e-4)
	# Any corner, by the signs of where he stands.
	spot = WrestlerController.corner_behind(Vector3(-2.0, 0, 2.3), Vector3(-1.2, 0, 1.6))
	assert_vector(spot).is_equal_approx(Vector3(-2.6, 0, 2.6), Vector3.ONE * 1e-4)


func test_not_trapped_mid_ring_along_one_rope_or_driven_out_of_the_corner() -> void:
	# Mid-ring.
	assert_bool(WrestlerController.corner_behind(Vector3(0.5, 0, 0.3), Vector3(0, 0, 0)).is_finite()).is_false()
	# By one rope, not in a corner.
	assert_bool(WrestlerController.corner_behind(Vector3(2.4, 0, 0.2), Vector3(1.4, 0, 0.2)).is_finite()).is_false()
	# In the corner's reach but hit from the corner side: driven OUT of it.
	assert_bool(WrestlerController.corner_behind(Vector3(2.0, 0, 2.0), Vector3(2.7, 0, 2.7)).is_finite()).is_false()


func test_the_trap_holds_him_as_long_as_its_clips_run() -> void:
	# The clips are cut to the state lengths (strike_recipes.gd), so the pose
	# never freezes on a held last frame while he is still trapped.
	var recipes := WrestlerController.StrikeRecipes.RECIPES
	assert_float(recipes["corner_slump"]["seconds"] * 60.0).is_equal_approx(
			WrestlerController.CORNER_TRAP_TICKS, 0.5)
	assert_float(recipes["corner_hit"]["seconds"] * 60.0).is_equal_approx(
			WrestlerController.CORNER_HIT_TICKS, 0.5)
	assert_int(WrestlerController.CORNER_HITS_MAX).is_greater(0)


func test_lying_with_his_head_to_the_ropes_he_can_reach_them() -> void:
	# Head up his own -Z: lying toward +x, 2.1 m out, a hand over his head
	# gets to the rope on the +x side.
	var man := _body(Vector3(2.1, 0, 0.4), Vector3(1, 0, 0))
	assert_vector(WrestlerController.rope_within_reach(man)).is_equal(Vector3(1, 0, 0))
	# Feet to the -z ropes.
	man = _body(Vector3(0.3, 0, -2.2), Vector3(0, 0, 1))
	assert_vector(WrestlerController.rope_within_reach(man)).is_equal(Vector3(0, 0, -1))


func test_in_the_middle_of_the_ring_he_cannot() -> void:
	for facing: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, -1)]:
		var man := _body(Vector3(0.5, 0, -0.4), facing)
		assert_vector(WrestlerController.rope_within_reach(man)).is_equal(Vector3.ZERO)


## The referee breaks the count the moment a man touches the rope: before the
## first slap, not after a two-count.
func test_the_rope_breaks_the_count_before_the_first_slap() -> void:
	var got := MatchReferee.ROPE_REACH_START_TICK + MatchReferee.ROPE_REACH_TICKS
	assert_int(got).is_less(MatchReferee.COUNT_TICKS[0])


# --- pin legality ------------------------------------------------------------
#
# A cover counts only with both men inside the ropes, the pinned man's head
# and shoulders not under the bottom rope, and nobody on the apron.

func _lying(at: Vector3, head_toward: Vector3) -> Transform3D:
	# His head is up his own -Z.
	return Transform3D(Basis.looking_at(head_toward, Vector3.UP), at)


func test_a_cover_in_the_middle_is_legal() -> void:
	var man := _lying(Vector3(0.2, 0.0, 0.1), Vector3(0, 0, 1))
	assert_bool(MatchReferee.cover_is_legal(Vector3(0.6, 0.0, 0.2), man)).is_true()


func test_a_man_with_his_head_under_the_bottom_rope_is_not_covered() -> void:
	# Hips well inside, head out past the rope line.
	var man := _lying(Vector3(2.5, 0.0, 0.0), Vector3(1, 0, 0))
	assert_bool(MatchReferee.cover_is_legal(Vector3(2.0, 0.0, 0.5), man)).is_false()


func test_a_man_lying_with_his_feet_to_the_ropes_is_covered() -> void:
	# The same place, the other way round: head in, only his feet near the rope.
	var man := _lying(Vector3(2.5, 0.0, 0.0), Vector3(-1, 0, 0))
	assert_bool(MatchReferee.cover_is_legal(Vector3(2.0, 0.0, 0.5), man)).is_true()


func test_a_man_part_way_out_of_the_ring_is_not_covered() -> void:
	var man := _lying(Vector3(3.2, 0.0, 0.0), Vector3(-1, 0, 0))
	assert_bool(MatchReferee.cover_is_legal(Vector3(2.0, 0.0, 0.0), man)).is_false()


func test_nobody_covers_from_the_apron() -> void:
	var man := _lying(Vector3(0.3, 0.0, 0.0), Vector3(0, 0, 1))
	assert_bool(MatchReferee.cover_is_legal(Vector3(3.4, 0.0, 0.0), man)).is_false()


func test_a_man_on_the_floor_outside_is_not_covered() -> void:
	var man := _lying(Vector3(0.3, -1.0, 0.0), Vector3(0, 0, 1))
	assert_bool(MatchReferee.cover_is_legal(Vector3(0.6, 0.0, 0.0), man)).is_false()
