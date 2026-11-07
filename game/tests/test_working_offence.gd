extends GdUnitTestSuite
## Exhausted power allowances must not funnel every later working hold into
## the basic suplex. Exercise accepted attempts and actual hold selection.

func test_spent_power_allowances_keep_a_legal_varied_working_fallback() -> void:
	var attacker: WrestlerController = auto_free(WrestlerController.new())
	var defender: WrestlerController = auto_free(WrestlerController.new())
	attacker.opponent = defender
	attacker.is_ai = true
	attacker.combat = CombatSystem.new()
	defender.combat = CombatSystem.new()
	attacker.combat.momentum = CombatSystem.MOMENTUM_MAX
	attacker.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	attacker.flow = auto_free(MatchFlow.new())
	attacker.flow.tick = 120 * 60
	attacker.grapple_move = load("res://resources/moves/grapple_vertical_suplex.tres")
	attacker.power_move = load("res://resources/moves/power_powerslam.tres")
	attacker.power_move_pool = [load("res://resources/moves/power_alabama_slam.tres")]
	for move: MoveDef in [attacker.power_move] + attacker.power_move_pool:
		for i in MovePlaybook.max_uses(move):
			attacker._record_move_attempt(move)
	var seen := {}
	for i in 10:
		attacker.tie_up_rung_cap = CombatSystem.Tier.POWER
		var move := attacker._pick_hold_move()
		assert_object(move).is_not_null()
		assert_int(MovePlaybook.place_of(move)).is_less_equal(MovePlaybook.Place.MID)
		seen[move.animation_pair_id] = true
		attacker._record_move_attempt(move)
	assert_int(seen.size()).is_equal(3)


func test_working_selection_respects_fatigue_and_body_part_damage() -> void:
	var attacker: WrestlerController = auto_free(WrestlerController.new())
	var defender: WrestlerController = auto_free(WrestlerController.new())
	attacker.opponent = defender
	attacker.is_ai = true
	attacker.combat = CombatSystem.new()
	defender.combat = CombatSystem.new()
	var head := MoveDef.new()
	head.animation_pair_id = &"head_work"
	head.damage_head = 10
	var legs := MoveDef.new()
	legs.animation_pair_id = &"leg_work"
	legs.damage_legs = 10
	defender.combat.limb_damage[CombatSystem.Limb.LEGS] = CombatSystem.MAX_LIMB_DAMAGE
	assert_float(attacker._offence_weight(legs)).is_greater(attacker._offence_weight(head))
	var slow := head.duplicate() as MoveDef
	slow.startup_frames = 160
	attacker.combat.stamina = 0.1
	assert_float(attacker._offence_weight(head)).is_greater(attacker._offence_weight(slow))
