extends GdUnitTestSuite
## Inertializer's fade (Bollo's quintic): it starts exactly at the carried
## difference, moving as the bone was, and arrives at nothing -- with no
## overshoot past the new pose on the way.


func test_starts_at_the_difference_and_ends_at_nothing() -> void:
	var c := Inertializer._bollo(0.5, -0.02, 9.0)
	assert_float(Inertializer._eval(c, 0.0)).is_equal_approx(0.5, 1e-5)
	assert_float(Inertializer._eval(c, 9.0)).is_equal(0.0)
	assert_float(Inertializer._eval(c, 20.0)).is_equal(0.0)


func test_carries_the_speed_the_bone_had() -> void:
	# Heading toward the new pose at 0.03 per tick: the first tick moves it
	# about that far, rather than starting from rest.
	var c := Inertializer._bollo(0.5, -0.03, 9.0)
	var first := 0.5 - Inertializer._eval(c, 1.0)
	assert_float(first).is_greater(0.025)


func test_a_bone_moving_away_starts_from_rest_and_never_overshoots() -> void:
	var c := Inertializer._bollo(0.4, 0.05, 9.0)
	assert_float(c[1]).is_equal(0.0)
	var t := 0.0
	while t <= 9.0:
		var x := Inertializer._eval(c, t)
		assert_float(x).is_between(-1e-4, 0.4 + 1e-5)
		t += 0.25


func test_a_fast_arrival_shortens_the_fade_instead_of_overshooting() -> void:
	# At 0.2 per tick a 0.3 difference is covered in well under 9 ticks.
	var c := Inertializer._bollo(0.3, -0.2, 9.0)
	assert_float(c[6]).is_less(9.0)
	var t := 0.0
	while t <= c[6]:
		assert_float(Inertializer._eval(c, t)).is_greater_equal(-1e-4)
		t += 0.25


func test_nothing_to_carry_is_a_no_op() -> void:
	var c := Inertializer._bollo(0.0, -0.1, 9.0)
	assert_float(Inertializer._eval(c, 0.0)).is_equal(0.0)


## In the match the mixer runs on the 60 Hz tick; the pose drawn between two
## ticks is between the two tick poses, not the last one held (the "stop
## motion" a 120 Hz display showed: 111 of 240 frames held,
## tools/probe/motion_cadence -- --match).
func test_the_pose_is_drawn_between_ticks() -> void:
	var sk: Skeleton3D = auto_free(Skeleton3D.new())
	sk.add_bone("root")
	sk.add_bone("arm")
	sk.set_bone_parent(1, 0)
	var ine := Inertializer.new()
	sk.add_child(ine)
	add_child(sk)
	ine._ensure(sk)
	ine._tick_prior_rot = [Quaternion.IDENTITY, Quaternion.IDENTITY]
	ine._tick_prior_pos = [Vector3.ZERO, Vector3.ZERO]
	ine._drawn_rot[1] = Quaternion(Vector3.UP, 0.4)
	ine._drawn_pos[0] = Vector3(0, 0, 0.2)
	ine.draw_between(sk, 0.5)
	assert_float(sk.get_bone_pose_rotation(1).get_angle()).is_equal_approx(0.2, 1e-4)
	assert_vector(sk.get_bone_pose_position(0)).is_equal_approx(Vector3(0, 0, 0.1), Vector3.ONE * 1e-5)
	ine.draw_between(sk, 1.0)
	assert_float(sk.get_bone_pose_rotation(1).get_angle()).is_equal_approx(0.4, 1e-4)


## A placed body is drawn as placed: nothing in between.
func test_a_snap_draws_the_next_tick_as_it_is() -> void:
	var ine: Inertializer = auto_free(Inertializer.new())
	assert_bool(ine._cut).is_true()
	ine._cut = false
	ine.snap()
	assert_bool(ine._cut).is_true()
