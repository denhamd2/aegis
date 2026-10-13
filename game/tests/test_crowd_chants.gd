extends GdUnitTestSuite
## When the building chants (CrowdChants): every chant it can ask for is
## built, it waits for a reason, never talks over itself, rests between
## chants, does not repeat one too soon, drops a stale reason, and never
## chants a name that is not in the match.

const CHANTS := ["chant_cody", "chant_lets_go_cody", "chant_otc",
		"chant_this_is_awesome", "chant_you_deserve_it", "chant_one_more_match",
		"chant_holy_cow", "chant_tables", "chant_boring"]


func _chants(cody := true, roman := true, rung := true) -> CrowdChants:
	var c: CrowdChants = auto_free(CrowdChants.new())
	c.cody_here = cody
	c.roman_here = roman
	add_child(c)
	if rung:
		c.bell()
	return c


func _heard(c: CrowdChants) -> Array:
	var out := []
	c.chanted.connect(func(name): out.append(name))
	return out


func test_every_chant_and_shout_is_built() -> void:
	for chant: String in CHANTS:
		assert_int(SfxPool.family_size(chant)).override_failure_message("no " + chant) \
				.is_greater_equal(1)
	for shout: String in ["crowd_count_1", "crowd_count_2", "crowd_count_3", "crowd_whoa"]:
		assert_int(SfxPool.family_size(shout)).override_failure_message("no " + shout) \
				.is_greater_equal(2)


func test_nothing_is_chanted_without_a_reason() -> void:
	var c := _chants()
	var heard := _heard(c)
	for i in 600:
		c.tick(0.1, 0.5)
	assert_array(heard).is_empty()


func test_a_near_fall_late_in_a_match_is_awesome_and_early_is_holy_cow() -> void:
	var c := _chants()
	var heard := _heard(c)
	c.clock = 30.0
	c.kicked_out(2)
	c.tick(0.1, 0.6)
	assert_array(heard).contains_exactly(["chant_holy_cow"])
	var late := _chants()
	var heard_late := _heard(late)
	late.clock = CrowdChants.AWESOME_AFTER + 10.0      # since the bell at 0
	late.kicked_out(2)
	late.tick(0.1, 0.6)
	assert_array(heard_late).contains_exactly(["chant_this_is_awesome"])


func test_nothing_but_the_entrances_is_chanted_before_the_bell() -> void:
	var c := _chants(true, true, false)
	var heard := _heard(c)
	c.kicked_out(2)
	c.table_set_up()
	for i in CrowdChants.MOMENTUM_MOVES:
		c.moved(1.0, 0.9)
	for i in int(CrowdChants.STALL_AFTER + CrowdChants.STALL_SECONDS + 10.0):
		c.tick(1.0, 0.0)
	assert_array(heard).is_empty()


func test_a_near_fall_is_answered_even_straight_after_another_chant() -> void:
	var c := _chants()
	var heard := _heard(c)
	c.table_set_up()
	c.tick(0.1, 0.5)
	assert_array(heard).contains_exactly(["chant_tables"])
	# out the far side of the tables chant, well inside the rest after it
	for i in int(SfxPool.stream("chant_tables_0").get_length() * 10.0) + 20:
		c.tick(0.1, 0.5)
	c.kicked_out(2)
	c.tick(0.1, 0.5)
	assert_array(heard).contains_exactly(["chant_tables", "chant_holy_cow"])


func test_a_one_count_is_not_a_near_fall() -> void:
	var c := _chants()
	var heard := _heard(c)
	c.kicked_out(1)
	c.tick(0.1, 0.6)
	assert_array(heard).is_empty()


