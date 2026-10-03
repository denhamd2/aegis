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
		# The finish is replayed after the bell (PostMatch), not mid-match.
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
