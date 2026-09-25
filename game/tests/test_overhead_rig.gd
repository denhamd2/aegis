extends GdUnitTestSuite
## The overhead rig: every light has a body, every body points where its
## light points, and the steel model carries the parts ArenaBuilder dresses.
##
## Renderer-free. What the rig LOOKS like is closed on rendered frames
## (gauntlet/refs/lighting.md); these hold the geometry that makes it honest.


func _rig() -> ArenaLighting:
	var rig: ArenaLighting = auto_free(ArenaLighting.new())
	add_child(rig)
	return rig


func _lights(rig: ArenaLighting) -> Array[SpotLight3D]:
	var out: Array[SpotLight3D] = []
	for child in rig.get_children():
		if child is SpotLight3D:
			out.append(child)
	return out


## No light without a fixture. A bare SpotLight3D in the rig is a light
## coming out of the air, which is the defect this round existed to fix.
func test_every_light_hangs_in_a_body() -> void:
	var rig := _rig()
	for light in _lights(rig):
		var body := rig.get_node_or_null("Body" + String(light.name)) as Node3D
		assert_object(body).override_failure_message(
				"%s has no fixture body" % light.name).is_not_null()
		assert_vector(body.position).is_equal_approx(light.position,
				Vector3.ONE * 0.001)


## The lens points down the beam. The body is articulated (fixed base,
## panned yoke, tilted head) rather than copying the light's basis, so this
## is the check that the pan/tilt solve is right for every aim in the rig:
## straight down, raking, outward over the bowl, and up at the roof.
func test_every_lens_faces_along_its_beam() -> void:
	var rig := _rig()
	for light in _lights(rig):
		var body := rig.get_node("Body" + String(light.name)) as Node3D
		var lens := body.get_node("FixtureLens") as Node3D
		var lens_forward := -(body.basis * lens.basis).z.normalized()
		var beam := -light.transform.basis.z.normalized()
		assert_float(lens_forward.dot(beam)).override_failure_message(
				"%s: lens faces %s, beam goes %s" % [light.name, lens_forward, beam]
		).is_greater(0.999)


## The base hangs from steel above or stands on steel below, and never leans:
## only the yoke and head move on a moving head.
func test_every_base_is_level() -> void:
	var rig := _rig()
	for light in _lights(rig):
		var body := rig.get_node("Body" + String(light.name)) as Node3D
		var base := body.get_node("FixtureBase") as Node3D
		var up := (body.basis * base.basis).y.normalized()
		assert_float(absf(up.y)).is_greater(0.999)
		var standing := (-light.transform.basis.z).y > 0.3
		# Hung fixtures keep the base's +Y up; standing ones are flipped.
		assert_bool(up.y < 0.0).is_equal(standing)


## The roof wash is aimed at the roof. Its cones out-range nothing on the
## floor only because they point up -- this keeps it that way.
func test_the_roof_wash_points_at_the_roof() -> void:
	var rig := _rig()
	var count := 0
	for light in _lights(rig):
		if String(light.name).begins_with("RoofWash"):
			count += 1
			assert_float((-light.transform.basis.z).y).is_greater(0.5)
	assert_int(count).is_equal(ArenaLighting.ROOF_WASH_FIXTURES)


func test_the_rig_model_carries_what_arena_builder_dresses() -> void:
	var packed: PackedScene = load(ArenaBuilder.RIG_MODEL)
	assert_object(packed).is_not_null()
	var root: Node3D = packed.instantiate()
	var wanted: Array = ArenaBuilder.RIG_MATERIALS.keys()
	wanted.append("RigLeds")
	for part: String in wanted:
		assert_object(root.find_child(part, true, false)).override_failure_message(
				"overhead_rig.glb has no '%s'" % part).is_not_null()
	root.free()


## The LED strips are blue-led: capture_harness.gd's HUD probes are blinded
## by a green-dominant element.
func test_the_rig_leds_are_not_green_dominant() -> void:
	var c: Color = MaterialLibrary.resolve("arena_rig_led").albedo_color
	assert_bool(c.g > c.r and c.g > c.b).is_false()
