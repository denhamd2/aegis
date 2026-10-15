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
	assert_int(schedule.size()).is_equal(3)
	assert_float(schedule[0]).is_between(28.0, 38.0)
	assert_float(schedule[1] - schedule[0]).is_greater_equal(90.0)
	assert_float(schedule[2] - schedule[1]).is_greater_equal(90.0)
	assert_float(CrowdChants.chant_gain_db(0.0, 35.7)).is_less(-80.0)
	assert_float(CrowdChants.chant_gain_db(10.0, 35.7)).is_equal_approx(
			CrowdChants.CODY_CHANT_LEVEL_DB, 0.01)
	assert_float(CrowdChants.chant_gain_db(35.7, 35.7)).is_less(-80.0)

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
