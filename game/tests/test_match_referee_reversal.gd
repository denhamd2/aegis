extends GdUnitTestSuite
## MatchReferee._check_for_reversal() -- consumes MoveDef.reversal_window_
## start/end and the previously-unread "reversal" input for the first time.
## Deferred to the referee (runs after both wrestlers' own
## _physics_process for the tick) for the same scene-order reason as
## tie-up entry and pending-hit resolution: the outcome depends on reading
## the *opponent's* same-tick state.

func _make_referee_with_pair() -> Array:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	var wrestler_a: WrestlerController = auto_free(WrestlerController.new())
	var wrestler_b: WrestlerController = auto_free(WrestlerController.new())
	for w in [wrestler_a, wrestler_b]:
		# CharacterBody3D defers global_position to the physics server, which
		# only exists once the node is inside a SceneTree -- outside the
		# tree, global_position writes silently no-op. add_child() here (in
		# addition to auto_free() above, which still handles cleanup) is
		# required for the range check in test_does_not_reverse_out_of_range
		# to mean anything.
		add_child(w)
		w.fsm = auto_free(WrestlerFSM.new())
		w.combat = CombatSystem.new()
		w.global_position = Vector3.ZERO
	referee.wrestler_a = wrestler_a
	referee.wrestler_b = wrestler_b
	return [referee, wrestler_a, wrestler_b]

func _make_move() -> MoveDef:
	var move := MoveDef.new()
	move.startup_frames = 14
	move.active_frames = 5
	move.recovery_frames = 16
	move.reversal_window_start = 7
	move.reversal_window_end = 12
	move.momentum_gain = 10.0
	return move

## Sets attacker up mid-move at a given frame_offset via
## _move_ticks_remaining (total_frames() - frame_offset).
func _put_in_running_attack(attacker: WrestlerController, move: MoveDef, frame_offset: int) -> void:
	attacker.fsm.current_state = WrestlerFSM.State.RUNNING_ATTACK
	attacker._active_move = move
	attacker._move_ticks_remaining = move.total_frames() - frame_offset

func test_reverses_inside_the_window() -> void:
	var setup := _make_referee_with_pair()
	var referee: MatchReferee = setup[0]
	var reverser: WrestlerController = setup[1]
	var attacker: WrestlerController = setup[2]
	var move := _make_move()
	_put_in_running_attack(attacker, move, 9) # inside [7, 12]
	reverser._wants_reversal_this_tick = true

	referee._check_for_reversal()

	assert_int(attacker.fsm.current_state).is_equal(WrestlerFSM.State.HIT_REACT)
	# _start_move(HIT_REACT, ...) overwrites _active_move with a timed stub
	# (same as _go_down()/_resolve_pending_hits() already do elsewhere) --
	# the reversed move itself is gone, not literally nulled.
	assert_object(attacker._active_move).is_not_same(move)
	assert_float(reverser.combat.momentum).is_equal(10.0)

func test_does_not_reverse_outside_the_window() -> void:
	var setup := _make_referee_with_pair()
	var referee: MatchReferee = setup[0]
	var reverser: WrestlerController = setup[1]
	var attacker: WrestlerController = setup[2]
	var move := _make_move()
	_put_in_running_attack(attacker, move, 2) # before the window
	reverser._wants_reversal_this_tick = true

	referee._check_for_reversal()

	assert_int(attacker.fsm.current_state).is_equal(WrestlerFSM.State.RUNNING_ATTACK)
	assert_object(attacker._active_move).is_same(move)
	assert_float(reverser.combat.momentum).is_equal(0.0)

func test_does_not_reverse_without_reversal_intent() -> void:
	var setup := _make_referee_with_pair()
	var referee: MatchReferee = setup[0]
	var reverser: WrestlerController = setup[1]
	var attacker: WrestlerController = setup[2]
	var move := _make_move()
	_put_in_running_attack(attacker, move, 9)
	reverser._wants_reversal_this_tick = false

	referee._check_for_reversal()

	assert_int(attacker.fsm.current_state).is_equal(WrestlerFSM.State.RUNNING_ATTACK)

func test_does_not_reverse_out_of_range() -> void:
	var setup := _make_referee_with_pair()
	var referee: MatchReferee = setup[0]
	var reverser: WrestlerController = setup[1]
	var attacker: WrestlerController = setup[2]
	var move := _make_move()
	_put_in_running_attack(attacker, move, 9)
	reverser._wants_reversal_this_tick = true
	attacker.global_position = Vector3(10.0, 0, 0)

	referee._check_for_reversal()

	assert_int(attacker.fsm.current_state).is_equal(WrestlerFSM.State.RUNNING_ATTACK)
