extends GdUnitTestSuite
## The shape of a match (MatchFlow, CombatSystem's recoverable wear, Persona):
## the heel in control, the face selling then hoping, finishers that cannot end
## it before the story gets there -- and a man getting his breath back.

const MATCH := "res://scenes/match.tscn"


func test_roman_is_the_heel_and_cody_the_face() -> void:
	assert_int(Persona.of("ROMAN REIGNS")).is_equal(Persona.Kind.HEEL)
	assert_int(Persona.of("Cody Rhodes")).is_equal(Persona.Kind.FACE)
	assert_int(Persona.of("WRESTLERA")).is_equal(Persona.Kind.NEUTRAL)
	assert_float(Persona.favor("ROMAN REIGNS")).is_less(0.0)
	assert_float(Persona.favor("CODY RHODES")).is_greater(0.0)


func test_the_phases_run_in_the_order_of_the_story() -> void:
	var order := []
	for clock in range(0, 600, 5):
		var name := String(MatchFlow.phase_at(float(clock))["name"])
		if order.is_empty() or order[-1] != name:
			order.append(name)
	assert_array(order).is_equal(
			["feeling_out", "heat", "hope", "cutoff", "comeback", "finish"])


func test_in_the_heat_the_heel_is_barely_marked_and_the_face_takes_it() -> void:
	var heat := MatchFlow.phase_at(100.0)
	var heel: Dictionary = MatchFlow.row(heat, Persona.Kind.HEEL)
	var face: Dictionary = MatchFlow.row(heat, Persona.Kind.FACE)
	assert_float(face["takes"]).is_greater(heel["takes"] * 3.0)
	# The man being worked over rarely answers; the heel works at his own pace.
	assert_float(face["tempo"]).is_greater(heel["tempo"] * 1.8)


func test_the_face_has_his_hope_spot_and_his_comeback() -> void:
	for clock: float in [225.0, 350.0]:
		var p := MatchFlow.phase_at(clock)
		var heel: Dictionary = MatchFlow.row(p, Persona.Kind.HEEL)
		var face: Dictionary = MatchFlow.row(p, Persona.Kind.FACE)
		assert_float(face["takes"]).override_failure_message("at %.0f s" % clock) \
				.is_less(heel["takes"])
		assert_float(face["tempo"]).is_less(heel["tempo"])


func test_a_finisher_cannot_end_the_match_before_the_story_gets_there() -> void:
	var scene: Node = load(MATCH).instantiate()
	add_child(scene)
	auto_free(scene)
	var flow := scene.get_node("MatchFlow") as MatchFlow
	assert_object(flow).is_not_null()
	assert_bool(flow.finish_allowed()).is_false()
	flow.tick = int(MatchFlow.FINISH_FROM * 60.0)
	assert_bool(flow.finish_allowed()).is_true()
	# Both men carry the flow, and it sets what they take.
	for path in ["WrestlerA", "WrestlerB"]:
		var w: WrestlerController = scene.get_node(path)
		assert_object(w.flow).is_same(flow)


func test_the_referee_only_opens_the_finisher_window_when_it_is_allowed() -> void:
	var scene: Node = load(MATCH).instantiate()
	add_child(scene)
	auto_free(scene)
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var flow := scene.get_node("MatchFlow") as MatchFlow
	var finisher := load("res://resources/moves/finisher_spear.tres") as MoveDef
	a.finisher_move = finisher
	referee._on_move_landed(a, b, finisher)
	assert_bool(referee.can_be_finished(b)).override_failure_message(
			"a finisher at the bell ended the match").is_false()
	flow.tick = int(MatchFlow.FINISH_FROM * 60.0)
	referee._on_move_landed(a, b, finisher)
	assert_bool(referee.can_be_finished(b)).is_true()


# --- vitality ----------------------------------------------------------------

func _hit(c: CombatSystem, amount: float) -> void:
	var m := MoveDef.new()
	m.damage_torso = amount
	c.apply_damage(m)


func test_the_beaten_man_gets_his_breath_back_but_not_all_of_it() -> void:
	var c := CombatSystem.new()
	_hit(c, 40.0)
	var worn := c.wear
	# Nothing heals while he is being hit, or just after.
	for _i in CombatSystem.GREEN_DELAY - 1:
		c.tick_recovery()
	assert_float(c.wear).is_equal(worn)
	for _i in 6000:
		c.tick_recovery()
	assert_float(c.wear).is_less(worn)
	# The red stays: the green share heals, no more.
	assert_float(c.wear).is_equal_approx(worn * (1.0 - CombatSystem.GREEN_SHARE), 0.01)
	assert_float(c.red()).is_equal_approx(c.wear, 0.01)
	# The limbs heal with it.
	assert_float(c.total_damage()).is_equal_approx(c.wear, 0.01)


