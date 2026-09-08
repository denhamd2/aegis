extends GdUnitTestSuite
## The entrance set's lighting invariants -- the ones three comments in
## `core/lighting/arena_lighting.gd` have been citing this file for while it
## did not exist.
##
## That is the reason it is here. `ACCENT_RANGE`, `STAGE_COLOR` and
## `COMPAT_STAGE_GAIN` each carry a comment saying "test_stage_lighting.gd
## asserts that", and none of it was asserted anywhere: before this file, no
## test in the suite referenced Light3D, spot_range or light_energy at all. A
## comment that claims a guard exists is worse than no comment, because it
## stops the next reader looking.
##
## All of it is renderer-free -- positions, ranges, angles and colours read off
## the rig the script builds -- so it holds under the headless CI run that
## `gauntlet/anchor/ARCHITECTURE.md` forbids judging visual slices on.

## `RingBuilder.MAT_HALF`. Duplicated rather than imported because it is a
## frozen dimension: if it ever moves, this test should fail and be read, not
## silently follow.
const MAT_HALF := 3.0


func _rig() -> ArenaLighting:
	var rig: ArenaLighting = auto_free(ArenaLighting.new())
	add_child(rig)
	return rig


func _mat_corners() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx: float in [1.0, -1.0]:
		for sz: float in [1.0, -1.0]:
			out.append(Vector3(sx * MAT_HALF, 0.0, sz * MAT_HALF))
	return out


## Fixtures at or behind the stage line, which is exactly the set
## `_compensate_for_renderer()` exempts from `COMPAT_LIGHT_GAIN`.
func _stage_side(rig: ArenaLighting) -> Array[SpotLight3D]:
	var out: Array[SpotLight3D] = []
	for child in rig.get_children():
		if child is SpotLight3D and child.position.z <= ArenaLighting.STAGE_LINE_Z:
			out.append(child)
	return out


## THE GUARANTEE `COMPAT_STAGE_GAIN` RESTS ON.
##
## That constant is 1.0: the entrance set is deliberately NOT scaled down on
## the compatibility renderer, because `COMPAT_LIGHT_GAIN` exists to hold the
## mat on VISUAL_BAR.md's 0.43-0.49 anchor and these fixtures cannot move the
## mat. If one of them ever can, that exemption starts spending the anchor's
## budget, and this is the test that says so first.
##
## The guarantee is a disjunction, not the single range rule an earlier comment
## claimed: a fixture is safe if the mat is beyond its range OR outside its
## cone. Eight of the ten are range-safe; the two stage-wash fixtures out-range
## the mat by eleven metres and are safe only because they are aimed away.
func test_no_entrance_fixture_can_reach_the_mat() -> void:
	var rig := _rig()
	var fixtures := _stage_side(rig)
	assert_int(fixtures.size()).override_failure_message(
			"no fixtures found behind the stage line -- either the rig stopped "
			+ "building the entrance set or STAGE_LINE_Z moved past it, and "
			+ "either way COMPAT_STAGE_GAIN is now exempting nothing"
	).is_greater(0)
	for light in fixtures:
		var axis := -light.global_transform.basis.z.normalized()
		var nearest := INF
		var off_axis := INF
		for corner in _mat_corners():
			var to_corner := corner - light.position
			nearest = minf(nearest, to_corner.length())
			off_axis = minf(off_axis,
					rad_to_deg(acos(clampf(to_corner.normalized().dot(axis), -1.0, 1.0))))
		var by_range := light.spot_range < nearest
		var by_cone := off_axis > light.spot_angle
		assert_bool(by_range or by_cone).override_failure_message(
				("%s reaches the mat: range %.1fm against a nearest corner at "
				+ "%.2fm, and that corner sits %.1f degrees off a %.1f degree "
				+ "cone. A fixture behind the stage line is exempt from "
				+ "COMPAT_LIGHT_GAIN, so this one now spends the mat's "
				+ "exposure budget on the compatibility renderer.") % [
					light.name, light.spot_range, nearest, off_axis,
					light.spot_angle]
		).is_true()


