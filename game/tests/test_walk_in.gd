extends GdUnitTestSuite
## The walk-in (GrappleRig.walk_in_ticks; gauntlet/refs/animation_gap.md
## Phase 2): the set-up takes as long as stepping there would, never less than
## the old fixed lead-in, never so long it reads as a pause.

func _at(x: float, z: float, yaw_deg := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3(x, 0.0, z))


func test_a_short_closing_is_no_slower_than_before() -> void:
	assert_int(GrappleRig.walk_in_ticks(_at(0, 0), _at(0, 0.05))).is_equal(GrappleRig.LEAD_IN_TICKS)


func test_the_time_follows_the_distance() -> void:
	# 0.65 m, the Spear's back-off, at 1.6 m/s: 25 ticks.
	var ticks := GrappleRig.walk_in_ticks(_at(0, 0), _at(0, 0.65))
	assert_int(ticks).is_between(24, 26)


func test_a_turn_on_the_spot_takes_time_too() -> void:
	# 120 degrees at 240 deg/s: half a second.
	assert_int(GrappleRig.walk_in_ticks(_at(0, 0), _at(0, 0, 120))).is_between(29, 31)


func test_a_long_carry_is_capped() -> void:
	assert_int(GrappleRig.walk_in_ticks(_at(0, 0), _at(0, 3.0))).is_equal(GrappleRig.LEAD_IN_MAX_TICKS)
