extends GdUnitTestSuite
## A landed handgun hit is fatal, leaves no recoverable health, and cannot be
## recovered from through the ordinary DOWN timer.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")
const MATCH_SCENE := preload("res://scenes/match.tscn")


func _wrestler() -> WrestlerController:
	var w: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	w.character_model_scene = load("res://scenes/kenny_model.tscn")
	add_child(w)
	await get_tree().physics_frame
	await get_tree().process_frame
	return w


func test_handgun_hit_drains_health_and_keeps_him_down() -> void:
	var victim := await _wrestler()
	victim._pending_hits.append(WeaponCatalog.swing_move(WeaponCatalog.by_id(&"handgun")))
	victim._resolve_pending_hits()

	assert_bool(victim.dead).is_true()
	assert_float(victim.combat.health()).is_equal(0.0)
	assert_float(victim.combat.green).is_equal(0.0)
	assert_int(victim.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	for i in 600:
		victim.combat.tick_recovery()
		victim._process_down({})
	assert_float(victim.combat.health()).is_equal(0.0)
	assert_int(victim.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)


func test_survivor_covers_a_fatal_shot_and_the_dead_wrestler_cannot_kick_out() -> void:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	var survivor: WrestlerController = scene.get_node("WrestlerA")
	var victim: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	survivor.global_position = Vector3(-2.0, 0.0, 0.0)
	victim.global_position = Vector3.ZERO
	victim._take_fatal_gunshot()
	survivor.is_ai = true
	survivor.combat.momentum = CombatSystem.FINISHER_THRESHOLD

	assert_bool(referee.wants_cover(victim)).is_true()
	var intent := survivor.ai.poll_input()
	assert_bool(intent.get("taunt", false)).is_false()
	assert_float((intent.get("move", Vector2.ZERO) as Vector2).length()).is_greater(0.0)

	# The survivor has reached the victim's side; the referee should initiate a
	# cover immediately rather than wait for a finisher knockdown or another hit.
	survivor.global_position = Vector3(0.5, 0.0, 0.0)
	referee._check_for_downed_opponent_action()
	assert_bool(referee.is_pin_active()).is_true()
	assert_int(survivor.fsm.current_state).is_equal(WrestlerFSM.State.PIN_ATTACKER)

	# A dead wrestler cannot fight the pin minigame or reach for the ropes.
	victim._kickout_input_this_tick = true
	for i in MatchReferee.PIN_COUNT_TICKS:
		referee._tick_pin()
	assert_bool(referee.is_match_over()).is_true()
	assert_int(referee.pin_count()).is_equal(3)
