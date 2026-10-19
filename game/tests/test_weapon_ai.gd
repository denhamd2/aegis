extends GdUnitTestSuite
## The AI and weapons (No Holds Barred only): what he pulls out, that he goes
## for one only in No Holds Barred, that under the ring he hands the wheel a
## weapon in stock, and that with a table behind the other man he lines him
## up and charges. A whole seeded match is tools/probe/nhb_weapon_probe.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func _pair(nhb: bool) -> Array[WrestlerController]:
	var out: Array[WrestlerController] = []
	for i in 2:
		var w: WrestlerController = WRESTLER_SCENE.instantiate()
		w.player_index = i
		w.display_name = "ROMAN REIGNS" if i == 0 else "CODY RHODES"
		if nhb:
			MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
		auto_free(w)
		add_child(w)
		out.append(w)
	out[0].opponent = out[1]
	out[1].opponent = out[0]
	for w in out:
		w.is_ai = true
		w.ai.target = w.opponent
		w.ai.setup_jitter(5, w.player_index)
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
	return out


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func after_test() -> void:
	var stock := get_node_or_null("WeaponStock")
	if stock:
		stock.free()


func test_he_favours_his_own_weapons() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	var cody := pair[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var roman_own := 0
	var cody_own := 0
	var draws := 400
	for i in draws:
		if roman.ai._owns(WeaponCatalog.by_id(roman.ai.choose_weapon(rng))):
			roman_own += 1
		if cody.ai._owns(WeaponCatalog.by_id(cody.ai.choose_weapon(rng))):
			cody_own += 1
	# Wild-weapon weighting dilutes ownership, but each favourite still wins
	# more often than a flat 1-in-35 draw.
	assert_float(float(roman_own) / draws).is_greater(0.18)
	assert_float(float(cody_own) / draws).is_greater(0.04)


func test_the_same_seed_picks_the_same() -> void:
	var pair := _pair(true)
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 3
	b.seed = 3
	for i in 20:
		assert_str(String(pair[0].ai.choose_weapon(a))).is_equal(String(pair[0].ai.choose_weapon(b)))


func test_rocket_gun_and_bed_of_nails_are_regular_ai_picks() -> void:
	var pair := _pair(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 812
	var wild := 0
	for i in 200:
		if pair[0].ai.choose_weapon(rng) in WrestlerAI.WILD_WEAPONS:
			wild += 1
	assert_float(float(wild) / 200.0).is_greater(0.35)
	assert_int(WrestlerAI.WEAPON_RUNS).is_greater_equal(10)


func test_gun_and_rocket_launcher_are_open_from_the_bell() -> void:
	# the owner, 19 Oct: no late-match lock -- they can come out at any time
	var pair := _pair(true)
	var flow := MatchFlow.new()
	flow.name = "MatchFlow"
	add_child(flow)
	var stock := WeaponStock.of(pair[0])
	flow.tick = 0
	assert_bool(stock.in_stock(&"handgun")).is_true()
	assert_bool(stock.in_stock(&"rpg")).is_true()
	var rng := RandomNumberGenerator.new()
	var early_picks := {}
	for i in 200:
		rng.seed = i + 1
		early_picks[pair[0].ai.choose_weapon(rng)] = true
	assert_bool(early_picks.has(&"handgun")).is_true()
	assert_bool(early_picks.has(&"rpg")).is_true()


func test_tables_are_a_common_pick_for_both_wrestlers() -> void:
	var pair := _pair(true)
	var counts := [0, 0]
	for i in 200:
		for wrestler_index in 2:
			var rng := RandomNumberGenerator.new()
			rng.seed = 31000 + i * 2 + wrestler_index
			if pair[wrestler_index].ai.choose_weapon(rng) == &"table":
				counts[wrestler_index] += 1
	# Roman has a researched table preference; table should still be a regular
	# option for Cody rather than an accidental once-in-a-match draw.
	assert_float(float(counts[0]) / 200.0).is_greater(0.25)
	assert_float(float(counts[1]) / 200.0).is_greater(0.10)


func test_never_in_a_singles_match() -> void:
	var pair := _pair(false)
	var ai := pair[0].ai
	ai._weapon_roll = 0
	pair[0].combat.tier_reached = 0
	for i in 50:
		ai._circle_tick = i
		assert_bool(ai._weapon_input({}, Vector3(0, 0, -2), 2.0).is_empty()).is_true()
	assert_int(ai.weapon_runs_started).is_equal(0)


func test_in_no_holds_barred_he_goes_out_for_one() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	roman.combat.tier_reached = 0
	roman.global_position = Vector3(1.5, 0.0, 0.0)
	pair[1].global_position = Vector3(-1.0, 0.0, 0.0)
	await _ticks(2)
	var started := false
	roman.is_ai = false                  # held still: only the plan is under test
	roman.fsm.transition_to(WrestlerFSM.State.IDLE)
	for i in 400:
		roman.ai._weapon_roll = 0
		roman.ai._circle_tick = i
		var input: Dictionary = roman.ai._weapon_input({}, Vector3(-2.5, 0, 0), 2.5)
		if roman.ai._weapon_plan == WrestlerAI.WeaponPlan.FETCH:
			started = true
			# inside: to the ropes nearest him, and through them
			assert_bool(input.get("rope_cross", false)).is_true()
			assert_float((input["move"] as Vector2).x).is_greater(0.0)
			break
	assert_bool(started).is_true()


func test_outside_weapon_approach_routes_around_the_ring() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	var cody := pair[1]
	roman.outside_ring = true
	cody.outside_ring = true
	# Opponents on opposite sides have the deck between them. Each should
	# start around the southern (steps-free) side instead of pushing at the
	# ring through the apron.
	roman.global_position = Vector3(5.0, 0.0, 0.0)
	cody.global_position = Vector3(-5.0, 0.0, 0.0)
	var roman_move := roman.ai._outside_opponent_move(cody.global_position)
	var cody_move := cody.ai._outside_opponent_move(roman.global_position)
	assert_float(roman_move.y).is_greater(0.1)
	assert_float(cody_move.y).is_greater(0.1)
	assert_float(roman_move.length()).is_equal_approx(1.0, 0.001)
	assert_float(cody_move.length()).is_equal_approx(1.0, 0.001)


func test_both_outside_ai_close_the_gap_instead_of_walking_into_the_ring() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	var cody := pair[1]
	roman.outside_ring = true
	cody.outside_ring = true
	roman.global_position = Vector3(5.0, WrestlerController.FLOOR_LEVEL, 0.0)
	cody.global_position = Vector3(-5.0, WrestlerController.FLOOR_LEVEL, 0.0)
	# Suppress discretionary weapon runs so this exercises the ordinary chase.
	roman.ai._weapon_runs = WrestlerAI.WEAPON_RUNS
	cody.ai._weapon_runs = WrestlerAI.WEAPON_RUNS
	var roman_input: Dictionary = roman.ai._poll_input()
	var cody_input: Dictionary = cody.ai._poll_input()
	var roman_move: Vector2 = roman_input["move"]
	var cody_move: Vector2 = cody_input["move"]
	# Both route around the deck, rather than sending opposite movement into it.
	assert_float(absf(roman_move.y)).is_greater(0.1)
	assert_float(absf(cody_move.y)).is_greater(0.1)
	assert_float(roman_move.length()).is_equal_approx(1.0, 0.001)
	assert_float(cody_move.length()).is_equal_approx(1.0, 0.001)


func test_outside_route_waypoint_clears_the_entrance_steps() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	var cody := pair[1]
	roman.outside_ring = true
	cody.outside_ring = true
	# A wrestler pushed against the (+X, -Z) steps first needs to clear their
	# expanded collision footprint; following the tangent route kept him pinned.
	roman.global_position = Vector3(5.2, WrestlerController.FLOOR_LEVEL, -4.2)
	cody.global_position = Vector3(-5.2, WrestlerController.FLOOR_LEVEL, -4.2)
	var move := roman.ai._outside_opponent_move(cody.global_position)
	assert_float(move.x).is_greater(0.7)
	assert_float(move.y).is_less(-0.1)
	assert_float(WrestlerAI.OUTSIDE_ROUTE_RADIUS).is_greater(5.0)


func test_same_side_ringside_ai_moves_directly_towards_opponent() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	var cody := pair[1]
	roman.outside_ring = true
	cody.outside_ring = true
	roman.global_position = Vector3(5.0, WrestlerController.FLOOR_LEVEL, -1.25)
	cody.global_position = Vector3(5.0, WrestlerController.FLOOR_LEVEL, 1.25)
	roman.ai._weapon_runs = WrestlerAI.WEAPON_RUNS
	var input: Dictionary = roman.ai._poll_input()
	var move: Vector2 = input["move"]
	assert_float(absf(move.x)).is_less(0.1)
	assert_float(move.y).is_greater(0.9)


func test_an_outside_ai_chooses_a_loose_stage_weapon_and_heads_up_the_ramp() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	roman.outside_ring = true
	roman.global_position = Vector3(0.0, WrestlerController.FLOOR_LEVEL, -8.0)
	var stock := WeaponStock.of(roman)
	var stage_weapon := stock.pull(WeaponCatalog.by_id(&"barbed_wire_bat"))
	stage_weapon.mode = WeaponActor.Mode.FLOOR
	stage_weapon.global_position = Vector3(0.0, ArenaBuilder.STAGE_DECK_Y, -32.0)
	stock.stage_actors.append(stage_weapon)
	roman.ai._weapon_plan = WrestlerAI.WeaponPlan.FETCH
	roman.ai._fetch_from_stage = true      # this run is for the stage's layout
	var input := roman.ai._weapon_input({}, Vector3.BACK, 24.0)
	assert_bool(input.has("move")).is_true()
	assert_float((input["move"] as Vector2).y).is_less(0.0)


func test_under_the_ring_he_hands_the_wheel_a_weapon_in_stock() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	var input := roman.ai._rummage_input()
	assert_bool(input["weapon"]).is_true()
	var id: StringName = input["weapon_pick"]
	assert_object(WeaponCatalog.by_id(id)).is_not_null()
	assert_bool(WeaponStock.of(roman).in_stock(id)).is_true()


func test_with_a_table_at_his_back_he_locks_up_for_the_suplex() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	var cody := pair[1]
	roman.combat.tier_reached = 0
	# the bare test wrestler carries no move pools: Roman's suplex
	roman.grapple_move_pool.append(load("res://resources/moves/grapple_vertical_suplex.tres"))
	cody.global_position = Vector3(0.0, 0.0, -1.0)
	roman.global_position = Vector3(1.4, 0.0, 1.0)
	await _ticks(2)
	var table := WeaponStock.of(cody).pull(WeaponCatalog.by_id(&"table"))
	table.set_up_at(Vector3(0.0, 0.0, 1.3), 0.0)
	var to := cody.global_position - roman.global_position
	var input: Dictionary = roman.ai._line_up_input({}, Vector3(to.x, 0, to.z), Vector2(to.x, to.z).length())
	# off the spot: he moves to it, and does not lock up yet
	assert_bool(input.has("move")).is_true()
	assert_bool(input.get("grapple", false)).is_false()
	# on it -- the table 1.3 m at his back, Cody in front in reach
	roman.global_position = Vector3(0.0, 0.0, 0.0)
	to = cody.global_position - roman.global_position
	input = roman.ai._line_up_input({}, Vector3(to.x, 0, to.z), Vector2(to.x, to.z).length())
	assert_bool(input.get("grapple", false)).is_true()
	assert_object(roman.prefer_hold_move).is_not_null()
	assert_str(String(roman.prefer_hold_move.animation_pair_id)).contains("vertical_suplex")
	# and the hold he wins throws it
	assert_object(roman._pick_hold_move()).is_same(roman.ai._suplex())
	assert_object(roman.prefer_hold_move).is_null()


func test_tacks_and_barbed_wire_board_are_paired_ai_spots_too() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	var cody := pair[1]
	roman.combat.tier_reached = 0
	roman.grapple_move_pool.append(load("res://resources/moves/grapple_vertical_suplex.tres"))
	cody.global_position = Vector3(0.0, 0.0, -1.0)
	roman.global_position = Vector3(0.0, 0.0, 0.0)
	await _ticks(2)
	cody.global_position = Vector3(0.0, 0.0, -1.0)
	roman.global_position = Vector3(0.0, 0.0, 0.0)
	for id: StringName in [&"thumbtacks", &"bed_of_nails", &"barbed_wire_board"]:
		var piece := WeaponStock.of(cody).pull(WeaponCatalog.by_id(id))
		piece.set_up_at(Vector3(0.0, 0.0, 1.3), 0.0)
		var to := cody.global_position - roman.global_position
		var input: Dictionary = roman.ai._line_up_input({}, to, Vector2(to.x, to.z).length())
		assert_bool(input.get("grapple", false)).override_failure_message(
				"AI should line up a suplex onto %s" % id).is_true()
		assert_object(roman.prefer_hold_move).is_same(roman.ai._suplex())
		roman.prefer_hold_move = null
		piece.queue_free()


func test_a_laid_out_ladder_selects_the_ladder_slam_pair() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	var cody := pair[1]
	roman.combat.tier_reached = 0
	roman.grapple_move_pool.append(load("res://resources/moves/grapple_vertical_suplex.tres"))
	cody.global_position = Vector3(0.0, 0.0, -1.0)
	roman.global_position = Vector3(0.0, 0.0, 0.0)
	await _ticks(2)
	cody.global_position = Vector3(0.0, 0.0, -1.0)
	roman.global_position = Vector3(0.0, 0.0, 0.0)
	var ladder := WeaponStock.of(cody).pull(WeaponCatalog.by_id(&"ladder"))
	ladder.set_up_at(Vector3(0.0, 0.0, 1.3), 0.0)
	assert_int(ladder.mode).is_equal(WeaponActor.Mode.SET_UP)
	assert_bool(ladder.def.set_piece).is_true()
	assert_int(WeaponStock.of(roman).set_up_pieces().size()).is_equal(1)
	var to := cody.global_position - roman.global_position
	var input: Dictionary = roman.ai._line_up_input({}, to, Vector2(to.x, to.z).length())
	assert_bool(input.get("grapple", false)).is_true()
	assert_object(roman.prefer_hold_move).is_same(
			load("res://resources/moves/weapon_ladder_slam.tres"))


func test_a_weapon_fetched_outside_is_often_taken_back_into_the_ring() -> void:
	# the owner, 19 Oct: more of No Holds Barred in the ring
	var pair := _pair(true)
	var roman := pair[0]
	roman.outside_ring = true
	roman.global_position = Vector3(WrestlerController.DECK_KEEP_OUT + 0.6, WrestlerController.FLOOR_LEVEL, 0.5)
	pair[1].outside_ring = true
	pair[1].global_position = Vector3(WrestlerController.DECK_KEEP_OUT + 0.6, WrestlerController.FLOOR_LEVEL, 3.0)
	await _ticks(2)
	var in_ring := 0
	for i in 100:
		roman.ai._circle_tick = i * 7
		roman.ai._start_use()
		if roman.ai._use_in_ring:
			in_ring += 1
	assert_int(in_ring).is_between(50, 80)
	# and heading in, he walks to the ropes on his side and goes through
	roman.ai._use_in_ring = true
	roman.ai._slide_in = false
	var weapon := WeaponStock.of(roman).pull(WeaponCatalog.by_id(&"steel_chair"))
	roman.take_weapon(weapon)
	roman.ai._weapon_plan = WrestlerAI.WeaponPlan.USE
	var input := roman.ai._weapon_input({}, Vector3(0, 0, 2.5), 2.5)
	assert_float((input["move"] as Vector2).x).is_less(0.0)
	assert_bool(input.get("rope_cross", false)).is_true()


func test_both_out_too_long_he_takes_the_fight_back_in() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	for w in pair:
		w.outside_ring = true
	roman.global_position = Vector3(WrestlerController.DECK_KEEP_OUT + 0.4, WrestlerController.FLOOR_LEVEL, 0.5)
	pair[1].global_position = Vector3(WrestlerController.DECK_KEEP_OUT + 0.6, WrestlerController.FLOOR_LEVEL, 2.5)
	roman.ai._outside_ticks = WrestlerAI.OUTSIDE_SPELL.y
	assert_bool(roman.ai._back_in_the_ring_now()).is_true()
	roman.ai._outside_ticks = 0
	assert_bool(roman.ai._back_in_the_ring_now()).is_true()      # latched till he is in
