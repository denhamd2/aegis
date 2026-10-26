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


## Batch 1 (19 Oct): five new paired moves and three of ours under their FF
## names, all built and all reachable by the men who should have them.
func test_batch_one_is_built() -> void:
	for m: String in ["powerbomb_1", "sit_out_powerbomb_2", "spinebuster_5", "brainbuster_1",
			"chokeslam_1", "spear_2", "cody_cutter_5", "scoop_slam_2"]:
		assert_bool(FFMoveLibrary.is_built(m)).override_failure_message(m).is_true()
	assert_int(FFMoveLibrary.progress().x).is_greater_equal(13)
	# the reused ones are ours, not a second copy of the move
	assert_str(FFMoveLibrary.move("spear_2").resource_path).is_equal("res://resources/moves/finisher_spear.tres")


## Batch 2 (26 Oct), Roman's fits: two new paired moves and our Samoan Drop
## under FF's name, each in the roster draw where he throws it.
func test_batch_two_is_built_and_romans() -> void:
	for m: String in ["oklahoma_stampede", "fireman_carry_bomb_2", "squatting_samoan_drop"]:
		assert_bool(FFMoveLibrary.is_built(m)).override_failure_message(m).is_true()
		assert_array(FFMoveLibrary.fits_of("roman")).contains([m])
	assert_str(FFMoveLibrary.move("squatting_samoan_drop").resource_path) \
			.is_equal("res://resources/moves/power_samoan_drop.tres")
	var roman := Roster.by_id("roman")
	assert_array(roman.moveset["power"]).contains(["res://resources/moves/ff/fireman_carry_bomb_2.tres"])
	assert_array(roman.moveset["rebound"]).contains(["res://resources/moves/ff/oklahoma_stampede.tres"])
	assert_int(FFMoveLibrary.progress().x).is_greater_equal(16)


## Batch 3 (26 Oct), Cody's fits: the Code Breaker in his signature draw and
## the Inverted DDT among his grapples.
func test_batch_three_is_built_and_codys() -> void:
	for m: String in ["code_breaker_1", "inverted_ddt_1"]:
		assert_bool(FFMoveLibrary.is_built(m)).override_failure_message(m).is_true()
		assert_array(FFMoveLibrary.fits_of("cody")).contains([m])
	var cody := Roster.by_id("cody")
	assert_array(cody.moveset["signature"]).contains(["res://resources/moves/ff/code_breaker_1.tres"])
	assert_array(cody.moveset["grapple"]).contains(["res://resources/moves/ff/inverted_ddt_1.tres"])
	assert_int(FFMoveLibrary.progress().x).is_greater_equal(18)


## Batch 4 (26 Oct): Roman's Buckle Bomb, in his corner draw beside the Spear.
func test_batch_four_is_built_and_romans() -> void:
	assert_bool(FFMoveLibrary.is_built("buckle_bomb")).is_true()
	assert_array(FFMoveLibrary.fits_of("roman")).contains(["buckle_bomb"])
	var roman := Roster.by_id("roman")
	assert_array(roman.moveset["corner"]).contains(["res://resources/moves/ff/buckle_bomb.tres"])
	assert_int(FFMoveLibrary.progress().x).is_greater_equal(19)


## Batch 5 (26 Oct): Roman's Casualty of War, in his running draw.
func test_batch_five_is_built_and_romans() -> void:
	assert_bool(FFMoveLibrary.is_built("casualty_of_war")).is_true()
	assert_array(FFMoveLibrary.fits_of("roman")).contains(["casualty_of_war"])
	var roman := Roster.by_id("roman")
	assert_array(roman.moveset["running"]).contains(["res://resources/moves/ff/casualty_of_war.tres"])
	assert_int(FFMoveLibrary.progress().x).is_greater_equal(20)


