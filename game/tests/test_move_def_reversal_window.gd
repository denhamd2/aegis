extends GdUnitTestSuite
## Reversal-window boundary tests: frame N-1 fails, N succeeds,
## last frame succeeds, last+1 fails.

func test_reversal_window_boundaries() -> void:
	var move := MoveDef.new()
	move.reversal_window_start = 10
	move.reversal_window_end = 14

	assert_bool(move.is_in_reversal_window(9)).is_false()   # N-1 fails
	assert_bool(move.is_in_reversal_window(10)).is_true()   # N succeeds
	assert_bool(move.is_in_reversal_window(14)).is_true()   # last frame succeeds
	assert_bool(move.is_in_reversal_window(15)).is_false()  # last+1 fails
