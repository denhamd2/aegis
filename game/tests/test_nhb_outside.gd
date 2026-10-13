extends GdUnitTestSuite
## No Holds Barred takes the fight outside (gauntlet/refs/weapons_nhb.md):
## through the ropes to the floor and back, held on the floor inside the
## barricade and out from under the apron, pins counted anywhere, no rope
## breaks -- and none of it in the singles match.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func _wrestler(nhb: bool) -> WrestlerController:
	var wrestler: WrestlerController = WRESTLER_SCENE.instantiate()
	if nhb:
		MatchRules.set_mode(wrestler, MatchRules.Mode.NO_HOLDS_BARRED)
	auto_free(wrestler)
	add_child(wrestler)
	return wrestler


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_only_no_holds_barred_lets_him_through_the_ropes() -> void:
	var singles := _wrestler(false)
	singles.global_position = Vector3(2.55, 0.0, 0.5)
	assert_bool(singles.begin_rope_cross()).is_false()
	var nhb := _wrestler(true)
	nhb.global_position = Vector3(2.55, 0.0, 0.5)
	assert_bool(nhb.can_cross_ropes()).is_true()


func test_pushing_into_the_ropes_picks_that_side() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(2.5, 0.0, 0.3)
	assert_vector(w.rope_side_pushed(Vector2(1.0, 0.0))).is_equal(Vector3(1, 0, 0))
	# Pushing along the ropes, or from the middle of the ring, is not a cross.
	assert_vector(w.rope_side_pushed(Vector2(0.0, 1.0))).is_equal(Vector3.ZERO)
	w.global_position = Vector3(1.0, 0.0, 0.3)
	assert_vector(w.rope_side_pushed(Vector2(1.0, 0.0))).is_equal(Vector3.ZERO)
	# Nor in a corner, where the turnbuckle is.
	w.global_position = Vector3(2.5, 0.0, 2.4)
	assert_vector(w.rope_side_pushed(Vector2(1.0, 0.0))).is_equal(Vector3.ZERO)


func test_he_rolls_out_to_the_floor_and_back_in() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(0.4, 0.0, -2.5)
	await _ticks(2)
	assert_bool(w.begin_rope_cross()).is_true()
	assert_bool(w.is_crossing_ropes()).is_true()
	await _ticks(DiveSpot.ROLL_OUT_TICKS + 5)
	assert_bool(w.is_crossing_ropes()).is_false()
	assert_bool(w.outside_ring).is_true()
	assert_float(w.global_position.y).is_equal_approx(WrestlerController.FLOOR_LEVEL, 0.05)
	assert_float(-w.global_position.z).is_greater_equal(WrestlerController.DECK_KEEP_OUT - 0.01)
	assert_float(w.global_position.x).is_equal_approx(0.4, 0.05)

	assert_bool(w.begin_rope_cross()).is_true()
	await _ticks(DiveSpot.ROLL_IN_TICKS + 5)
	assert_bool(w.outside_ring).is_false()
	assert_float(w.global_position.y).is_equal_approx(0.0, 0.05)
	assert_float(absf(w.global_position.z)).is_less_equal(WrestlerController.RING_KEEP_IN)


func test_outside_he_stays_on_the_floor_inside_the_barricade() -> void:
	var w := _wrestler(true)
	w.outside_ring = true
	for put: Vector3 in [Vector3(9.0, -3.0, 0.0), Vector3(0.0, -1.0, -9.0),
			Vector3(7.0, -1.0, 7.0), Vector3(2.0, -1.0, 0.5)]:
		w.global_position = put
		w.keep_inside_the_ring()
		var p := w.global_position
		assert_float(p.y).is_greater_equal(WrestlerController.FLOOR_LEVEL - 0.001)
		assert_float(absf(p.x)).is_less_equal(WrestlerController.BARRICADE_KEEP_IN + 0.001)
		assert_float(absf(p.z)).is_less_equal(WrestlerController.BARRICADE_KEEP_IN + 0.001)
		assert_float(absf(p.x) + absf(p.z)) \
			.is_less_equal(WrestlerController.BARRICADE_CORNER_KEEP_IN + 0.001)
		# Never under the apron.
		assert_bool(absf(p.x) >= WrestlerController.DECK_KEEP_OUT - 0.001 \
				or absf(p.z) >= WrestlerController.DECK_KEEP_OUT - 0.001).is_true()


func test_nobody_reaches_across_the_ropes() -> void:
	var a := _wrestler(true)
	var b := _wrestler(true)
	a.global_position = Vector3(2.5, 0.0, 0.0)
	b.global_position = Vector3(3.7, -1.1, 0.0)
	b.outside_ring = true
	a.opponent = b
	assert_bool(a._in_range(5.0)).is_false()
	a.outside_ring = true
	assert_bool(a._in_range(5.0)).is_true()


func test_a_move_on_the_floor_plays_at_floor_height_off_the_deck() -> void:
	var rig := GrappleRig.new()
	auto_free(rig)
	var a := _wrestler(true)
	var b := _wrestler(true)
	a.outside_ring = true
	b.outside_ring = true
	a.global_position = Vector3(3.7, -1.1, 0.0)
	b.global_position = Vector3(3.7, -1.1, 0.8)
	var pair := rig._compute_pair_transform(a, b)
	assert_float(pair.origin.y).is_equal_approx(WrestlerController.FLOOR_LEVEL, 0.001)
	assert_float(pair.origin.x).is_greater_equal(WrestlerController.DECK_KEEP_OUT)
	assert_float(pair.origin.x).is_less_equal(ArenaBuilder.BARRICADE_RADIUS - GrappleRig.OUTSIDE_MARGIN)


func test_no_holds_barred_has_no_rope_breaks() -> void:
	var referee: Node = (load("res://core/match/match_referee.gd") as GDScript).new()
	auto_free(referee)
	var a := _wrestler(true)
	var b := _wrestler(true)
	MatchRules.set_mode(referee, MatchRules.Mode.NO_HOLDS_BARRED)
	b.global_position = Vector3(2.4, 0.0, 0.0)
	assert_vector(referee._reachable_ropes(a, b)).is_equal(Vector3.ZERO)
