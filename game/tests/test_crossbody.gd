extends GdUnitTestSuite
## Cody's crossbody off the top rope onto a man on his FEET -- the other
## top-rope spot (gauntlet/refs/ff_moves_and_gameplay_plan.md, AI staples 5).
## TopRopeSpot climbs the corner as for the moonsault; the man, just up, is
## turned to the corner and taken over backward in his own bump, and the
## match covers him from there.

const MATCH := "res://scenes/match.tscn"


func _roman_vs_cody() -> Node:
	var scene: Node = auto_free(load(MATCH).instantiate())
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	add_child(scene)
	return scene


func test_cody_carries_the_crossbody_and_roman_does_not() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	assert_object(cody.top_rope_standing_move).is_not_null()
	assert_str(String(cody.top_rope_standing_move.animation_pair_id)).is_equal("dive_crossbody")
	assert_object(roman.top_rope_standing_move).is_null()
	for clip in ["strikes/crossbody_leap", "strikes/crossbody_land"]:
		assert_bool(cody.anim_player.has_animation(clip)).is_true()


func test_only_a_man_in_reach_of_a_corner_can_be_crossbodied() -> void:
	# Dead centre is out of reach of every corner; a step toward one is not.
	assert_array(TopRopeSpot.pick_corner_standing(Vector3.ZERO)).is_empty()
	var pick := TopRopeSpot.pick_corner_standing(Vector3(1.0, 0.0, 1.0))
	assert_array(pick).is_not_empty()
	assert_vector(pick[0]).is_equal(Vector2(1, 1))


func test_off_the_top_he_takes_the_man_over_and_covers() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	var referee := scene.get_node("MatchReferee") as MatchReferee
	referee._tying_up = false
	cody.global_position = Vector3(0.2, 0.0, 0.6)
	roman.global_position = Vector3(1.0, 0.0, 1.0)
	for w: WrestlerController in [roman, cody]:
		w.velocity = Vector3.ZERO
	await get_tree().physics_frame
	roman.fsm.current_state = WrestlerFSM.State.GETUP
	var spot := TopRopeSpot.new()
	scene.add_child(spot)
	spot.begin(cody, roman, true)
	var hp := roman.combat.health()
	var finished := [false]
	spot.finished.connect(func() -> void: finished[0] = true)
	for i in 900:
		await get_tree().physics_frame
		if finished[0]:
			break
	assert_bool(finished[0]).is_true()
	# Taken over backward, hurt, and covered where he fell.
	assert_float(roman.combat.health()).is_less(hp)
	assert_bool(roman.fsm.is_in([WrestlerFSM.State.DOWN, WrestlerFSM.State.PIN_DEFENDER])).is_true()
	assert_bool(referee._pinning).is_true()
	var gap := Vector2(cody.global_position.x - roman.global_position.x,
			cody.global_position.z - roman.global_position.z).length()
	assert_float(gap).is_less(0.9)
	# And he lies where he was standing: taken over backward, not shoved
	# across the ring by Cody's body landing on his.
	var fell := Vector2(roman.global_position.x - 1.0, roman.global_position.z - 1.0).length()
	assert_float(fell).is_less(0.3)
