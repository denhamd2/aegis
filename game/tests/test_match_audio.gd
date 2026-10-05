extends GdUnitTestSuite
## The hall's sound (MatchAudio, SfxPool): every sound it asks for exists,
## strikes are heard on landing and slams are left to the bump detector, and
## a sound can never touch the global RNG a match seed is drawn from.

const NAMED := ["crowd_bed", "crowd_walla_a", "crowd_walla_b", "crowd_boo",
		"crowd_cheer", "crowd_roar", "crowd_finish", "bell_start", "bell_end",
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


## Five loops of different lengths: no two seams land together for minutes.
func test_the_crowd_beds_are_out_of_step() -> void:
	var lengths := []
	for n: String in ["crowd_bed", "crowd_walla_a", "crowd_walla_b"]:
		var s := SfxPool.stream(n) as AudioStreamOggVorbis
		lengths.append(int(round(s.get_length())))
	assert_array(lengths).is_equal([52, 23, 41])
	# Pairwise co-prime: the combined pattern repeats only after the product.
	for i in lengths.size():
		for j in range(i + 1, lengths.size()):
			assert_int(_gcd(lengths[i], lengths[j])).is_equal(1)


func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t := b
		b = a % b
		a = t
	return a


func test_the_house_is_for_cody_and_against_roman() -> void:
	assert_float(MatchAudio.favor_of("ROMAN REIGNS")).is_less(0.0)
	assert_float(MatchAudio.favor_of("Cody Rhodes")).is_greater(0.0)
	assert_float(MatchAudio.favor_of("WRESTLERA")).is_equal(0.0)


func test_the_room_warms_over_the_match() -> void:
	assert_float(MatchAudio.phase_floor(0.0)).is_equal(0.0)
	var prev := 0.0
	for t in range(0, 360, 10):
		var f := MatchAudio.phase_floor(float(t))
		assert_float(f).is_greater_equal(prev)
		prev = f
	assert_float(MatchAudio.phase_floor(MatchAudio.PHASE_FULL)) \
			.is_equal(MatchAudio.PHASE_FLOOR_MAX)
	# Quiet in the first minute: well under half the final warmth.
	assert_float(MatchAudio.phase_floor(60.0)).is_less(MatchAudio.PHASE_FLOOR_MAX * 0.25)


func test_the_beds_rise_with_the_intensity_and_the_new_ones_most() -> void:
	var low := MatchAudio.bed_levels(0.0)
	var high := MatchAudio.bed_levels(1.0)
	for k: String in low:
		assert_float(high[k]).is_greater(low[k])
	# The added beds swing further than the base one: that is the swell.
	assert_float(float(high["walla_b"]) - float(low["walla_b"])) \
			.is_greater(float(high["bed"]) - float(low["bed"]))


func test_heat_is_off_when_cold_and_dies_away() -> void:
	assert_float(MatchAudio.heat_db(0.0)).is_less(-60.0)
	assert_float(MatchAudio.heat_db(1.0)).is_equal(MatchAudio.HEAT_ON_DB)
	assert_float(MatchAudio.cool(1.0, MatchAudio.HEAT_HALF_LIFE)).is_equal_approx(0.5, 0.001)


## The heel's blows and taunts bring boos; the face's, a cheer -- in a live
## match, through the real signals.
func test_the_heel_is_booed_and_the_face_cheered() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	var heel: WrestlerController = auto_free(WrestlerController.new())
	heel.display_name = "ROMAN REIGNS"
	var face: WrestlerController = auto_free(WrestlerController.new())
	face.display_name = "CODY RHODES"
	audio._heat(heel, 0.5)
	assert_float(audio.boo).is_equal(0.5)
	assert_float(audio.cheer).is_equal(0.0)
	audio._heat(face, 0.7)
	assert_float(audio.cheer).is_equal(0.7)
	assert_float(audio.boo).is_equal(0.5)


## The winner's song starts at its main part, not the intro, and fades in
## under a ducked crowd.
func test_winner_theme_starts_at_the_chorus_not_the_top() -> void:
	var audio: MatchAudio = auto_free(MatchAudio.new())
	add_child(audio)
	assert_float(StageVideo.chorus_at("roman")).is_equal(45.0)
	assert_float(StageVideo.chorus_at("cody")).is_equal(22.5)
	assert_float(StageVideo.chorus_at("nobody")).is_less(0.0)
	assert_bool(audio.winner_theme("nobody")).is_false()
	assert_bool(audio.winner_theme("cody")).is_true()
	var p := audio.theme_player()
	assert_object(p).is_not_null()
	assert_float(p.volume_db).is_less(-50.0)
	assert_float(audio._theme_from).is_equal(22.5)
	# Fades in over time and ducks the beds.
	audio._crowd = null
	for i in 90:
		audio._process(0.05)
	assert_float(p.volume_db).is_greater(MatchAudio.THEME_DB - 1.0)
	assert_float(audio._duck).is_less(-5.0)
