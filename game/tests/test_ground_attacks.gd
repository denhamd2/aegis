extends GdUnitTestSuite
## Phase 4, position: a man down is worked by where the other man stands --
## the head end gets the fist, beside him a stomp to the body, the feet end a
## stomp to the legs.


func test_where_he_stands_along_the_body_picks_the_zone() -> void:
	assert_str(WrestlerController.zone_along_body(-0.9)).is_equal("head")
	assert_str(WrestlerController.zone_along_body(WrestlerController.HEAD_ZONE_Z)).is_equal("head")
	assert_str(WrestlerController.zone_along_body(0.0)).is_equal("body")
	assert_str(WrestlerController.zone_along_body(WrestlerController.LEGS_ZONE_Z)).is_equal("legs")
	assert_str(WrestlerController.zone_along_body(0.8)).is_equal("legs")


func test_each_zone_gets_its_move_and_the_move_hurts_that_zone() -> void:
	var head := WrestlerController.ground_move_for("head")
	var body := WrestlerController.ground_move_for("body")
	var legs := WrestlerController.ground_move_for("legs")
	assert_float(head.damage_head).is_greater(0.0)
	assert_float(body.damage_torso).is_greater(0.0)
	assert_float(legs.damage_legs).is_greater(0.0)
	assert_str(String(head.animation_pair_id)).is_equal("ground_fist")
	assert_str(String(legs.animation_pair_id)).is_equal("ground_stomp")


func test_ground_attacks_are_wearing_down_not_a_shortcut() -> void:
	# A strike earns momentum; working a man on the mat barely does -- at 3 a
	# stomp, matches ran to their finishers in half the time.
	for m: MoveDef in [WrestlerController.GROUND_FIST, WrestlerController.GROUND_STOMP_BODY,
			WrestlerController.GROUND_STOMP_LEGS]:
		assert_float(m.momentum_gain).is_less_equal(1.0)
