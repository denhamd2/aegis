extends GdUnitTestSuite
## WrestlerController._process_grapple_hold()'s momentum-gated move tier
## ladder (grapple_move -> power_move -> signature_move -> finisher_move).
## No test previously covered this at all, not even the pre-existing
## signature/finisher split -- this is new coverage added alongside the new
## power_move rung (see combat_system.gd's POWER_THRESHOLD/can_power()).

func _make_move(id: StringName) -> MoveDef:
	var move := MoveDef.new()
	move.animation_pair_id = id
	return move

func _make_grappling_pair() -> Array:
	var attacker: WrestlerController = auto_free(WrestlerController.new())
	var defender: WrestlerController = auto_free(WrestlerController.new())
	for w in [attacker, defender]:
		w.fsm = auto_free(WrestlerFSM.new())
		w.combat = CombatSystem.new()
	attacker.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	defender.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	attacker.opponent = defender
	attacker._is_grapple_attacker = true
	attacker.grapple_move = _make_move(&"grapple")
	attacker.power_move = _make_move(&"power")
	attacker.signature_move = _make_move(&"signature")
	attacker.finisher_move = _make_move(&"finisher")
	return [attacker, defender]

func _selected_move_id(attacker: WrestlerController, defender: WrestlerController, momentum: float) -> StringName:
	attacker.combat.momentum = momentum
	attacker._process_grapple_hold({})
	# _active_move is set before GrappleRig dispatch/resolution and (with no
	# grapple_rig assigned here, so the synchronous else-branch runs) is left
	# holding the selected move afterward -- simpler and less fragile than
	# capturing move_landed through a lambda closure.
	var id: StringName = attacker._active_move.animation_pair_id
	# Reset back to GRAPPLE_HOLD for the next call in the same test.
	attacker.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	defender.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	return id

func test_below_power_threshold_selects_base_grapple() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.POWER_THRESHOLD - 1.0)
	assert_str(id).is_equal(&"grapple")

func test_at_power_threshold_selects_power_move() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.POWER_THRESHOLD)
	assert_str(id).is_equal(&"power")

func test_at_signature_threshold_selects_signature_move() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.SIGNATURE_THRESHOLD)
	assert_str(id).is_equal(&"signature")

func test_at_finisher_threshold_selects_finisher_move() -> void:
	var pair := _make_grappling_pair()
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.FINISHER_THRESHOLD)
	assert_str(id).is_equal(&"finisher")

func test_missing_power_move_falls_back_to_base_grapple() -> void:
	var pair := _make_grappling_pair()
	pair[0].power_move = null
	var id := _selected_move_id(pair[0], pair[1], CombatSystem.POWER_THRESHOLD)
	assert_str(id).is_equal(&"grapple")
