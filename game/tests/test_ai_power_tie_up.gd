extends GdUnitTestSuite
## The AI's middle-of-the-match lock-up: once, inside the power band, to
## throw the body slam -- see WrestlerAI._wants_power_tie_up().

func _make_pair() -> WrestlerAI:
	var ai: WrestlerAI = auto_free(WrestlerAI.new())
	var me: WrestlerController = auto_free(WrestlerController.new())
	var them: WrestlerController = auto_free(WrestlerController.new())
	for w: WrestlerController in [me, them]:
		w.fsm = auto_free(WrestlerFSM.new())
		w.combat = CombatSystem.new()
	me.power_move = load("res://resources/moves/power_bodyslam.tres")
	me.opponent = them
	them.opponent = me
	ai.controller = me
	ai.target = them
	# He won the opening lock-up and landed the grapple, which is what
	# CombatSystem.can_power() asks for: the slam is the winner's to earn.
	me.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	return ai

func test_it_locks_up_for_the_power_move_inside_the_band() -> void:
	var ai := _make_pair()
	ai.controller.combat.momentum = CombatSystem.POWER_THRESHOLD + 1.0
	assert_bool(ai._wants_power_tie_up()).is_true()
	assert_bool(ai._wants_tie_up()).is_true()

func test_not_below_the_band() -> void:
	var ai := _make_pair()
	ai.controller.combat.momentum = CombatSystem.POWER_THRESHOLD - 1.0
	assert_bool(ai._wants_power_tie_up()).is_false()

## Past the signature threshold the hold would draw a signature, in the
## middle of the match.
func test_not_once_a_signature_is_affordable() -> void:
	var ai := _make_pair()
	ai.controller.combat.momentum = CombatSystem.SIGNATURE_THRESHOLD
	assert_bool(ai._wants_power_tie_up()).is_false()

func test_not_before_the_opening_grapple() -> void:
	var ai := _make_pair()
	ai.controller.combat.tier_reached = -1
	ai.controller.combat.momentum = CombatSystem.POWER_THRESHOLD + 1.0
	assert_bool(ai._wants_power_tie_up()).is_false()

func test_not_after_landing_one() -> void:
	var ai := _make_pair()
	ai.controller.combat.momentum = CombatSystem.POWER_THRESHOLD + 1.0
	ai.controller.combat.record_tier(CombatSystem.Tier.POWER)
	assert_bool(ai._wants_power_tie_up()).is_false()

## One try, won or lost.
func test_only_one_attempt_a_match() -> void:
	var ai := _make_pair()
	ai.controller.combat.momentum = CombatSystem.POWER_THRESHOLD + 1.0
	ai._power_attempt_spent = true
	assert_bool(ai._wants_power_tie_up()).is_false()

func test_not_without_a_power_move() -> void:
	var ai := _make_pair()
	ai.controller.power_move = null
	ai.controller.combat.momentum = CombatSystem.POWER_THRESHOLD + 1.0
	assert_bool(ai._wants_power_tie_up()).is_false()

## The man who lost the opening lock-up has no rung on the record, so the
## power move is not his to reach for -- he strikes.
func test_not_for_the_man_who_lost_the_opening_lock_up() -> void:
	var ai := _make_pair()
	ai.controller.combat.tier_reached = -1
	ai.target.combat.record_tier(CombatSystem.Tier.GRAPPLE)
	ai.controller.combat.momentum = CombatSystem.POWER_THRESHOLD + 1.0
	assert_bool(ai._wants_power_tie_up()).is_false()
