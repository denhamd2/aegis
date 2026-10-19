extends GdUnitTestSuite
## The select-to-entrance wipe (MatchStinger): its bands start off screen,
## end covering it, move in the order drawn, and never run backwards.


func test_each_band_runs_from_nothing_to_full_cover() -> void:
	for k in 3:
		assert_float(MatchStinger.band_progress(0.0, k, MatchStinger.IN_TIME)).is_equal(0.0)
		assert_float(MatchStinger.band_progress(
				MatchStinger.IN_TIME + MatchStinger.STAGGER * k, k, MatchStinger.IN_TIME)) \
				.is_equal_approx(1.0, 1e-6)


func test_the_bands_follow_each_other_and_never_run_backwards() -> void:
	var t := 0.0
	var last := [0.0, 0.0, 0.0]
	while t <= MatchStinger.IN_TIME + MatchStinger.STAGGER * 3.0:
		for k in 3:
			var p := MatchStinger.band_progress(t, k, MatchStinger.IN_TIME)
			assert_float(p).is_greater_equal(float(last[k]))
			last[k] = p
			if k > 0:
				assert_float(p).is_less_equal(MatchStinger.band_progress(t, k - 1, MatchStinger.IN_TIME))
		t += 0.01


## The match-up screen (the owner, 19 Oct): the arena behind the names, a
## loading bar that fills to READY before the reveal, and `revealing` -- the
## title theme's cue to fade -- only once the bar is full and the match asked.
func test_the_matchup_screen_fills_its_bar_before_it_reveals() -> void:
	assert_bool(ResourceLoader.exists(MatchStinger.ARENA)).is_true()
	var s := MatchStinger.new()
	s.setup(Roster.by_id("roman"), Roster.by_id("cody"))
	add_child(s)
	var revealed := [false]
	s.revealing.connect(func() -> void: revealed[0] = true)
	s._stage = MatchStinger.Stage.HOLD
	s.progress = 0.5
	for i in 120:
		s._process(1.0 / 60.0)
	assert_bool(revealed[0]).override_failure_message("revealed before the match asked").is_false()
	assert_float(s._shown).is_equal_approx(0.5, 0.01)
	s.reveal()
	var frames := 0
	while not revealed[0] and frames < 600:
		s._process(1.0 / 60.0)
		frames += 1
	assert_bool(revealed[0]).is_true()
	assert_float(s._shown).is_equal(1.0)
	s.free()
