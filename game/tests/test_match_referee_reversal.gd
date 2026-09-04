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

## When the reverser has a real GrappleRig, _apply_reversal() plays a paired
## counter animation asynchronously (see its own doc comment) instead of
## resolving immediately -- the other tests above all exercise the
## no-grapple_rig fallback (bare WrestlerController.new() never gets one),
## so this covers the async path directly. A bare, unparented GrappleRig
## has no animation_player, so begin() takes its grey-box timer fallback
## (see grapple_rig.gd) rather than needing a real AnimationPlayer/library
## in this unit test.
func test_reverses_via_paired_animation_when_grapple_rig_present() -> void:
	var setup := _make_referee_with_pair()
	var referee: MatchReferee = setup[0]
	var reverser: WrestlerController = setup[1]
	var attacker: WrestlerController = setup[2]
	reverser.grapple_rig = auto_free(GrappleRig.new())
	var counter_move := MoveDef.new()
	counter_move.startup_frames = 1
	counter_move.active_frames = 0
	counter_move.recovery_frames = 0
	referee.reversal_counter_move = counter_move
	var move := _make_move()
	_put_in_running_attack(attacker, move, 9)
	reverser._wants_reversal_this_tick = true

	referee._check_for_reversal()

	# Not resolved yet -- still mid-animation.
	assert_bool(referee._reversing).is_true()
	assert_int(attacker.fsm.current_state).is_equal(WrestlerFSM.State.RUNNING_ATTACK)

	await reverser.grapple_rig.grapple_finished

	assert_bool(referee._reversing).is_false()
	assert_int(attacker.fsm.current_state).is_equal(WrestlerFSM.State.HIT_REACT)
	assert_float(reverser.combat.momentum).is_equal(10.0)

## Both wrestlers inside each other's reversal window on the same tick.
##
## _check_for_reversal() read _reversing once, above its [[a,b],[b,a]] loop,
## so the second pair applied a reversal on top of the first. With a real
## GrappleRig on both sides that is a hard crash, not a cosmetic double-up:
## the first _apply_reversal() leaves the rig active, and the second call
## trips GrappleRig.begin()'s own `assert(not _active)`. Mutual windows are
## not exotic here -- the AI presses reversal off the opponent's window
## (WrestlerAI._maybe_press_reversal()) and rapid mutual strike-trading is
## the normal texture of this match loop.
##
## Correct behaviour: exactly one reversal lands, and the other wrestler
## simply doesn't get one this tick.
func test_mutual_same_tick_reversal_applies_only_one() -> void:
	var setup := _make_referee_with_pair()
	var referee: MatchReferee = setup[0]
	var wrestler_a: WrestlerController = setup[1]
	var wrestler_b: WrestlerController = setup[2]
	var move_a := _make_move()
	var move_b := _make_move()
	# Each is mid-move inside its own reversal window, and each wants to
	# reverse the other -- so both pairs of the loop qualify.
	_put_in_running_attack(wrestler_a, move_a, 9)
	_put_in_running_attack(wrestler_b, move_b, 9)
	wrestler_a._wants_reversal_this_tick = true
	wrestler_b._wants_reversal_this_tick = true

	referee._check_for_reversal()

	# Exactly one of them took the hit reaction; the other kept its move.
	var a_reversed := wrestler_a.fsm.current_state == WrestlerFSM.State.HIT_REACT
	var b_reversed := wrestler_b.fsm.current_state == WrestlerFSM.State.HIT_REACT
	assert_bool(a_reversed != b_reversed) \
		.override_failure_message("expected exactly one reversal, got a=%s b=%s" % [
			a_reversed, b_reversed]) \
		.is_true()

## The same mutual tick with a real GrappleRig on both sides -- the shape
## that actually crashed. A second _apply_reversal() would reach
## GrappleRig.begin() while it is still _active.
func test_mutual_same_tick_reversal_does_not_reenter_the_rig() -> void:
	var setup := _make_referee_with_pair()
	var referee: MatchReferee = setup[0]
	var wrestler_a: WrestlerController = setup[1]
	var wrestler_b: WrestlerController = setup[2]
	var rig: GrappleRig = auto_free(GrappleRig.new())
	wrestler_a.grapple_rig = rig
	wrestler_b.grapple_rig = rig
	var counter_move := MoveDef.new()
	counter_move.startup_frames = 1
	counter_move.active_frames = 0
	counter_move.recovery_frames = 0
	referee.reversal_counter_move = counter_move
	_put_in_running_attack(wrestler_a, _make_move(), 9)
	_put_in_running_attack(wrestler_b, _make_move(), 9)
	wrestler_a._wants_reversal_this_tick = true
	wrestler_b._wants_reversal_this_tick = true

	referee._check_for_reversal()

	# One reversal is in flight, and the rig was entered exactly once.
	assert_bool(referee._reversing).is_true()

	await rig.grapple_finished

	assert_bool(referee._reversing).is_false()
