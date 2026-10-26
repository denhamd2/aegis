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
	var crb: MoveDef = load("res://resources/moves/finisher_cross_rhodes.tres")
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
			"strikes/springboard_cutter_attacker", "strikes/springboard_cutter_defender",
			"strikes/springboard_moonsault_attacker", "strikes/springboard_moonsault_defender"]:
		for w in [_roman, _cody]:
			assert_bool(w.anim_player.has_animation(clip)) \
					.override_failure_message("%s lacks %s" % [w.name, clip]).is_true()


func test_roman_clotheslines_a_man_in_the_corner() -> void:
	await _ticks(2)
	assert_object(_roman.corner_strike_move).is_not_null()
	# Cody chops a man in the corner (the AI staples round, 25 Oct).
	assert_str(String(_cody.corner_strike_move.animation_pair_id)).is_equal("strike_chop")
	assert_object(_roman._pick_string_strike()).is_not_equal(_roman.corner_strike_move)
	_cody._corner_trapped = true
	_cody.fsm.transition_to(WrestlerFSM.State.STUNNED)
	assert_object(_roman._pick_string_strike()).is_equal(_roman.corner_strike_move)


## The springboard ends three ways, one a match, in turn by the seed: the
## Disaster Kick, the Cody Cutter, the moonsault (FF batch 6).
func test_the_seed_picks_each_springboard_ending() -> void:
	var picked := []
	for seed_value in [3, 4, 5]:
		_cody.match_seed = seed_value
		picked.append(DiveSpot.ending_of(_cody))
	assert_array(picked).is_equal([DiveSpot.SPRING_MOVE, DiveSpot.CUTTER_MOVE,
			DiveSpot.MOONSAULT_MOVE])
	# A man whose dives carry none of them would get the Disaster Kick.
	assert_str(DiveSpot.ending_of(_roman)).is_equal(DiveSpot.SPRING_MOVE)


## The moonsault ending, played: Roman taken over backward and down, hurt,
## inside the ropes; Cody up on his feet inside, past him.
func test_the_springboard_moonsault_puts_him_down() -> void:
	await _ticks(2)
	_cody.match_seed = 5
	assert_str(DiveSpot.ending_of(_cody)).is_equal(DiveSpot.MOONSAULT_MOVE)
	_roman.global_position = Vector3(2.4, 0.0, 0.3)
	_cody.global_position = Vector3(1.0, 0.0, 0.3)
	await _ticks(1)
	var before := _roman.combat.total_damage()
	var spot := DiveSpot.new()
	spot.name = "DiveSpot"
	_scene.add_child(spot)
	spot.begin(_cody, _roman)
	# Straight to the last beat, the springboard.
	spot._seg = spot._segments.size() - 2
	spot._next()
	var guard := 0
	while is_instance_valid(spot) and guard < DiveSpot.MOONSAULT_TICKS + 40:
		await get_tree().physics_frame
		guard += 1
	assert_bool(is_instance_valid(spot)).is_false()
	assert_int(_roman.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	assert_float(_roman.combat.total_damage()).is_greater(before)
	assert_bool(_cody.outside_ring).is_false()
	for w: WrestlerController in [_roman, _cody]:
		assert_float(maxf(absf(w.global_position.x), absf(w.global_position.z))).is_less(3.0)
	# Up past the man's head, not on top of him.
	assert_float(_cody.global_position.distance_to(_roman.global_position)).is_greater(0.9)


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
