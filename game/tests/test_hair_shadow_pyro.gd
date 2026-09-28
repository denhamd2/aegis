extends GdUnitTestSuite
## refs/aaa_gap.md items 7-9: hair shine (HairLook, the root-to-tip shade),
## soft key shadows, and pyro that lights what is near it while it burns.

func test_hair_look_stretches_the_highlight() -> void:
	var m := StandardMaterial3D.new()
	HairLook.apply(m)
	assert_bool(m.anisotropy_enabled).is_true()
	assert_float(m.anisotropy).is_equal_approx(HairLook.ANISOTROPY, 0.001)
	# Along the tangent needs no flowmap.
	assert_object(m.anisotropy_flowmap).is_null()


func test_a_flowmap_encodes_the_direction_across_the_strands() -> void:
	var m := StandardMaterial3D.new()
	HairLook.apply(m, Vector2(0.0, 1.0))
	var c := m.anisotropy_flowmap.get_image().get_pixel(0, 0)
	assert_float(c.r).is_equal_approx(0.5, 0.01)
	assert_float(c.g).is_equal_approx(1.0, 0.01)


func test_roman_hair_is_darkest_at_the_root() -> void:
	assert_float(RomanModel.hair_root_to_tip(0.0)).is_equal_approx(
			RomanModel.HAIR_ROOT_SHADE, 0.001)
	assert_float(RomanModel.hair_root_to_tip(0.02)).is_between(
			RomanModel.HAIR_ROOT_SHADE, 1.0)
	assert_float(RomanModel.hair_root_to_tip(0.1)).is_equal(1.0)


func test_the_ring_keys_are_wide_sources() -> void:
	var rig: ArenaLighting = auto_free(ArenaLighting.new())
	add_child(rig)
	var keys := rig.find_children("Key*", "SpotLight3D", false, false)
	assert_int(keys.size()).is_equal(4)
	for key: SpotLight3D in keys:
		assert_bool(key.shadow_enabled).is_true()
		assert_float(key.light_size).is_equal_approx(ArenaLighting.KEY_LIGHT_SIZE, 0.001)


## A gerb's light holds while the jet burns, and only then goes out.
func test_a_burning_jet_holds_its_light() -> void:
	assert_float(EntrancePyro.sustain_level(0.0)).is_equal(0.0)
	assert_float(EntrancePyro.sustain_level(0.3)).is_equal(1.0)
	assert_float(EntrancePyro.sustain_level(0.65)).is_equal(1.0)
	assert_float(EntrancePyro.sustain_level(0.9)).is_between(0.0, 0.5)
	assert_float(EntrancePyro.sustain_level(1.0)).is_equal(0.0)


func test_its_flicker_stays_in_band_and_varies() -> void:
	var lo := 1.0
	var hi := 0.0
	for i in 120:
		var f := EntrancePyro.flicker(i / 60.0, 1.3)
		lo = minf(lo, f)
		hi = maxf(hi, f)
	assert_float(lo).is_greater_equal(1.0 - EntrancePyro.FLICKER - 0.001)
	assert_float(hi).is_less_equal(1.0 + 0.001)
	assert_float(hi - lo).is_greater(EntrancePyro.FLICKER * 0.5)


func test_gerbs_carry_a_sustained_light() -> void:
	var pyro: EntrancePyro = auto_free(EntrancePyro.new())
	add_child(pyro)
	pyro.fire("posts")
	var sustained := 0
	for f: Array in pyro._flashes:
		if f[4]:
			sustained += 1
	# Four post gerbs, each lit while it burns; the room flash is a pop.
	assert_int(sustained).is_equal(4)
	assert_int(pyro._flashes.size()).is_equal(5)
