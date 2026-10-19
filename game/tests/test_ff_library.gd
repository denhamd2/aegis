extends GdUnitTestSuite
## The Fight Forever move library (tools/moves/build_ff_library.py): every
## wrestler in the owner's compilation, every signature and special, each move
## tagged to the wrestlers who use it, and nothing unbuilt reachable in a match.


func test_every_wrestler_in_the_video_is_in_it() -> void:
	assert_int(FFMoveLibrary.WRESTLERS.size()).is_equal(52)
	for w: String in ["cody_rhodes", "kenny_omega", "adam_cole", "darby_allin", "mjf",
			"penta", "fenix", "miro", "aubrey_edwards", "yuka_sakazaki"]:
		assert_bool(FFMoveLibrary.WRESTLERS.has(w)).override_failure_message(w).is_true()


func test_every_move_loads_and_carries_its_tags() -> void:
	for m: String in FFMoveLibrary.MOVES:
		var def := FFMoveLibrary.move(m)
		assert_object(def).override_failure_message(m).is_not_null()
		if FFMoveLibrary.EXISTING.has(m):
			continue
		assert_str(def.get_meta("ff_name", "")).is_equal(FFMoveLibrary.MOVES[m]["name"])
		var tagged: PackedStringArray = def.get_meta("ff_wrestlers", PackedStringArray())
		assert_array(Array(tagged)).override_failure_message(m) \
				.contains_exactly_in_any_order(FFMoveLibrary.wrestlers_of(m))
		assert_int(def.total_frames()).is_greater(0)


func test_a_shared_move_is_one_move_tagged_to_each_user() -> void:
	assert_array(FFMoveLibrary.wrestlers_of("spinebuster_5")) \
			.contains_exactly_in_any_order(["cash_wheeler", "jade_cargill", "powerhouse_hobbs"])
	assert_array(FFMoveLibrary.wrestlers_of("superkick_5")) \
			.contains_exactly_in_any_order(["aubrey_edwards", "nick_jackson"])


func test_cody_and_kenny_have_their_video_movesets() -> void:
	assert_array(FFMoveLibrary.moves_of("cody_rhodes")).contains_exactly(
			["cody_cutter_4", "figure_four_leglock", "tiger_driver_98", "cross_rhodes"])
	assert_array(FFMoveLibrary.moves_of("kenny_omega")).contains_exactly(
			["running_v_trigger_3", "powerbomb_v_trigger_combo", "snap_dragon_suplex_3",
			"snap_dragon_suplex_2", "running_v_trigger_1", "v_trigger_1", "one_winged_angel"])


func test_the_moves_we_already_animate_are_built() -> void:
	assert_bool(FFMoveLibrary.is_built("cross_rhodes")).is_true()
	assert_bool(FFMoveLibrary.is_built("figure_four_leglock")).is_true()
	var p := FFMoveLibrary.progress()
	assert_int(p.y).is_equal(FFMoveLibrary.MOVES.size())
	print("FF library built: %d / %d" % [p.x, p.y])
