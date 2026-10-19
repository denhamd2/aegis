extends GdUnitTestSuite
## The generated chant beds are gone. Match crowd reactions now come from
## continuous crowd ambience and nonverbal pops, not synthetic voices.


func test_match_event_hooks_are_silent_and_keep_the_match_clock() -> void:
	var chants: CrowdChants = auto_free(CrowdChants.new())
	var pool: SfxPool = auto_free(SfxPool.new())
	add_child(chants)
	add_child(pool)
	var played := []
	pool.played.connect(func(sound: String, _db: float) -> void: played.append(sound))
	chants.bell()
	chants.moved(1.0, 1.0)
	chants.fired_up(1.0)
	chants.kicked_out(3)
	chants.table_set_up()
	chants.count(2, pool)
	chants.match_over(1.0)
	chants.entrance("cody")
	chants.tick(0.5, 1.0)
	assert_array(played).is_empty()
	assert_float(chants.match_time()).is_equal_approx(0.5, 0.001)


func test_generated_chant_assets_are_not_in_the_game() -> void:
	for path in [
		"res://assets/audio/chant_this_is_awesome_0.ogg",
		"res://assets/audio/chant_cody_0.ogg",
		"res://assets/audio/chant_otc_0.ogg",
		"res://assets/audio/crowd_count_1_0.ogg",
		"res://assets/audio/crowd_whoa_0.ogg",
	]:
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_false()


func test_cody_chant_is_faded_and_spaced_out_after_the_bell() -> void:
	assert_bool(ResourceLoader.exists("res://assets/audio/crowd_cody_chant.ogg")).is_true()
	var schedule := CrowdChants.schedule_for_seed(1234)
	assert_int(schedule.size()).is_equal(CrowdChants.CHANT_SLOTS)
	assert_float(schedule[0]).is_between(20.0, 28.0)
	for i in range(1, schedule.size()):
		# a whole chant (35.7 s) and a breather between them
		assert_float(schedule[i] - schedule[i - 1]).is_greater_equal(60.0)
	assert_float(CrowdChants.chant_gain_db(0.0, 35.7)).is_less(-70.0)
	assert_float(CrowdChants.chant_gain_db(10.0, 35.7)).is_equal_approx(
			CrowdChants.CODY_CHANT_LEVEL_DB, 0.01)
	assert_float(CrowdChants.chant_gain_db(35.7, 35.7)).is_less(-70.0)

	var chants: CrowdChants = auto_free(CrowdChants.new())
	add_child(chants)
	chants.configure_cody_chant(load("res://assets/audio/crowd_cody_chant.ogg"),
			RingAnnouncer.under_bus(), 1234)
	chants.entrance("cody")
	chants.tick(schedule[0] + 1.0, 0.0)
	assert_int(chants._next_chant).is_equal(0)
	assert_bool(chants._chant_player.playing).is_false()
	chants.bell()
	chants.tick(schedule[0] + 1.1, 0.0)
	assert_int(chants._next_chant).is_equal(1)
	assert_bool(chants._chant_active).is_true()
	chants.match_over(1.0)
	assert_float(chants._ending_elapsed).is_equal(0.0)


func test_match_finish_cancels_any_later_chant_slots() -> void:
	var chants: CrowdChants = auto_free(CrowdChants.new())
	add_child(chants)
	chants.configure_cody_chant(load("res://assets/audio/crowd_cody_chant.ogg"),
			RingAnnouncer.under_bus(), 1234)
	chants.bell()
	chants.match_over(1.0)
	chants.tick(300.0, 0.0)
	assert_int(chants._next_chant).is_equal(0)
	assert_bool(chants._chant_player.playing).is_false()


## The owner's other chants (19 Oct): O-T-C and the building turning on Roman
## with Roman in the match, "This is awesome!" only once it has had time to
## earn it, each loudness-matched to Cody's and faded in and out.
func test_roman_and_this_is_awesome_chants_join_codys() -> void:
	for path: String in MatchAudio.ROMAN_CROWD_CHANTS.values() + [MatchAudio.THIS_IS_AWESOME_CHANT]:
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
	var chants: CrowdChants = auto_free(CrowdChants.new())
	add_child(chants)
	chants.configure(RingAnnouncer.under_bus(), 77)
	chants.add_chant("cody", load(MatchAudio.CODY_CROWD_CHANT))
	for id: String in MatchAudio.ROMAN_CROWD_CHANTS:
		chants.add_chant(id, load(MatchAudio.ROMAN_CROWD_CHANTS[id]))
	chants.add_chant("this_is_awesome", load(MatchAudio.THIS_IS_AWESOME_CHANT),
			MatchAudio.THIS_IS_AWESOME_FROM)
	chants.bell()
	var schedule := CrowdChants.schedule_for_seed(77)
	var t := 0.0
	for at: float in schedule:
		while t < at + 0.05:
			chants.tick(0.25, 0.0)
			t += 0.25
		chants._chant_player.stop()            # let the next slot start
		chants._chant_active = false
	assert_int(chants.chanted.size()).is_equal(CrowdChants.CHANT_SLOTS)
	for i in chants.chanted.size():
		if chants.chanted[i] == "this_is_awesome":
			assert_float(schedule[i]).is_greater_equal(MatchAudio.THIS_IS_AWESOME_FROM)
		if i > 0:
			assert_str(chants.chanted[i]).is_not_equal(chants.chanted[i - 1])
	# the 7 s O-T-C is heard at full, not all fade
	assert_float(CrowdChants.chant_gain_db(3.4, 6.78)).is_equal_approx(CrowdChants.CODY_CHANT_LEVEL_DB, 0.01)
	assert_float(CrowdChants.chant_gain_db(0.0, 6.78)).is_less(-70.0)
	assert_float(CrowdChants.chant_gain_db(6.78, 6.78)).is_less(-70.0)


func test_no_roman_chants_without_roman() -> void:
	var cody := WrestlerController.new()
	cody.entrance_style = "cody"
	assert_bool(MatchAudio.is_in_match([cody], "roman")).is_false()
	assert_bool(MatchAudio.is_in_match([cody], "cody")).is_true()
	cody.free()