## Batch 6 (26 Oct): the Springboard Moonsault is Cody's -- the third ending
## of his dive spot, our own move under FF's name.
func test_batch_six_is_codys_dive() -> void:
	assert_bool(FFMoveLibrary.is_built("springboard_moonsault_3")).is_true()
	assert_str(FFMoveLibrary.EXISTING["springboard_moonsault_3"]).is_equal(DiveSpot.MOONSAULT_MOVE)
	var cody := Roster.by_id("cody")
	assert_array(cody.moveset["dive"]).contains([DiveSpot.MOONSAULT_MOVE])
	assert_int(FFMoveLibrary.progress().x).is_greater_equal(21)


## Kenny batch 1 (26 Oct): his V-Triggers, built and in his hands -- his own
## moveset now, not the shared draw.
func test_kenny_batch_one_is_built_and_his() -> void:
	var kenny := Roster.by_id("kenny")
	for m: String in ["running_v_trigger_1", "running_v_trigger_3", "v_trigger_1"]:
		assert_bool(FFMoveLibrary.is_built(m)).override_failure_message(m).is_true()
		assert_array(FFMoveLibrary.fits_of("kenny")).contains([m])
	assert_array(kenny.moveset["running"]).contains([
			"res://resources/moves/ff/running_v_trigger_1.tres",
			"res://resources/moves/ff/running_v_trigger_3.tres"])
	assert_array(kenny.moveset["signature"]).contains(["res://resources/moves/ff/v_trigger_1.tres"])
	assert_int(FFMoveLibrary.progress().x).is_greater_equal(24)


## A library move finds its hold (PairedContacts): filed as ff/<move>.tres,
## listed as ff_<move>. Until 26 Oct none did -- the lariat's arm was drawn
## onto the man -- and the contact pull stays off for them until they are
## refit with it.
func test_library_moves_find_their_contact_family() -> void:
	var ff := "res://resources/moves/ff/%s.tres"
	assert_str(PairedContacts.family(load(ff % "casualty_of_war"))).is_equal("none")
	assert_str(PairedContacts.family(load(ff % "oklahoma_stampede"))).is_equal("legs")
	assert_str(PairedContacts.family(load(ff % "inverted_ddt_1"))).is_equal("neck")
	assert_str(PairedContacts.family(load(ff % "buckle_bomb"))).is_equal("waist")
	assert_bool(PairedContacts.pulls(load(ff % "oklahoma_stampede"))).is_false()
	# Our own moves are untouched: looked up by file name, and pulled.
	var own: MoveDef = load("res://resources/moves/signature_neckbreaker.tres")
	assert_str(PairedContacts.family(own)).is_equal("neck")
	assert_bool(PairedContacts.pulls(own)).is_true()
	assert_bool(PairedContacts.pulls(load("res://resources/moves/signature_cody_cutter.tres"))).is_false()


## The owner asked for good fits for Cody and Roman to be tagged, built or
## not: every fit is a library move, and the built ones are in their hands.
func test_cody_and_roman_have_fits() -> void:
	for id: String in ["cody", "roman"]:
		var fits := FFMoveLibrary.fits_of(id)
		assert_int(fits.size()).is_greater_equal(8)
		for m: String in fits:
			assert_bool(FFMoveLibrary.MOVES.has(m)).override_failure_message(m).is_true()
	assert_array(FFMoveLibrary.fits_of("roman")).contains(["powerbomb_1", "spinebuster_5", "spear_2"])
	assert_array(FFMoveLibrary.fits_of("cody")).contains(["brainbuster_1", "sit_out_powerbomb_2", "cross_rhodes"])
	var roman := Roster.by_id("roman")
	assert_array(roman.moveset["power"]).contains(["res://resources/moves/ff/powerbomb_1.tres",
			"res://resources/moves/ff/spinebuster_5.tres"])
	var cody := Roster.by_id("cody")
	assert_array(cody.moveset["grapple"]).contains(["res://resources/moves/ff/brainbuster_1.tres"])
