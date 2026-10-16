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
	# A gunshot victim cannot recover, so the attacker has time to cover him
	# and this test exercises the real finish path rather than racing the quick
	# recovery timer on an ordinary knockdown.
	b.dead = true
	b._move_ticks_remaining = 1 << 30
	b.knockdown_tier = CombatSystem.Tier.SIGNATURE
	b.global_position = Vector3.ZERO
	a.global_position = Vector3(0.0, 0.0, -0.9)
	b._cover_eligible = true
	for i in 900:
		await get_tree().physics_frame
		if _scene.post_match != null:
			break
	return [a, b]


func _pelvis_y(w: WrestlerController) -> float:
	var p := w._bone_world("pelvis")
	return p.y if p != Vector3.INF else w.global_position.y


func test_gunshot_victim_is_covered_and_stays_down_after_the_match() -> void:
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


func test_a_standing_loser_is_put_on_the_mat_for_the_post_match() -> void:
	var winner: WrestlerController = _scene.get_node("WrestlerA")
	var loser: WrestlerController = _scene.get_node("WrestlerB")
	winner.is_ai = false
	loser.is_ai = false
	for i in 20:
		await get_tree().physics_frame
	assert_float(_pelvis_y(loser)).is_greater(0.6)
	_scene._on_match_won(winner, "count_out")
	assert_object(_scene.post_match).is_not_null()
	var worst := 0.0
	for i in 1200:
		await get_tree().process_frame
		worst = maxf(worst, _pelvis_y(loser))
		if _scene.post_match.is_done():
			break
	assert_float(worst).is_less(0.6)
