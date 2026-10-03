extends GdUnitTestSuite
## The phone's on-screen controls (TouchControls): the stick maps onto the
## same four move actions the keyboard does, the buttons sit on screen, and
## nothing shows without a human player.

func test_the_stick_drives_the_move_actions_with_a_dead_zone() -> void:
	var s := TouchControls.stick_strengths(Vector2(0.05, -0.05))
	for a: String in TouchControls.STICK_ACTIONS:
		assert_float(s[a]).is_equal(0.0)
	s = TouchControls.stick_strengths(Vector2(1.0, 0.0))
	assert_float(s["move_right"]).is_equal(1.0)
	assert_float(s["move_left"]).is_equal(0.0)
	s = TouchControls.stick_strengths(Vector2(0.0, -2.0))
	assert_float(s["move_up"]).is_equal(1.0)
	for a: String in TouchControls.STICK_ACTIONS:
		assert_bool(InputMap.has_action(a)).is_true()


func test_every_button_is_a_real_action_and_on_screen() -> void:
	var size := Vector2(2400, 1080)
	var lay := TouchControls.layout(size)
	var rect := Rect2(Vector2.ZERO, size)
	for b: Array in lay["buttons"]:
		assert_bool(InputMap.has_action(b[0])).override_failure_message(b[0]).is_true()
		var c: Vector2 = b[3]
		var r: float = b[4]
		assert_bool(rect.has_point(c - Vector2(r, r)) and rect.has_point(c + Vector2(r, r))) \
				.override_failure_message("%s off screen" % b[1]).is_true()
	# Buttons do not overlap one another.
	var bs: Array = lay["buttons"]
	for i in bs.size():
		for j in range(i + 1, bs.size()):
			assert_float((bs[i][3] as Vector2).distance_to(bs[j][3])) \
					.is_greater(float(bs[i][4]) * 1.9)


func test_no_controls_when_nobody_plays() -> void:
	assert_bool(TouchControls.wanted(false)).is_false()
