extends GdUnitTestSuite
## The beam fixtures over the bowl, and the crowd's wash colour.
##
## Both were added to match the four AEW stills in gauntlet/refs/lighting/
## (see lighting.md), and both are only safe to have because they cannot touch
## VISUAL_BAR.md's exposure anchor: the mat at 0.43-0.49. These are the
## renderer-free halves of that claim; the rendered half is
## measure_silhouette.py, which moved 0.453 -> 0.450 when they went in.

## `RingBuilder.MAT_HALF`, duplicated for the reason test_stage_lighting.gd
## gives: a frozen dimension should fail loudly if it moves.
const MAT_HALF := 3.0


func _beams() -> Array[SpotLight3D]:
	var rig: ArenaLighting = auto_free(ArenaLighting.new())
	add_child(rig)
	var out: Array[SpotLight3D] = []
	for child in rig.get_children():
		if child is SpotLight3D and String(child.name).begins_with("Beam"):
			out.append(child)
	return out


## Headless reports forward_plus, so the rig builds them here.
func test_the_rig_builds_every_beam() -> void:
	assert_int(_beams().size()).is_equal(ArenaLighting.BEAM_FIXTURES)


## Every beam points away from the canvas. The beams out-range the mat, so the
## cone is the whole guarantee, and a 6-degree cone makes it a strong one:
## the nearest beam sits 58 degrees off the mat, and the margin asserted is
## five times the cone.
func test_no_beam_can_reach_the_mat() -> void:
	for light in _beams():
		var axis := -light.global_transform.basis.z.normalized()
		var off_axis := INF
		for sx: float in [1.0, -1.0]:
			for sz: float in [1.0, -1.0]:
				var to_corner := Vector3(sx * MAT_HALF, 0.0, sz * MAT_HALF) \
						- light.position
				off_axis = minf(off_axis, rad_to_deg(acos(clampf(
						to_corner.normalized().dot(axis), -1.0, 1.0))))
		assert_float(off_axis).override_failure_message(
				"%s sits %.1f degrees off the nearest mat corner against a "
				% [light.name, off_axis]
				+ "%.1f degree cone -- it has been re-aimed toward the ring."
				% light.spot_angle
		).is_greater(light.spot_angle * 5.0)


## capture_harness.gd: a green-dominant element in the HUD corner probes blinds
## the evidence gate.
func test_no_beam_colour_is_green_dominant() -> void:
	for color: Color in ArenaLighting.BEAM_COLORS:
		assert_bool(color.g > color.r and color.g > color.b).is_false()


## The wash changes the crowd's colour, not its level: VISUAL_BAR.md's 0.014
## crowd is set by `house_light`, and CROWD_WASH is normalised to leave it.
func test_the_crowd_wash_holds_the_crowd_level() -> void:
	var w := ArenaBuilder.CROWD_WASH
	var luminance := 0.2126 * w.x + 0.7152 * w.y + 0.0722 * w.z
	assert_float(luminance).is_between(0.95, 1.05)
	# And it is actually a colour -- blue-led, as the references are.
	assert_float(w.z).is_greater(w.x * 2.0)
