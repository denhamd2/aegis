extends GdUnitTestSuite
## The entrance lane is enclosed by crowd-control panels from the stage lip to
## the gap in the ringside barricade.


func test_barricade_runs_flank_the_full_ramp() -> void:
	var side_counts := {-1: 0, 1: 0}
	for panel: Array in ArenaBuilder.barricade_panels():
		var at: Vector3 = panel[0]
		var out: Vector3 = panel[2]
		if ArenaBuilder.is_ramp_barricade_panel(panel):
			assert_str(ArenaLighting.barricade_face(panel)).is_equal("black")
		if not is_equal_approx(absf(at.x), ArenaBuilder.RAMP_BARRICADE_OFFSET):
			continue
		if at.z < ArenaBuilder.STAGE_FRONT or at.z > -ArenaBuilder.BARRICADE_RADIUS:
			continue
		var side := int(signf(at.x))
		side_counts[side] += 1
		assert_float(absf(at.x)).is_greater(ArenaBuilder.RAMP_HALF_WIDTH)
		assert_float(out.x * at.x).is_greater(0.0)
	assert_int(side_counts[-1]).is_greater(0)
	assert_int(side_counts[-1]).is_equal(side_counts[1])
