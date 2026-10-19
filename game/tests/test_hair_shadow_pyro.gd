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
	# The top fill too: shadowless, it filled in every key shadow.
	keys.append_array(rig.find_children("Top*", "SpotLight3D", false, false))
	assert_int(keys.size()).is_equal(6)
	for key: SpotLight3D in keys:
		assert_bool(key.shadow_enabled).is_true()
		# The overhead fills are a tighter source than the keys: the dark
		# pool straight under a body (cody_roman_2k26.md).
		var want := ArenaLighting.TOP_LIGHT_SIZE if String(key.name).begins_with("Top") \
				else ArenaLighting.KEY_LIGHT_SIZE
		assert_float(key.light_size).is_equal_approx(want, 0.001)


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


func test_flames_carry_a_sustained_light() -> void:
	var pyro: EntrancePyro = auto_free(EntrancePyro.new())
	add_child(pyro)
	pyro.fire("roman")
	var sustained := 0
	for f: Array in pyro._flashes:
		if f[4]:
			sustained += 1
	# The first pulse: ten flame units, the four original ones lit while they
	# burn; the room's red flash is a pop. Four more pulses follow on the
	# beat, and the barrage over the set (the owner, 19 Oct: five times the
	# pyro).
	assert_int(sustained).is_equal(EntrancePyro.FLAME_LIT_XS.size())
	assert_int(pyro._flashes.size()).is_equal(EntrancePyro.FLAME_LIT_XS.size() + 1)
	assert_int(pyro._pending.size()).is_equal(EntrancePyro.FLAME_PULSES)
	assert_int(pyro.find_children("", "GPUParticles3D", false, false).size()) \
			.is_equal(EntrancePyro.FLAME_DECK_XS.size() + EntrancePyro.FLAME_HIGH_XS.size())


## Five times the fireworks: every volley cue is VOLLEYS waves, and Cody's
## WHOA twice that plus the shells down the ramp.
func test_every_volley_is_a_five_wave_barrage() -> void:
	var pyro: EntrancePyro = auto_free(EntrancePyro.new())
	add_child(pyro)
	pyro.fire("stage")
	for i in 240:
		pyro._physics_process(1.0 / 60.0)
	var stage_shells := pyro.find_children("", "GPUParticles3D", false, false).size()
	assert_int(stage_shells).is_equal(EntrancePyro.SET_SHELL_XS.size() * EntrancePyro.VOLLEYS)
	var whoa: EntrancePyro = auto_free(EntrancePyro.new())
	add_child(whoa)
	whoa.fire("cody_hit")
	for i in 360:
		whoa._physics_process(1.0 / 60.0)
	var whoa_shells := whoa.find_children("", "GPUParticles3D", false, false).size()
	assert_int(whoa_shells).is_equal(EntrancePyro.WHOA_VOLLEYS
			* (EntrancePyro.SET_SHELL_XS.size() + EntrancePyro.RAMP_SHELL_ZS.size() * 2))
	# and not a light per shell
	assert_int(whoa._flashes.size()).is_less(whoa_shells / 3)


## The owner: no sparkler or waterfall pyro for either man -- fire for
## Roman, firework shells for Cody. Nothing that fires a spark fountain
## (a jet that emits upward over its life) or a falling sheet is left.
func test_no_sparkler_or_waterfall_pyro() -> void:
	var pyro: EntrancePyro = auto_free(EntrancePyro.new())
	add_child(pyro)
	assert_bool(pyro.has_method("_gerb")).is_false()
	assert_bool(pyro.has_method("_waterfall")).is_false()
	for cue: String in ["stage", "roman", "cody_hit", "cody_punch", "over_ring"]:
		pyro.fire(cue)
	for i in 120:
		pyro._physics_process(1.0 / 60.0)
	var emitters := 0
	for p: GPUParticles3D in pyro.find_children("", "GPUParticles3D", false, false):
		emitters += 1
		var m := p.process_material as ParticleProcessMaterial
		# A shell bursts all at once in every direction; a flame is a short
		# fireball. A fountain is a slow narrow jet held over its life, and a
		# waterfall points down.
		assert_bool(m.direction.y < 0.0).override_failure_message("a falling sheet").is_false()
		var shell := is_equal_approx(p.explosiveness, 1.0) and m.spread >= 179.0
		var flame := p.lifetime <= 1.0 and p.draw_pass_1 is QuadMesh \
				and ((p.draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_texture != null
		assert_bool(shell or flame).override_failure_message("an emitter that is neither a shell nor a flame").is_true()
	assert_int(emitters).is_greater(10)


## Rocket pyro, not a waterfall (the owner, 19 Oct): every shell goes up on a
## trail from its mortar and bursts where it stops; nothing bursts first.
func test_every_shell_goes_up_as_a_rocket() -> void:
	var pyro: EntrancePyro = auto_free(EntrancePyro.new())
	add_child(pyro)
	for cue: String in ["stage", "cody_hit", "over_ring"]:
		pyro.fire(cue)
	pyro._physics_process(1.0 / 60.0)
	assert_int(pyro._rockets.size()).is_greater(0)
	assert_int(pyro.find_children("", "GPUParticles3D", false, false).size()).is_equal(0)
	for r: Array in pyro._rockets:
		assert_float((r[2] as Vector3).y - (r[1] as Vector3).y).is_greater(4.0)
