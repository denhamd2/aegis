extends GdUnitTestSuite
## The hall's sound (MatchAudio, SfxPool): every sound it asks for exists,
## strikes are heard on landing and slams are left to the bump detector, and
## a sound can never touch the global RNG a match seed is drawn from.

const NAMED := ["crowd_bed", "crowd_roar", "crowd_finish", "bell_start", "bell_end",
		"bell_ding", "pyro_boom", "pyro_bang", "whoosh", "ui_move", "ui_select", "ui_back"]
const FAMILIES := ["crowd_pop", "crowd_ooh", "hit_punch", "hit_kick", "bump", "count_slap"]


func test_every_sound_it_plays_is_built() -> void:
	for s: String in NAMED:
		assert_object(SfxPool.stream(s)).override_failure_message("missing " + s).is_not_null()
	for f: String in FAMILIES:
		assert_int(SfxPool.family_size(f)).override_failure_message("no " + f).is_greater_equal(2)


func test_strikes_sound_on_landing_and_slams_do_not() -> void:
	var cases := {
		"strike_jab": "hit_punch", "strike_kick_heavy": "hit_kick",
		"ground_stomp_body": "hit_kick", "ground_fist": "hit_punch",
		"signature_superman_punch": "hit_punch", "strike_bionic_elbow": "hit_punch",
		"power_bodyslam": "", "grapple_vertical_suplex": "", "finisher_spear": "",
	}
	for id: String in cases:
		var move := load("res://resources/moves/%s.tres" % id) as MoveDef
		assert_str(MatchAudio.hit_sound(move)).override_failure_message(id) \
				.is_equal(cases[id])


func test_harder_strikes_are_louder() -> void:
	var jab := load("res://resources/moves/strike_jab.tres") as MoveDef
	var elbow := load("res://resources/moves/strike_bionic_elbow.tres") as MoveDef
	assert_float(MatchAudio.hit_volume(elbow)).is_greater_equal(MatchAudio.hit_volume(jab))
	assert_float(MatchAudio.hit_volume(elbow)).is_less_equal(0.0)


func test_a_bump_needs_a_real_fall_and_is_louder_the_harder_he_lands() -> void:
	assert_bool(is_nan(MatchAudio.bump_volume(0.5))).is_true()
	assert_bool(is_nan(MatchAudio.bump_volume(MatchAudio.BUMP_FALL_SPEED - 0.1))).is_true()
	var soft := MatchAudio.bump_volume(MatchAudio.BUMP_FALL_SPEED + 0.2)
	var hard := MatchAudio.bump_volume(MatchAudio.BUMP_FULL_SPEED + 1.0)
	assert_float(hard).is_greater(soft)
	assert_float(hard).is_equal(0.0)


func test_picking_a_sound_leaves_the_global_rng_alone() -> void:
	var pool := SfxPool.new()
	add_child(pool)
	seed(77)
	var expected := randi()
	seed(77)
	for i in 20:
		pool.play_any("hit_punch", -80.0)
	assert_int(randi()).is_equal(expected)
	pool.queue_free()


func test_two_pools_pick_the_same_sounds() -> void:
	var picks := [[], []]
	for n in 2:
		var pool := SfxPool.new()
		add_child(pool)
		pool.played.connect(func(s: String, _db: float) -> void: picks[n].append(s))
		for i in 12:
			pool.play_any("bump", -80.0)
		pool.queue_free()
	assert_array(picks[0]).is_equal(picks[1])
