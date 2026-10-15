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
