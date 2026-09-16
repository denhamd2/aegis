extends GdUnitTestSuite
## The truss beams' invariants -- the cyan shafts `gauntlet/refs/lighting/`
## is carried by, added to `core/lighting/arena_lighting.gd`.
##
## Renderer-free throughout: positions, aims, ranges, angles and colours read
## off the rig the script builds, so it holds under the headless CI run
## `gauntlet/anchor/ARCHITECTURE.md` forbids judging visual slices on.
##
## What it CANNOT cover, said plainly so nobody reads more into a green run
## than it earns: a headless run reports `forward_plus`, so
## `_build_truss_beams()`'s `_supports_volumetric_fog()` guard always takes the
## build branch here. The gl_compatibility path -- where the beams are
## deliberately absent -- is covered by rendered frames and by nothing else.
## `test_the_beam_rig_is_built_on_this_renderer` asserts the premise so that a
## later guard change cannot leave this whole file quietly testing an empty
## array.

## `RingBuilder.MAT_HALF`. Duplicated rather than imported because it is a
## frozen dimension: if it ever moves, this test should fail and be read, not
## silently follow.
const MAT_HALF := 3.0
## A wrestler's working height. The mat's corners are not the whole of what a
## beam must miss -- the cone passes overhead, so the thing at risk is a
## standing figure, not the canvas.
const FIGURE_HEIGHT := 2.0


func _rig() -> ArenaLighting:
	var rig: ArenaLighting = auto_free(ArenaLighting.new())
	add_child(rig)
	return rig


func _beams(rig: ArenaLighting) -> Array[SpotLight3D]:
	var out: Array[SpotLight3D] = []
	for child in rig.get_children():
		if child is SpotLight3D and String(child.name).begins_with("Beam"):
			out.append(child)
	return out


## The eight corners of the box a match is fought in, not the four of the mat.
func _ring_prism() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx: float in [1.0, -1.0]:
		for sz: float in [1.0, -1.0]:
			out.append(Vector3(sx * MAT_HALF, 0.0, sz * MAT_HALF))
			out.append(Vector3(sx * MAT_HALF, FIGURE_HEIGHT, sz * MAT_HALF))
	return out


## The premise every other test here rests on.
func test_the_beam_rig_is_built_on_this_renderer() -> void:
	assert_str(RenderingServer.get_current_rendering_method()) \
			.override_failure_message(
					"the beams are forward_plus-only by design, so this suite "
					+ "means nothing on any other renderer -- see the header"
			).is_equal("forward_plus")
	assert_int(_beams(_rig()).size()).override_failure_message(
			"expected 10 beams: BEAM_PICKS (12) bearings walked on the plan "
			+ "loop, less the two whose targets fall in the entrance-set gap "
			+ "where ArenaBuilder._in_stage_gap() says there is no seating"
	).is_equal(10)


## A beam hangs from modelled steel or it hangs from nothing.
func test_every_beam_hangs_on_a_truss_chord() -> void:
	for light in _beams(_rig()):
		var on_chord := maxf(absf(light.position.x), absf(light.position.z))
		assert_float(on_chord).override_failure_message(
				("%s sits at (%.2f, %.2f) in plan, which is not on the truss's "
				+ "outer chord square at %.1f. tools/blender/entrance_set.py "
				+ "build_truss() lays the lattice on x and z in "
				+ "{-7.5, -2.5, 2.5, 7.5}; a fixture off those lines is hung "
				+ "from air.") % [light.name, light.position.x,
					light.position.z, ArenaLighting.BEAM_HANG_XZ]
		).is_equal_approx(ArenaLighting.BEAM_HANG_XZ, 0.001)
		var along := minf(absf(light.position.x), absf(light.position.z))
		assert_float(along).override_failure_message(
				"%s is %.2f along its chord, past the lattice's %.1f end"
				% [light.name, along, ArenaLighting.TRUSS_REACH]
		).is_less_equal(ArenaLighting.TRUSS_REACH)
		assert_float(light.position.y).is_equal_approx(ArenaLighting.HANG_Y, 0.001)


## THE GUARANTEE THAT LETS THESE FIXTURES OUT-RANGE THE MAT.
##
## Every other long-range fixture in the rig is kept off the canvas by range.
## A beam cannot be: it hangs eight metres from the mat and throws forty.
## What keeps it off is that it is aimed outward, and this is the assertion
## that says so -- against the ring PRISM rather than the mat's corners,
## because the cone passes overhead and a standing wrestler is what it would
## catch first.
func test_no_beam_cone_contains_the_ring() -> void:
	for light in _beams(_rig()):
		var axis := -light.global_transform.basis.z.normalized()
		var off_axis := INF
		for point in _ring_prism():
			var to_point := point - light.position
			off_axis = minf(off_axis, rad_to_deg(
					acos(clampf(to_point.normalized().dot(axis), -1.0, 1.0))))
		assert_float(off_axis).override_failure_message(
				("%s puts the ring %.1f degrees off a %.1f degree cone. A beam "
				+ "reaches the mat by range and is kept off it by aim alone, "
				+ "so this margin IS the exposure anchor's guarantee -- "
				+ "VISUAL_BAR.md's 0.43-0.49 mat, which measure_silhouette.py "
				+ "checks and nothing here can.") % [
					light.name, off_axis, light.spot_angle]
		).is_greater(light.spot_angle + 30.0)


