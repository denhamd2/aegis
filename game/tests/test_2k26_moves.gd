extends GdUnitTestSuite
## The moves the 2K26 match shows that we lacked
## (gauntlet/refs/moveset_audit_2k26.md): the Superman Punch into the Spear,
## the Cross Rhodes from behind, Roman's corner clotheslines, Cody's
## top-rope moonsault, the possum attack and the springboard Cody Cutter.

var _scene: Node
var _roman: WrestlerController
var _cody: WrestlerController


func before_test() -> void:
	_scene = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(_scene, Roster.by_id("roman"), Roster.by_id("cody"), 3)
	_scene.entrances = false
	add_child(_scene)
	_roman = _scene.get_node("WrestlerA")
	_cody = _scene.get_node("WrestlerB")
	for w in [_roman, _cody]:
		w.is_ai = false


func after_test() -> void:
	_scene.queue_free()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_the_variants_are_finishers() -> void:
	var sms: MoveDef = load("res://resources/moves/finisher_superman_spear.tres")
	var crb: MoveDef = load("res://resources/moves/finisher_cross_rhodes_behind.tres")
	assert_bool(_roman.is_finisher(sms)).is_true()
	assert_bool(_cody.is_finisher(crb)).is_true()
	assert_bool(_cody.is_finisher(sms)).is_false()
	for move: MoveDef in [sms, crb]:
		var id := String(move.animation_pair_id)
		assert_bool(PairedRecipes.RECIPES.has(id)).is_true()
		assert_bool(PairedRecipes.TRAJECTORIES.has(id)).is_true()
		# The move lasts as long as its trajectory.
		assert_float(move.total_frames() / 60.0).is_equal_approx(
				float(PairedRecipes.TRAJECTORIES[id]["length"]), 0.02)


func test_every_new_clip_is_on_both_men() -> void:
	for clip in ["strikes/strike_corner_clothesline", "strikes/top_rope_step",
			"strikes/moonsault", "strikes/possum_sweep", "strikes/swept_legs",
			"strikes/springboard_cutter_attacker", "strikes/springboard_cutter_defender"]:
		for w in [_roman, _cody]:
			assert_bool(w.anim_player.has_animation(clip)) \
					.override_failure_message("%s lacks %s" % [w.name, clip]).is_true()


func test_roman_clotheslines_a_man_in_the_corner() -> void:
	await _ticks(2)
	assert_object(_roman.corner_strike_move).is_not_null()
	assert_object(_cody.corner_strike_move).is_null()
	assert_object(_roman._pick_string_strike()).is_not_equal(_roman.corner_strike_move)
	_cody._corner_trapped = true
	_cody.fsm.transition_to(WrestlerFSM.State.STUNNED)
	assert_object(_roman._pick_string_strike()).is_equal(_roman.corner_strike_move)


func test_the_springboard_ends_on_the_cutter_on_odd_seeds() -> void:
	_cody.match_seed = 3
	assert_bool(DiveSpot.uses_cutter(_cody)).is_true()
	_cody.match_seed = 4
	assert_bool(DiveSpot.uses_cutter(_cody)).is_false()
	assert_bool(DiveSpot.uses_cutter(_roman)).is_false()


func test_a_man_down_mid_ring_can_be_dived_on() -> void:
	var t := Transform3D(Basis(), Vector3(0.4, 0.0, -0.2))
	var pick := TopRopeSpot.pick_corner(t)
	assert_array(pick).is_not_empty()
	var reach := DiveSpot._flat(pick[1]).distance_to(DiveSpot._flat(t * TopRopeSpot.DOWNED_CHEST)) \
			- TopRopeSpot.CHEST_FROM_ROOT
	assert_float(reach).is_between(TopRopeSpot.MIN_REACH, TopRopeSpot.MAX_REACH)


## The whole moonsault plays in a match and hands back a man covering-ready
## beside a man still down, hurt by it.
func test_the_moonsault_plays_through() -> void:
	await _ticks(2)
	_roman.global_position = Vector3(0.3, _roman.global_position.y, 0.0)
	_roman._go_down()
	var before := _roman.combat.total_damage()
	var referee := _scene.get_node("MatchReferee")
	referee._start_top_rope(_cody, _roman)
	var spot := _scene.get_node("TopRopeSpot")
	var guard := 0
	while is_instance_valid(spot) and guard < 1200:
		await get_tree().physics_frame
		guard += 1
	assert_bool(is_instance_valid(spot)).is_false()
	assert_int(_roman.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	assert_float(_roman.combat.total_damage()).is_greater(before)
	assert_float(DiveSpot._flat(_cody.global_position).distance_to(
			DiveSpot._flat(_roman.global_position))).is_less(1.2)


## The possum attack: Roman down, Cody standing at his boots -- the sweep is
## on for the AI, never for a player, and once it plays both men are down.
func test_the_possum_attack() -> void:
	await _ticks(2)
	_roman._go_down()
	_roman.fsm.ticks_in_state = PossumSpot.MIN_DOWN_TICKS
	_cody.global_position = _roman.global_transform * PossumSpot.STAND_AT
	assert_bool(PossumSpot.wants(_roman, _cody)).is_false()
	_roman.is_ai = true
	assert_bool(PossumSpot.wants(_roman, _cody)).is_true()
	var referee := _scene.get_node("MatchReferee")
	referee._start_possum(_roman, _cody)
	var spot := _scene.get_node("PossumSpot")
	var guard := 0
	while is_instance_valid(spot) and guard < 400:
		await get_tree().physics_frame
		guard += 1
	assert_int(_cody.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	assert_int(_roman.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	assert_bool(PossumSpot.wants(_roman, _cody)).is_false()
