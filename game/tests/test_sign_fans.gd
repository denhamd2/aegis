extends GdUnitTestSuite
## The two ringside sign fans (SignFans): in chairs opposite the hard camera
## and the stare-down shot, their seats kept out of the crowd, and their signs
## up only now and then -- the face-off, then at most MATCH_RAISES_MAX times
## in the match, never close together.


func test_they_sit_across_the_ring_from_the_cameras() -> void:
	for spec: Array in SignFans.FANS:
		var spot: Vector3 = spec[1]
		# The hard camera is at -X looking +X; so is the face-off shot.
		assert_float(spot.x).is_greater(0.0)
		# Ringside rows two and three: the barricade square at 6 m plus
		# FLOOR_SEAT_START and one or two pitches.
		var first := ArenaBuilder.BARRICADE_RADIUS + ArenaBuilder.FLOOR_SEAT_START
		assert_float(spot.x).is_between(first + ArenaBuilder.FLOOR_ROW_PITCH * 0.5,
				first + ArenaBuilder.FLOOR_ROW_PITCH * 2.5)
		# Off the centre line, so two men chest to chest do not hide them.
		assert_float(absf(spot.z)).is_greater(2.0)


func test_each_fan_gets_his_own_nearest_chair() -> void:
	var chairs: Array[Transform3D] = []
	for x in [7.2, 8.05, 8.9]:
		for z in range(-8, 9):
			chairs.append(Transform3D(Basis.IDENTITY, Vector3(x, -1.1, z * 0.62)))
	var picked := SignFans.pick_seats(chairs)
	assert_int(picked.size()).is_equal(SignFans.FANS.size())
	assert_int(picked[0]).is_not_equal(picked[1])
	for n in picked.size():
		var spot: Vector3 = SignFans.FANS[n][1]
		assert_float(Vector2(chairs[picked[n]].origin.x - spot.x,
				chairs[picked[n]].origin.z - spot.z).length()).is_less(0.5)


func test_signs_go_up_only_now_and_then() -> void:
	assert_int(SignFans.MATCH_RAISES_MAX).is_between(1, 2)
	assert_float(SignFans.MATCH_GAP).is_greater_equal(20.0)
	assert_float(SignFans.MATCH_HOLD).is_less(10.0)


func test_both_signs_are_in_the_project() -> void:
	for spec: Array in SignFans.FANS:
		assert_object(load(spec[0])).is_not_null()
	assert_object(load(SignFan.MODEL)).is_not_null()


func test_the_fan_model_has_his_four_clips() -> void:
	var model: Node = auto_free((load(SignFan.MODEL) as PackedScene).instantiate())
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_object(player).is_not_null()
	for clip: String in [SignFan.SEATED, SignFan.RISE, SignFan.HOLD, SignFan.LOWER]:
		assert_bool(player.has_animation(clip)).override_failure_message("no clip " + clip).is_true()