func test_one_chant_at_a_time_and_a_rest_between() -> void:
	assert_str(CrowdChants.pick({&"chant_cody": 10.0}, {}, 10.0, 99.0, true)).is_empty()
	assert_str(CrowdChants.pick({&"chant_cody": 10.0}, {}, 10.0,
			CrowdChants.MIN_GAP - 1.0, false)).is_empty()
	assert_str(CrowdChants.pick({&"chant_cody": 10.0}, {}, 10.0,
			CrowdChants.MIN_GAP, false)).is_equal("chant_cody")
	# a near-fall or a table does not wait out the rest -- but never talks over one
	assert_str(CrowdChants.pick({&"chant_tables": 10.0}, {}, 10.0, 1.0, false)).is_equal("chant_tables")
	assert_str(CrowdChants.pick({&"chant_tables": 10.0}, {}, 10.0, 1.0, true)).is_empty()


func test_the_same_chant_waits_and_a_stale_reason_is_dropped() -> void:
	var last := {&"chant_tables": 100.0}
	assert_str(CrowdChants.pick({&"chant_tables": 150.0}, last, 150.0, 99.0, false)).is_empty()
	assert_str(CrowdChants.pick({&"chant_tables": 150.0}, last,
			100.0 + CrowdChants.SAME_GAP + 1.0, 99.0, false)).is_empty()  # stale by then
	assert_str(CrowdChants.pick({&"chant_tables": 300.0}, last, 300.0, 99.0, false)) \
			.is_equal("chant_tables")


func test_the_freshest_reason_wins() -> void:
	var reasons := {&"chant_tables": 10.0, &"chant_holy_cow": 12.0}
	assert_str(CrowdChants.pick(reasons, {}, 12.5, 99.0, false)).is_equal("chant_holy_cow")


func test_a_run_of_moves_by_the_face_gets_his_name() -> void:
	var c := _chants()
	var heard := _heard(c)
	for i in CrowdChants.MOMENTUM_MOVES:
		c.moved(1.0, 0.2)
		c.tick(1.0, 0.5)
	assert_int(heard.size()).is_equal(1)
	assert_str(String(heard[0])).contains("cody")


func test_no_name_is_chanted_for_a_man_who_is_not_there() -> void:
	var c := _chants(false, false)
	var heard := _heard(c)
	for i in 3 * CrowdChants.MOMENTUM_MOVES:
		c.moved(1.0, 0.9)
		c.moved(-1.0, 0.9)
		c.tick(0.5, 0.5)
	assert_array(heard).is_empty()


func test_a_flat_room_gets_bored_but_not_in_the_opening_minute() -> void:
	var c := _chants()
	var heard := _heard(c)
	for i in int(CrowdChants.STALL_AFTER - 5.0):
		c.tick(1.0, 0.0)
	assert_array(heard).is_empty()
	for i in int(CrowdChants.STALL_SECONDS + 2.0):
		c.tick(1.0, 0.0)
	assert_array(heard).contains_exactly(["chant_boring"])
	# and only the once, however flat the rest of it is
	for i in 600:
		c.tick(1.0, 0.0)
	assert_array(heard).contains_exactly(["chant_boring"])


func test_the_face_winning_a_long_match_is_deserved_then_one_more() -> void:
	var c := _chants()
	var heard := _heard(c)
	c.clock = CrowdChants.ONE_MORE_AFTER + 5.0
	c.match_over(1.0)
	for i in 450:
		c.tick(0.1, 0.8)
	assert_array(heard).contains_exactly(["chant_you_deserve_it", "chant_one_more_match"])


func test_the_heel_winning_is_not_deserved() -> void:
	var c := _chants()
	var heard := _heard(c)
	c.clock = 60.0
	c.match_over(-1.0)
	for i in 250:
		c.tick(0.1, 0.8)
	assert_array(heard).is_empty()


func test_cody_entrance_sings_the_whoas_on_his_music() -> void:
	var c := _chants()
	var pool: SfxPool = auto_free(SfxPool.new())
	add_child(pool)
	c.sfx = pool
	var whoas := []
	pool.played.connect(func(s, _db): if s.begins_with("crowd_whoa"): whoas.append(s))
	c.entrance("cody")
	for i in 500:
		c.tick(0.1, 0.5)
	assert_int(whoas.size()).is_equal(CrowdChants.CODY_WHOAS.size())
