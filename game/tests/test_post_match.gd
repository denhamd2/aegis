extends GdUnitTestSuite
## After the three: the loser stays laid out on the mat through the whole
## post-match, and the winner ends up beside Aubrey with his arm raised.

var _scene: Node


func before_test() -> void:
	_scene = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(_scene, pair[0], pair[1], 3)
	_scene.entrances = false
	add_child(_scene)


func after_test() -> void:
	_scene.queue_free()


func _finish_by_pin() -> Array:
	var a: WrestlerController = _scene.get_node("WrestlerA")
	var b: WrestlerController = _scene.get_node("WrestlerB")
	a.is_ai = false
	b.is_ai = false
	for i in 20:
		await get_tree().physics_frame
	a.fsm.transition_to(WrestlerFSM.State.IDLE)
	b.fsm.transition_to(WrestlerFSM.State.IDLE)
	b.fsm.transition_to(WrestlerFSM.State.STUNNED)
	b.fsm.transition_to(WrestlerFSM.State.DOWN)
	b._move_ticks_remaining = 2000
	a.global_position = b.global_position + (a.global_position - b.global_position).normalized() * 0.9
	for i in 900:
		await get_tree().physics_frame
		if _scene.post_match != null:
			break
		if _scene.referee.is_pin_active() and i > 60:
			_scene.referee._end_pin(true)
	return [a, b]


func _pelvis_y(w: WrestlerController) -> float:
	var p := w._bone_world("pelvis")
	return p.y if p != Vector3.INF else w.global_position.y


func test_loser_stays_down_and_winner_arm_goes_up() -> void:
	var men := await _finish_by_pin()
	assert_object(_scene.post_match).is_not_null()
	var pm: PostMatch = _scene.post_match
	var loser: WrestlerController = pm.loser
	var winner: WrestlerController = pm.winner
	for i in 120:
		await get_tree().process_frame
	assert_float(_pelvis_y(loser)).is_less(0.6)
	assert_int(winner.fsm.current_state).is_equal(WrestlerFSM.State.VICTORY)
	# Run the whole post-match; the loser never gets up.
	var worst := 0.0
	for i in 2400:
		await get_tree().process_frame
		worst = maxf(worst, _pelvis_y(loser))
		if pm.is_done():
			break
	assert_float(worst).is_less(0.6)
	var actor: RefereeActor = _scene.referee_actor
	assert_int(actor.mode).is_equal(RefereeActor.Mode.RAISE)
	assert_float(actor.raise_hand_gap()).is_less(0.25)
