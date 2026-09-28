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
