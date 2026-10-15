extends GdUnitTestSuite
## Follow-through and surface-aware pain sells (ImpactSell).

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func test_follow_through_is_presentation_only_and_wired_on_wrestlers() -> void:
	var wrestler: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(wrestler)
	var move := load("res://resources/moves/grapple_vertical_suplex.tres") as MoveDef
	var state_before := wrestler.fsm.current_state
	var ticks_before := wrestler._move_ticks_remaining
	wrestler.impact_sell.react_to_move(move)
	assert_array(wrestler.impact_sell.active_profiles()).contains("suplex")
	assert_int(wrestler.fsm.current_state).is_equal(state_before)
	assert_int(wrestler._move_ticks_remaining).is_equal(ticks_before)
	wrestler.impact_sell.react_to_surface(&"table", true)
	assert_array(wrestler.impact_sell.active_profiles()).contains("table_rebound")

func test_paired_finishers_get_distinct_follow_through_profiles() -> void:
	var suplex := load("res://resources/moves/grapple_vertical_suplex.tres") as MoveDef
	var cross_rhodes := load("res://resources/moves/finisher_cross_rhodes.tres") as MoveDef
	var cross_behind := load("res://resources/moves/finisher_cross_rhodes_behind.tres") as MoveDef
	assert_str(ImpactSell.move_profile(suplex)).is_equal("suplex")
	assert_str(ImpactSell.move_profile(cross_rhodes)).is_equal("cross_rhodes")
	assert_str(ImpactSell.move_profile(cross_behind)).is_equal("cross_rhodes")
	assert_str(ImpactSell.move_profile(null)).is_empty()


func test_surface_landings_route_to_recoil_or_localized_protection() -> void:
	assert_str(ImpactSell.surface_profile(&"table", true)).is_equal("table_rebound")
	assert_str(ImpactSell.surface_profile(&"table", false)).is_empty()
	assert_str(ImpactSell.surface_profile(&"barbed_wire_board", false)).is_equal("wire_guard")
	assert_str(ImpactSell.surface_profile(&"thumbtacks", false)).is_equal("tack_guard")
	assert_str(ImpactSell.surface_profile(&"bed_of_nails", false)).is_equal("tack_guard")
	assert_str(ImpactSell.surface_profile(&"ladder", false)).is_equal("ladder_crash")
	assert_str(ImpactSell.surface_profile(&"steel_chair", false)).is_empty()


func test_ladder_landing_keeps_the_specific_crash_sell() -> void:
	var wrestler: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(wrestler)
	var ladder_move := load("res://resources/moves/weapon_ladder_slam.tres") as MoveDef
	assert_str(ImpactSell.move_profile(ladder_move)).is_equal("suplex")
	wrestler.impact_sell.react_to_surface(&"ladder", false)
	wrestler.impact_sell.react_to_move(ladder_move)
	assert_array(wrestler.impact_sell.active_profiles()).contains("ladder_crash")
	assert_bool(wrestler.impact_sell.active_profiles().has(&"suplex")).is_false()


func test_impact_is_sharp_then_recoils_and_guard_holds_before_releasing() -> void:
	assert_float(ImpactSell.impact_envelope(-1.0)).is_equal(0.0)
	assert_float(ImpactSell.impact_envelope(0.0)).is_equal(0.0)
	assert_float(ImpactSell.impact_envelope(1.0)).is_greater(0.9)
	assert_float(ImpactSell.impact_envelope(10.0)).is_less(0.5)
	assert_float(ImpactSell.guard_envelope(0.0)).is_equal(0.0)
	assert_float(ImpactSell.guard_envelope(10.0)).is_equal(1.0)
	assert_float(ImpactSell.guard_envelope(50.0)).is_equal(0.0)
