extends GdUnitTestSuite
## The in-match replay (InstantReplay, camera_aaa_plan.md C2 "Frequent"):
## which moves earn one, when it may play, and that a match carries it.

func _scene() -> Node:
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], 3)
	scene.entrances = false
	add_child(scene)
	return auto_free(scene)


func test_a_signature_earns_a_replay_and_the_finisher_does_not() -> void:
	var scene := _scene()
	var w: WrestlerController = scene.get_node("WrestlerA")
	if w.signature_move:
		assert_bool(InstantReplay.worth_replaying(w, w.signature_move)).is_true()
	if w.finisher_move:
		# Finishers do not interrupt the finish; ending replays are removed.
		assert_bool(InstantReplay.worth_replaying(w, w.finisher_move)).is_false()
	if w.grapple_move:
		assert_bool(InstantReplay.worth_replaying(w, w.grapple_move)).is_false()
	assert_bool(InstantReplay.worth_replaying(w, null)).is_false()


func test_it_plays_only_on_frequent_between_moves_and_not_too_often() -> void:
	assert_bool(InstantReplay.may_play(true, false, 100.0, -INF)).is_true()
	assert_bool(InstantReplay.may_play(false, false, 100.0, -INF)).is_false()
	# Never in a pin or a hold.
	assert_bool(InstantReplay.may_play(true, true, 100.0, -INF)).is_false()
	assert_bool(InstantReplay.may_play(true, false, 100.0, 100.0 - InstantReplay.COOLDOWN + 1.0)).is_false()
	assert_bool(InstantReplay.may_play(true, false, 100.0, 100.0 - InstantReplay.COOLDOWN)).is_true()


func test_a_queued_replay_is_cancelled_when_the_match_is_over() -> void:
	var replay: InstantReplay = auto_free(InstantReplay.new())
	replay.referee = auto_free(MatchReferee.new())
	replay.buffer = auto_free(ReplayBuffer.new())
	replay._due = 0.0
	replay._capture_from = 0.0
	replay.referee._match_over = true
	replay._process(1.0 / 60.0)
	assert_float(replay._due).is_equal(-1.0)
	assert_float(replay._capture_from).is_equal(-1.0)
	assert_int(replay.replays).is_zero()
	assert_bool(replay.is_processing()).is_false()


func test_options_keep_in_match_replays_and_retire_the_finish_only_choice() -> void:
	var saved := CameraSettings.replays
	var menu: TitleScreen = auto_free(TitleScreen.new())
	menu.camera_row = 3
	assert_array(TitleScreen.CAMERA_ROWS[3][1]).is_equal(["OFF", "FREQUENT"])
	# Legacy stored/CLI FINISH values remain readable, without ending replays.
	CameraSettings.replays = CameraSettings.Replays.FINISH
	assert_int(TitleScreen.camera_option(3)).is_zero()
	assert_bool(CameraSettings.replay_finish()).is_false()
	menu.step_camera_option(1)
	assert_bool(CameraSettings.replay_frequent()).is_true()
	assert_int(TitleScreen.camera_option(3)).is_equal(1)
	menu.step_camera_option(-1)
	assert_bool(CameraSettings.replay_frequent()).is_false()
	CameraSettings.replays = saved


## Every match carries one, and headless (no frames recorded) it never pauses
## the match.
func test_the_match_carries_it_and_headless_it_never_fires() -> void:
	var scene := _scene()
	var replay: InstantReplay = scene.get_node("InstantReplay")
	assert_object(replay).is_not_null()
	for i in 120:
		await get_tree().physics_frame
	assert_int(replay.replays).is_equal(0)
	assert_bool(get_tree().paused).is_false()
