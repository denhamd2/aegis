extends GdUnitTestSuite
## After the three: the loser stays laid out on the mat through the whole
## post-match, and the winner climbs a turnbuckle to celebrate.

var _scene: Node
var _saved_replays: CameraSettings.Replays


func before_test() -> void:
	_saved_replays = CameraSettings.replays
	_scene = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(_scene, pair[0], pair[1], 3)
	_scene.entrances = false
	add_child(_scene)


func after_test() -> void:
	CameraSettings.replays = _saved_replays
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
	# Run the whole post-match; the loser never gets up. The owner, 9 Nov:
	# no hand raise -- the winner climbs a turnbuckle and celebrates.
	var worst := 0.0
	var actor: RefereeActor = _scene.referee_actor
	var raised := false
	var posed := false
	for i in 2400:
		await get_tree().process_frame
		worst = maxf(worst, _pelvis_y(loser))
		if actor.mode == RefereeActor.Mode.RAISE:
			raised = true
		if pm._stage == "corner" and pm._corner_step == 3 \
				and winner._presentation_clip == PostMatch.corner_pose_clip(winner):
			posed = true
			# Up on the second rope, in the corner, facing out.
			var flat := Vector2(winner.global_position.x, winner.global_position.z)
			assert_float(flat.length()).is_greater(2.0)
		if pm.is_done():
			break
	assert_float(worst).is_less(0.6)
	assert_bool(raised).is_false()
	assert_bool(posed).is_true()


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


func test_normal_loser_stays_down_and_a_buffered_finish_never_replays() -> void:
	var winner: WrestlerController = _scene.get_node("WrestlerA")
	var loser: WrestlerController = _scene.get_node("WrestlerB")
	winner.is_ai = false
	loser.is_ai = false
	for i in 20:
		await get_tree().physics_frame
	winner.fsm.transition_to(WrestlerFSM.State.IDLE)
	loser.fsm.transition_to(WrestlerFSM.State.IDLE)
	loser.fsm.transition_to(WrestlerFSM.State.STUNNED)
	loser.fsm.transition_to(WrestlerFSM.State.DOWN)
	loser._move_ticks_remaining = 1
	assert_bool(loser.dead).is_false()
	# Supply a valid replay window even headless. The old ending would play it.
	var buffer: ReplayBuffer = _scene.replay_buffer
	buffer._marks = {"finisher": 2.0, "cover": 4.0}
	buffer._frames = [[0.0, buffer._snapshot()], [6.0, buffer._snapshot()]]
	CameraSettings.replays = CameraSettings.Replays.FREQUENT
	_scene.referee._declare_winner(winner, "pinfall")
	var pm: PostMatch = _scene.post_match
	assert_str(pm._stage).is_equal("winner")
	assert_bool(pm._card.is_showing()).is_true()
	assert_int(winner.fsm.current_state).is_equal(WrestlerFSM.State.VICTORY)
	for i in 1100:
		await get_tree().physics_frame
		assert_bool(buffer._playing).is_false()
		assert_bool(winner.is_physics_processing()).is_false()
		assert_bool(loser.is_physics_processing()).is_false()
		if i > 30:
			assert_float(_pelvis_y(loser)).is_less(0.6)
		if pm.is_done():
			break
	assert_int(loser.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