func test_a_new_hit_stops_the_healing_and_a_knockdown_is_not_undone() -> void:
	var c := CombatSystem.new()
	_hit(c, 30.0)
	for _i in CombatSystem.GREEN_DELAY + 100:
		c.tick_recovery()
	var healing := c.wear
	_hit(c, 5.0)
	var after_hit := c.wear
	c.tick_recovery()
	assert_float(c.wear).is_equal(after_hit)
	assert_float(healing).is_less(30.0)
	# Knocked down at this wear: it cannot be healed below.
	c.heal_floor = c.wear
	c.green = 0.0
	for _i in 6000:
		c.tick_recovery()
	assert_float(c.wear).is_equal_approx(after_hit, 0.001)


func test_damage_scale_shrinks_what_a_man_takes() -> void:
	var c := CombatSystem.new()
	c.damage_taken_scale = 0.25
	_hit(c, 40.0)
	assert_float(c.wear).is_equal_approx(10.0, 0.001)


func test_a_finisher_spends_the_meter_and_rests_for_a_long_while() -> void:
	var c := CombatSystem.new()
	c.momentum = 100.0
	c.tier_reached = CombatSystem.Tier.SIGNATURE
	assert_bool(c.can_finisher()).is_true()
	c.spend_finisher()
	assert_float(c.momentum).is_equal(0.0)
	c.momentum = 100.0
	assert_bool(c.can_finisher()).override_failure_message("a second finisher at once").is_false()
	assert_bool(c.finisher_resting()).is_true()
	for _i in CombatSystem.FINISHER_REST:
		c.tick_recovery()
	assert_bool(c.can_finisher()).is_true()


func test_the_ai_is_held_off_the_big_moves_its_phase_does_not_give_it() -> void:
	var scene: Node = load(MATCH).instantiate()
	add_child(scene)
	auto_free(scene)
	var flow := scene.get_node("MatchFlow") as MatchFlow
	var a: WrestlerController = scene.get_node("WrestlerA")
	a.is_ai = true
	a.combat.momentum = 100.0
	a.combat.tier_reached = CombatSystem.Tier.SIGNATURE
	flow.tick = 10 * 60
	flow._apply()
	assert_bool(a.combat.can_signature()).override_failure_message("a signature in the first minute").is_false()
	assert_bool(a.combat.can_finisher()).is_false()
	# A human is never held back from a move he has earned.
	a.is_ai = false
	flow._apply()
	assert_bool(a.combat.can_signature()).is_true()


func test_he_has_one_kickout_in_him_when_the_finish_comes() -> void:
	var flow := MatchFlow.new()
	auto_free(flow)
	assert_bool(flow.no_kickout_left()).is_false()
	flow.finisher_kickouts = MatchFlow.FINISHER_KICKOUTS_MAX
	assert_bool(flow.no_kickout_left()).is_true()


func test_the_story_has_a_winner_picked_by_the_seed_and_both_men_win_sometimes() -> void:
	var a: WrestlerController = auto_free(WrestlerController.new())
	var b: WrestlerController = auto_free(WrestlerController.new())
	var wins := {a: 0, b: 0}
	for seed_value in range(1, 41):
		var w := MatchFlow.pick_winner([a, b], seed_value)
		wins[w] += 1
		# The same seed tells the same story.
		assert_object(MatchFlow.pick_winner([a, b], seed_value)).is_same(w)
	assert_int(wins[a]).is_between(10, 30)
	assert_int(wins[b]).is_between(10, 30)


func test_in_the_finish_the_winner_is_barely_marked_and_the_loser_is_not() -> void:
	var scene: Node = load(MATCH).instantiate()
	add_child(scene)
	auto_free(scene)
	var flow := scene.get_node("MatchFlow") as MatchFlow
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.is_ai = true
	b.is_ai = true
	flow.tick = int((MatchFlow.FINISH_FROM + 10.0) * 60.0)
	var win: WrestlerController = flow.winner
	var lose: WrestlerController = b if win == a else a
	assert_float(flow.damage_taken_scale(lose)).is_greater(flow.damage_taken_scale(win) * 2.0)
	assert_str(flow.rung(win)).is_equal("finisher")
	assert_str(flow.rung(lose)).is_equal("none")
