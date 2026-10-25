extends GdUnitTestSuite
## Roman's build to the Spear (gauntlet/refs/ff_moves_and_gameplay_plan.md, AI
## staples 6): with it in hand and the man down he drops into his set-up --
## the canvas pounded, the roar, the coil -- holds it until the man is up, and
## runs the Spear into him. The Spear run in is his finisher, whatever path
## threw it.

const MATCH := "res://scenes/match.tscn"


func _roman_vs_cody() -> Node:
	var scene: Node = auto_free(load(MATCH).instantiate())
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	add_child(scene)
	return scene


func test_roman_carries_the_run_in_spear_as_a_finisher() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	assert_object(roman.finisher_run_move).is_not_null()
	assert_str(String(roman.finisher_run_move.animation_pair_id)).is_equal("running_spear")
	assert_bool(roman.is_finisher(roman.finisher_run_move)).is_true()
	assert_object(cody.finisher_run_move).is_null()
	assert_bool(roman.anim_player.has_animation(WrestlerController.SPEAR_SETUP_CLIP)).is_true()


func test_the_set_up_holds_until_he_is_up() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	roman.is_ai = false
	cody.is_ai = false
	roman.global_position = Vector3(-1.5, 0.0, 0.0)
	cody.global_position = Vector3(1.5, 0.0, 0.0)
	cody.fsm.current_state = WrestlerFSM.State.DOWN
	await get_tree().physics_frame
	roman.begin_spear_setup()
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.TAUNT)
	# Past the clip and still set: the man is down.
	for i in WrestlerController.SPEAR_SETUP_TICKS + 30:
		cody.fsm.current_state = WrestlerFSM.State.DOWN
		await get_tree().physics_frame
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.TAUNT)
	# He is up: out of the coil.
	cody.fsm.current_state = WrestlerFSM.State.IDLE
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(roman.fsm.current_state).is_not_equal(WrestlerFSM.State.TAUNT)


func test_the_spear_runs_into_a_man_on_his_feet() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	roman.global_position = Vector3(-3.0, 0.0, 0.0)
	cody.global_position = Vector3(0.0, 0.0, 0.0)
	await get_tree().physics_frame
	# Out of range: not yet.
	assert_bool(roman.try_running_finisher()).is_false()
	roman.global_position = Vector3(-1.0, 0.0, 0.0)
	await get_tree().physics_frame
	roman.fsm.current_state = WrestlerFSM.State.RUN
	cody.fsm.current_state = WrestlerFSM.State.IDLE
	assert_bool(roman.try_running_finisher()).is_true()
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.GRAPPLE_HOLD)
	assert_object(roman._active_move).is_same(roman.finisher_run_move)


func test_the_ai_backs_off_sets_and_spears_him_as_he_rises() -> void:
	var scene := _roman_vs_cody()
	await await_millis(40)
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	var ai := roman.ai
	assert_object(ai).is_not_null()
	ai.target = cody
	# The Spear in hand.
	roman.combat.momentum = CombatSystem.MOMENTUM_MAX
	roman.combat.tier_reached = CombatSystem.Tier.SIGNATURE
	assert_bool(roman.combat.can_finisher()).is_true()
	roman.global_position = Vector3(0.0, 0.0, 0.0)
	cody.global_position = Vector3(1.2, 0.0, 0.0)
	cody.fsm.current_state = WrestlerFSM.State.DOWN
	await get_tree().physics_frame
	ai._begin_spear_stalk()
	# The spot is SPEAR_STALK_DISTANCE off him, away from where Roman stood.
	assert_float(Vector2(ai._spear_spot.x, ai._spear_spot.z)
			.distance_to(Vector2(cody.global_position.x, cody.global_position.z))) \
		.is_equal_approx(WrestlerAI.SPEAR_STALK_DISTANCE, 0.05)
	assert_float(ai._spear_spot.x).is_less(cody.global_position.x)
	# Walking there, then set.
	var input := ai._spear_stalk_input({"move": Vector2.ZERO}, Vector3.ZERO, 0.0)
	assert_float((input["move"] as Vector2).x).is_less(0.0)
	roman.global_position = ai._spear_spot
	input = ai._spear_stalk_input({"move": Vector2.ZERO}, Vector3.ZERO, 0.0)
	assert_bool(input.get("spear_setup", false)).is_true()
	assert_int(ai._spear_stalk).is_equal(WrestlerAI.STALK_SET)