## The stage wash is the fragile one, and this pins WHY it is safe so the
## reason cannot quietly change. If someone re-aims it at the ring, the test
## above still passes on range for the accents and fails here.
func test_the_stage_wash_is_the_one_kept_off_the_mat_by_its_aim() -> void:
	var rig := _rig()
	var wash: Array[SpotLight3D] = []
	for light in _stage_side(rig):
		if String(light.name).begins_with("Stage"):
			wash.append(light)
	assert_int(wash.size()).is_equal(2)
	for light in wash:
		var nearest := INF
		for corner in _mat_corners():
			nearest = minf(nearest, (corner - light.position).length())
		assert_float(light.spot_range).override_failure_message(
				"%s is now range-safe (%.1fm against %.2fm). That is an "
				% [light.name, light.spot_range, nearest]
				+ "improvement, not a failure -- delete this test and let the "
				+ "range rule cover it."
		).is_greater(nearest)


## The violet push is a hue change that moves the level slightly, and this
## pins how slightly.
##
## `STAGE_COLOR`'s comment used to claim a luminance difference of 0.0007 --
## "hue only". Writing this test is what caught that: the real figure is
## 0.0056 on raw sRGB components, eight times the claim. The comment now
## carries the measured numbers.
##
## 0.01 is the band, not 0.0007: it is loose enough for a genuine recolour and
## tight enough that a brightness change wearing a recolour's clothes fails.
func test_the_stage_wash_recolour_only_moved_its_level_slightly() -> void:
	var previous := Color(0.72, 0.74, 1.0)
	var moved: float = absf(
			ArenaLighting.STAGE_COLOR.get_luminance() - previous.get_luminance())
	assert_float(moved).override_failure_message(
			("STAGE_COLOR now sits %.4f from the %.4f it replaced. Past 0.01 "
			+ "that is a brightness edit, not a recolour -- say so in the "
			+ "comment and re-check what it lights.") % [
				moved, previous.get_luminance()]
	).is_less(0.01)
	# And the hue really did move, so this is not passing by nothing changing.
	assert_float(absf(ArenaLighting.STAGE_COLOR.h - previous.h)).is_greater(0.005)


## The split `_compensate_for_renderer()` applies, asserted on the predicate
## rather than on a built rig.
func test_only_fixtures_behind_the_stage_line_escape_the_mat_gain() -> void:
	assert_float(ArenaLighting.compat_gain_for_z(ArenaLighting.STAGE_LINE_Z)) \
			.is_equal(ArenaLighting.COMPAT_STAGE_GAIN)
	assert_float(ArenaLighting.compat_gain_for_z(ArenaLighting.STAGE_LINE_Z - 5.0)) \
			.is_equal(ArenaLighting.COMPAT_STAGE_GAIN)
	assert_float(ArenaLighting.compat_gain_for_z(ArenaLighting.STAGE_LINE_Z + 0.1)) \
			.is_equal(ArenaLighting.COMPAT_LIGHT_GAIN)
	# The ring itself, which is the thing COMPAT_LIGHT_GAIN exists for.
	assert_float(ArenaLighting.compat_gain_for_z(0.0)) \
			.is_equal(ArenaLighting.COMPAT_LIGHT_GAIN)


## Every compatibility gain in the hall is a no-op on forward_plus, which is
## the renderer every gauntlet number is measured on. Headless reports
## forward_plus, so this run is that branch.
func test_the_compatibility_gains_are_inert_on_forward_plus() -> void:
	assert_str(RenderingServer.get_current_rendering_method()).is_equal("forward_plus")
	assert_float(ArenaBuilder._emissive_gain()).is_equal(1.0)
	assert_float(StageVideo._compat_gain()).is_equal(1.0)
