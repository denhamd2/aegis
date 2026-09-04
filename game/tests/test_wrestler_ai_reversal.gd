extends GdUnitTestSuite
## WrestlerAI._maybe_press_reversal(): reaction-delay-gated reversal
## attempts, same shape as the kickout/tie-up mash reaction delays. Only
## presses once the opponent's STRIKE/RUNNING_ATTACK has already been
## inside its own reversal window for more than reversal_reaction_ticks.

func _make_ai() -> WrestlerAI:
	var ai: WrestlerAI = auto_free(WrestlerAI.new())
	ai.controller = auto_free(WrestlerController.new())
	ai.target = auto_free(WrestlerController.new())
	ai.target.fsm = auto_free(WrestlerFSM.new())
	return ai

func _make_move() -> MoveDef:
	var move := MoveDef.new()
	move.startup_frames = 14
	move.active_frames = 5
	move.recovery_frames = 16
	move.reversal_window_start = 7
	move.reversal_window_end = 12
	return move

func _set_frame_offset(ai: WrestlerAI, move: MoveDef, frame_offset: int) -> void:
	ai.target.fsm.current_state = WrestlerFSM.State.RUNNING_ATTACK
	ai.target._active_move = move
	ai.target._move_ticks_remaining = move.total_frames() - frame_offset

func test_does_not_press_before_reaction_delay_elapses() -> void:
	var ai := _make_ai()
	var move := _make_move()
	_set_frame_offset(ai, move, 7) # window opens
	for i in ai.reversal_reaction_ticks:
		var input := {}
		ai._maybe_press_reversal(input)
		assert_bool(input.get("reversal", false)).is_false()

func test_presses_once_reaction_delay_elapses_inside_window() -> void:
	var ai := _make_ai()
	var move := _make_move()
	_set_frame_offset(ai, move, 7)
	for i in ai.reversal_reaction_ticks:
		ai._maybe_press_reversal({})
	var input := {}
	ai._maybe_press_reversal(input)
	assert_bool(input["reversal"]).is_true()

func test_resets_when_opponent_leaves_the_move_state() -> void:
	var ai := _make_ai()
	var move := _make_move()
	_set_frame_offset(ai, move, 7)
	for i in ai.reversal_reaction_ticks + 1:
		ai._maybe_press_reversal({})
	ai.target.fsm.current_state = WrestlerFSM.State.IDLE
	var input := {}
	ai._maybe_press_reversal(input)
	assert_bool(input.get("reversal", false)).is_false()
	assert_int(ai._reversal_window_ticks).is_equal(0)

func test_never_presses_outside_the_window() -> void:
	var ai := _make_ai()
	var move := _make_move()
	_set_frame_offset(ai, move, 2) # before the window
	for i in 10:
		var input := {}
		ai._maybe_press_reversal(input)
		assert_bool(input.get("reversal", false)).is_false()