## The mirror of `test_the_stage_wash_is_the_one_kept_off_the_mat_by_its_aim`:
## it records WHICH guarantee is load-bearing, so the one above cannot quietly
## start passing for the easy reason instead of the real one.
func test_a_beam_out_ranges_the_ring_and_is_kept_off_it_by_its_cone() -> void:
	for light in _beams(_rig()):
		var nearest := INF
		for point in _ring_prism():
			nearest = minf(nearest, (point - light.position).length())
		assert_float(light.spot_range).override_failure_message(
				("%s is now range-safe (%.1fm against %.2fm). That is an "
				+ "improvement, not a failure -- delete this test and let the "
				+ "range rule cover it, the way the stage wash's note says.")
				% [light.name, light.spot_range, nearest]
		).is_greater(nearest)


## A beam that widens or feathers has stopped being the thing the references
## show and has become another wash, of which this rig already has five.
func test_a_beam_is_narrow_and_hard() -> void:
	for light in _beams(_rig()):
		assert_float(light.spot_angle).override_failure_message(
				"%s opens to %.1f degrees half-angle; the house wash is 46 and "
				% [light.name, light.spot_angle]
				+ "the reference shafts are 2-4 degrees TOTAL"
		).is_between(2.0, 6.0)
		# Low is hard: Godot raises the cone's rim term to
		# 1.0 / spot_angle_attenuation, so a small parameter is a large
		# exponent and a flat cone with an edge on it.
		assert_float(light.spot_angle_attenuation).override_failure_message(
				"%s feathers at %.2f -- see BEAM_CONE_FALLOFF, low is hard here"
				% [light.name, light.spot_angle_attenuation]
		).is_less_equal(0.5)
		assert_float(light.spot_attenuation).is_less_equal(0.6)
		assert_bool(light.shadow_enabled).is_false()
		assert_float(light.light_specular).override_failure_message(
				"%s casts a specular highlight. That is the one way a cone "
				% light.name
				+ "which never touches the mat can still move the silhouette "
				+ "measurement this rig is cone-limited to protect."
		).is_equal(0.0)


## Outward and down. This is what the cross-aim is allowed to bend and not
## break: a beam may land most of the way round a corner from the chord it
## hangs on, but it must still be leaving.
##
## THE FIRST VERSION OF THIS TEST ASSERTED THE WRONG QUANTITY and two beams
## failed it correctly. It compared the fixture's aim against the direction
## from the hall's centre to the fixture, and demanded a dot over 0.3.
## Beam00 and Beam06 hang near the corners of the truss square and score 0.08
## there -- they leave almost tangentially in plan, because the hall is an
## obround 111m round and a target 30 degrees along its curve from a corner is
## nearly sideways.
##
## They were not aimed wrongly: Beam00 hangs 9.2m from the centre and lands
## 37.6m from it. It is emphatically leaving. What the old assertion measured
## was the instant of departure, and the near-tangential departure is the
## crossing the cross-aim exists to produce -- so the threshold was rejecting
## the feature.
##
## What is asserted instead is the end-to-end fact plus a reversal guard.
func test_a_beam_aims_outward_and_down() -> void:
	var loop := ArenaBuilder._plan_loop(
			ArenaLighting.BOWL_INNER + ArenaLighting.BEAM_TARGET_OFFSET)
	for light in _beams(_rig()):
		var axis := -light.global_transform.basis.z.normalized()
		assert_float(axis.y).override_failure_message(
				"%s aims upward (y %.3f); the beams rake DOWN across the bowl"
				% [light.name, axis.y]
		).is_less(-0.02)
		# Where the axis meets the target plane, against where it started.
		var travel := light.spot_range
		var lands := light.position + axis * travel
		var from_centre := Vector2(light.position.x, light.position.z).length()
		var to_centre := Vector2(lands.x, lands.z).length()
		assert_float(to_centre).override_failure_message(
				("%s ends %.1fm from the hall's centre having started %.1fm "
				+ "out. A beam that closes on the ring as it travels is aimed "
				+ "at the one thing this rig is built to keep light off.")
				% [light.name, to_centre, from_centre]
		).is_greater(from_centre + 10.0)
		# The reversal guard the old threshold was trying to be. Zero, not 0.3:
		# tangential is allowed, turning back is not.
		var out_plan := Vector2(light.position.x, light.position.z).normalized()
		var aim_plan := Vector2(axis.x, axis.z).normalized()
		assert_float(aim_plan.dot(out_plan)).override_failure_message(
				"%s aims back across the hall (dot %.2f)"
				% [light.name, aim_plan.dot(out_plan)]
		).is_greater(0.0)
		assert_int(loop.size()).is_greater(0)


## The shafts are the point, so they are the brightest thing in the haze.
## Pins the design intent, and catches the stage accents being pushed past
## them by some later entrance-set round.
func test_the_beams_are_the_brightest_shafts_in_the_hall() -> void:
	var rig := _rig()
	var dimmest_beam := INF
	var brightest_other := 0.0
	for child in rig.get_children():
		if child is not Light3D:
			continue
		var light: Light3D = child
		if String(light.name).begins_with("Beam"):
			dimmest_beam = minf(dimmest_beam, light.light_volumetric_fog_energy)
		else:
			brightest_other = maxf(brightest_other,
					light.light_volumetric_fog_energy)
	assert_float(dimmest_beam).override_failure_message(
			("the dimmest beam scatters at %.2f against some other fixture's "
			+ "%.2f. A beam is defined by the air it crosses; if something "
			+ "else in the hall out-scatters it, the shafts are no longer "
			+ "what the frame is about.") % [dimmest_beam, brightest_other]
	).is_greater(brightest_other)
