extends GdUnitTestSuite
## The owner, 2 Nov: "wrestlers recovery time was far too quick, especially
## when their health is low it should take a lot longer to recover, enabling
## time for finishers, and setup moves ... if someone is put through a table
## or hit with a weapon or a signature move it should take much longer to get
## back up and also they should be groggy getting up."


func test_the_quick_rise_slows_as_he_wears_down_and_stops_below_the_line() -> void:
	var fresh := WrestlerController.quick_rise_delay(1.0)
	var worn := WrestlerController.quick_rise_delay(WrestlerController.QUICK_RISE_MIN_HEALTH)
	assert_int(fresh).is_equal(WrestlerController.QUICK_DOWN_RECOVERY_DELAY_TICKS)
	# at the line he lies four seconds before he can kip up
	assert_int(worn).is_greater_equal(240)
	var prev := worn
	for h in [0.55, 0.7, 0.85, 1.0]:
		var d := WrestlerController.quick_rise_delay(h)
		assert_int(d).is_less_equal(prev)
		prev = d
	# below it, no quick rise at all: the staged rise only
	assert_float(WrestlerController.QUICK_RISE_MIN_HEALTH).is_between(0.3, 0.6)


func test_a_hard_knockdown_keeps_him_down_longer() -> void:
	assert_float(WrestlerController.HARD_DOWN_SCALE).is_greater_equal(1.3)


func test_he_gets_up_groggy_when_hurt_or_after_a_big_one() -> void:
	# a quick rise, fresh: straight back to it
	assert_int(WrestlerController.groggy_for(0.9, false, false)).is_equal(0)
	# the slow rise, or a hard knockdown: groggy, longer the more hurt
	var staged := WrestlerController.groggy_for(0.9, true, false)
	var hurt := WrestlerController.groggy_for(0.2, true, false)
	var hard := WrestlerController.groggy_for(0.2, true, true)
	assert_int(staged).is_greater(0)
	assert_int(hurt).is_greater(staged)
	assert_int(hard).is_greater(hurt)
	# and slow on his feet while it lasts
	assert_float(WrestlerController.GROGGY_SPEED).is_less(0.8)
