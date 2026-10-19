extends GdUnitTestSuite
## The ringside sign fans (SignFans): in chairs opposite the hard camera
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
		for z in range(-10, 11):
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
	assert_float(SignFans.OPENING_SIGN_HOLD).is_greater(5.0)


func test_dynamite_opening_raises_only_enda_sign_without_a_match_cutaway() -> void:
	var fans := SignFans.new()
	add_child(fans)
	var chairs: Array[Transform3D] = [Transform3D.IDENTITY]
	fans.seat(chairs, [0])
	var director := EntranceDirector.new()
	add_child(director)
	fans.follow(director)
	var camera_cutaway := [false]
	fans.raised.connect(func() -> void: camera_cutaway[0] = true)
	director.cue.emit(EntranceDirector.OPENING_SIGN_CUE)
	assert_object(fans.enda_easter_egg_fan()).is_not_null()
	assert_int(fans.enda_easter_egg_fan().stage).is_equal(SignFan.Stage.RISING)
	assert_bool(camera_cutaway[0]).is_false()


func test_both_signs_are_in_the_project() -> void:
	for spec: Array in SignFans.FANS:
		assert_object(load(spec[0])).is_not_null()
	for path: String in SignFan.MODELS:
		assert_object(load(path)).is_not_null()
	assert_int(SignFan.MODELS.size()).is_greater_equal(SignFans.FANS.size())


## Real people, not boxes (the owner, 19 Oct): each fan a textured avatar of
## thousands of triangles on a full skeleton, with his four clips.
func test_every_fan_model_is_a_real_person_with_his_four_clips() -> void:
	for path: String in SignFan.MODELS:
		var model: Node = auto_free((load(path) as PackedScene).instantiate())
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert_object(player).is_not_null()
		for clip: String in [SignFan.SEATED, SignFan.RISE, SignFan.HOLD, SignFan.LOWER]:
			assert_bool(player.has_animation(clip)).override_failure_message("no clip " + clip).is_true()
		var body := model.find_child("FanBody", true, false) as MeshInstance3D
		assert_object(body).is_not_null()
		assert_int(body.mesh.get_faces().size() / 3).is_greater(5000)
		var textured := 0
		for i in body.mesh.get_surface_count():
			var m := body.mesh.surface_get_material(i) as BaseMaterial3D
			if m and m.albedo_texture:
				textured += 1
		assert_int(textured).is_equal(body.mesh.get_surface_count())
		var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
		assert_int(skeleton.get_bone_count()).is_greater(50)
