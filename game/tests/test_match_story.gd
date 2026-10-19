extends GdUnitTestSuite
## An AI match told in order (the owner, 19 Oct; gauntlet/refs/ff_ai_flow.md):
## each move in its place in the story and seen only as often as a match shows
## it (MovePlaybook), the man the phase is for leading the offence
## (MatchFlow.initiative), and a finisher that can be covered.

const MATCH := "res://scenes/match.tscn"
const M := "res://resources/moves/"


func _move(path: String) -> MoveDef:
	return load(M + path) as MoveDef


func test_every_move_has_a_place_and_the_big_ones_are_rare() -> void:
	assert_int(MovePlaybook.place_of(_move("strike_jab.tres"))).is_equal(MovePlaybook.Place.BASIC)
	assert_int(MovePlaybook.max_uses(_move("strike_jab.tres"))).is_equal(0)
	assert_int(MovePlaybook.place_of(_move("grapple_vertical_suplex.tres"))).is_equal(MovePlaybook.Place.BASIC)
	assert_int(MovePlaybook.max_uses(_move("grapple_vertical_suplex.tres"))).is_equal(3)
	assert_int(MovePlaybook.place_of(_move("power_samoan_drop.tres"))).is_equal(MovePlaybook.Place.MID)
	assert_int(MovePlaybook.place_of(_move("ff/powerbomb_1.tres"))).is_equal(MovePlaybook.Place.MID)
	assert_int(MovePlaybook.max_uses(_move("ff/powerbomb_1.tres"))).is_equal(1)
	assert_int(MovePlaybook.place_of(_move("ff/tiger_driver_98.tres"))).is_equal(MovePlaybook.Place.LATE)
	assert_int(MovePlaybook.max_uses(_move("ff/tiger_driver_98.tres"))).is_equal(1)
	# the finisher is never rationed: it is how the match ends
	assert_int(MovePlaybook.max_uses(_move("finisher_spear.tres"))).is_equal(0)


func test_the_story_opens_with_basics_and_saves_the_big_moves() -> void:
	assert_str(String(MatchFlow.phase_at(30.0)["name"])).is_equal("feeling_out")
	var scene: Node = auto_free(load(MATCH).instantiate())
	add_child(scene)
	var flow := scene.get_node("MatchFlow") as MatchFlow
	var a: WrestlerController = scene.get_node("WrestlerA")
	a.is_ai = true
	for case: Array in [[30.0, MovePlaybook.Place.BASIC], [120.0, MovePlaybook.Place.MID],
			[270.0, MovePlaybook.Place.MID], [430.0, MovePlaybook.Place.LATE]]:
		flow.tick = int(case[0] * 60.0)
		assert_int(flow.story_place(a)).override_failure_message(str(case[0])).is_equal(case[1])
	a.is_ai = false
	flow.tick = 0
	assert_int(flow.story_place(a)).is_equal(MovePlaybook.Place.LATE)   # a player picks freely


func test_an_ai_power_draw_holds_its_big_moves_and_spreads_the_rest() -> void:
	var scene: Node = auto_free(load(MATCH).instantiate())
	add_child(scene)
	var flow := scene.get_node("MatchFlow") as MatchFlow
	var a: WrestlerController = scene.get_node("WrestlerA")
	a.is_ai = true
	var pool: Array[MoveDef] = [_move("power_alabama_slam.tres"), _move("ff/tiger_driver_98.tres"),
			_move("ff/sit_out_powerbomb_2.tres")]
	var primary := _move("power_powerslam.tres")
	# The heat: the slams of the middle, never the stretch-run specials.
	flow.tick = 120 * 60
	var seen := {}
	for i in 12:
		var m := a._pick_tier_move(primary, pool)
		seen[String(m.animation_pair_id)] = int(seen.get(String(m.animation_pair_id), 0)) + 1
	assert_bool(seen.has("ff_tiger_driver_98")).is_false()
	assert_bool(seen.has("ff_sit_out_powerbomb_2")).is_false()
	assert_bool(seen.has("power_powerslam") and seen.has("power_alabama_slam")).is_true()
	# The finish: the specials come out, once each.
	flow.tick = 430 * 60
	var late := {}
	for i in 6:
		var m := a._pick_tier_move(primary, pool)
		late[String(m.animation_pair_id)] = int(late.get(String(m.animation_pair_id), 0)) + 1
	assert_int(int(late.get("ff_tiger_driver_98", 0))).is_equal(1)
	assert_int(int(late.get("ff_sit_out_powerbomb_2", 0))).is_equal(1)


func test_the_man_the_phase_is_for_leads_the_offence() -> void:
	var heat := MatchFlow.phase_at(120.0)
	assert_float(MatchFlow.row(heat, Persona.Kind.HEEL)["lead"]).is_greater(
			MatchFlow.row(heat, Persona.Kind.FACE)["lead"] * 2.0)
	for clock: float in [230.0, 350.0]:
		var p := MatchFlow.phase_at(clock)
		assert_float(MatchFlow.row(p, Persona.Kind.FACE)["lead"]).is_greater(
				MatchFlow.row(p, Persona.Kind.HEEL)["lead"] * 2.0)
	assert_float(MatchFlow.WINNER_ROW["lead"]).is_greater(MatchFlow.LOSER_ROW["lead"] * 2.0)
	# the finish starts when a finisher may end it, not before
	assert_str(String(MatchFlow.phase_at(MatchFlow.FINISH_FROM - 1.0)["name"])).is_not_equal("finish")
	assert_str(String(MatchFlow.phase_at(MatchFlow.FINISH_FROM + 1.0)["name"])).is_equal("finish")


func test_a_finisher_keeps_him_down_for_the_cover_and_a_jab_does_not() -> void:
	for case: Array in [[CombatSystem.Tier.FINISHER, true], [CombatSystem.Tier.GRAPPLE, false]]:
		var scene: Node = auto_free(load(MATCH).instantiate())
		add_child(scene)
		await get_tree().process_frame
		var b: WrestlerController = scene.get_node("WrestlerB")
		b._go_down(case[0])
		for i in WrestlerController.QUICK_DOWN_RECOVERY_DELAY_TICKS + 5:
			if b.fsm.current_state != WrestlerFSM.State.DOWN:
				break
			b._process_down({"strike": true})
			b.fsm.ticks_in_state += 1
		var still_down: bool = b.fsm.current_state == WrestlerFSM.State.DOWN
		assert_bool(still_down).override_failure_message("tier %d" % case[0]).is_equal(case[1])
		scene.queue_free()
		await get_tree().process_frame


func test_cody_has_more_than_the_suplex_to_lock_up_for() -> void:
	var cody := Roster.by_id("cody")
	assert_int((cody.moveset["grapple"] as Array).size()).is_greater_equal(4)
