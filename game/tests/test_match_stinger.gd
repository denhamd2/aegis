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
