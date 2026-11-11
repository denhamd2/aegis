extends GdUnitTestSuite
## The owner, 3 Nov: "the wrestlers didn't run the ropes, there were no Irish
## whips ... lariats" and, outside, "it feels more like a synchronized dance.
## I would expect one to be running facing away from the other, and the other
## wrestler chasing him, and if close enough to attack him from behind."

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func _pair() -> Array[WrestlerController]:
	var out: Array[WrestlerController] = []
	for i in 2:
		var w: WrestlerController = WRESTLER_SCENE.instantiate()
		w.player_index = i
		w.display_name = "ROMAN REIGNS" if i == 0 else "CODY RHODES"
		MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
		auto_free(w)
		add_child(w)
		out.append(w)
	out[0].opponent = out[1]
	out[1].opponent = out[0]
	for w in out:
		w.is_ai = true
		w.ai.target = w.opponent
		w.ai.setup_jitter(5, w.player_index)
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
	return out


func test_he_runs_for_the_ropes_away_from_the_other_man() -> void:
	var dir := WrestlerController.rope_run_dir(Vector3(0.5, 0.0, 0.2), Vector3(-1.0, 0.0, 0.0))
	assert_vector(dir).is_equal(Vector3(1, 0, 0))
	dir = WrestlerController.rope_run_dir(Vector3(0.0, 0.0, -0.5), Vector3(0.2, 0.0, 1.5))
	assert_vector(dir).is_equal(Vector3(0, 0, -1))


func test_running_the_ropes_sends_him_off_and_marks_the_run() -> void:
	var pair := _pair()
	var roman := pair[0]
	roman.global_position = Vector3(0.0, 0.0, 0.0)
	pair[1].global_position = Vector3(-1.5, 0.0, 0.0)
	await get_tree().physics_frame
	assert_bool(roman.begin_rope_run()).is_true()
	assert_bool(roman.rope_running).is_true()
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.IRISH_WHIP)
	assert_float(roman.velocity.x).is_greater(0.0)


func test_no_rope_run_from_the_ropes_or_outside() -> void:
	var pair := _pair()
	var roman := pair[0]
	roman.global_position = Vector3(WrestlerController.RING_KEEP_IN - 0.2, 0.0, 0.0)
	assert_bool(roman.can_rope_run()).is_false()
	roman.global_position = Vector3.ZERO
	roman.outside_ring = true
	assert_bool(roman.can_rope_run()).is_false()


func test_on_the_floor_the_worse_off_man_breaks_away_and_runs() -> void:
	var pair := _pair()
	var roman := pair[0]
	var cody := pair[1]
	for w in pair:
		w.outside_ring = true
	roman.global_position = Vector3(4.2, -1.1, 0.0)
	cody.global_position = Vector3(4.2, -1.1, 2.0)
	# the worse off of the two (health is limb damage)
	for limb in cody.combat.limb_damage:
		cody.combat.limb_damage[limb] += 15.0
	var broke := false
	for i in 600:
		cody.ai._flee_cooldown = 0
		var input: Dictionary = cody.ai._floor_chase_input({}, roman.global_position - cody.global_position, 2.0)
		if cody.ai.is_fleeing():
			broke = true
			# away from him, at a run
			input = cody.ai._floor_chase_input({}, roman.global_position - cody.global_position, 2.0)
			var move: Vector2 = input["move"]
			assert_bool(input.get("run", false)).is_true()
			assert_float(move.y).is_greater(0.0)
			break
	assert_bool(broke).is_true()
	# The other man runs him down, then stops and hits him from behind.
	var chase: Dictionary = roman.ai._floor_chase_input({}, cody.global_position - roman.global_position, 2.0)
	assert_bool(chase.get("run", false)).is_true()
	chase = roman.ai._floor_chase_input({}, cody.global_position - roman.global_position, 1.0)
	assert_bool(chase.get("strike", false)).is_true()


func test_a_man_jogging_on_the_floor_faces_where_he_runs() -> void:
	var pair := _pair()
	var cody := pair[1]
	for w in pair:
		w.outside_ring = true
	pair[0].global_position = Vector3(4.2, -1.1, 0.0)
	cody.global_position = Vector3(4.2, -1.1, 1.2)
	await get_tree().physics_frame
	for i in 10:
		cody._process_free_movement(1.0 / 60.0, {"move": Vector2(0.0, 1.0), "run": true})
	var facing := -cody.global_basis.z
	assert_float(facing.z).is_greater(0.9)


func test_a_real_rope_rebound_continues_into_an_attack() -> void:
	var scene: Node = auto_free(load("res://scenes/match.tscn").instantiate())
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1, true)
	for part in ["Arena", "LightRig"]:
		scene.get_node(part).free()
	scene.entrances = false
	add_child(scene)
	var runner := scene.get_node("WrestlerA") as WrestlerController
	var target := scene.get_node("WrestlerB") as WrestlerController
	scene.get_node("MatchReferee").set_physics_process(false)
	target.is_ai = false
	runner.global_position = Vector3.ZERO
	target.global_position = Vector3(-1.5, 0, 0)
	assert_bool(runner.begin_rope_run()).is_true()
	var rebounded := false
	var attacked := false
	for tick in 240:
		await get_tree().physics_frame
		if runner.is_whip_returning():
			rebounded = true
		# Into a running strike or a two-man move -- the plain clothesline
		# has no pair id, so it leaves no attempt record to look for.
		if runner.fsm.current_state in [WrestlerFSM.State.GRAPPLE_HOLD,
				WrestlerFSM.State.RUNNING_ATTACK]:
			attacked = true
			break
	assert_bool(rebounded).override_failure_message("Never returned from the actual ring ropes").is_true()
	assert_bool(attacked).override_failure_message("Rebound expired before a running attack").is_true()
	assert_bool(runner.rope_running).is_false()
	assert_bool(runner.fsm.current_state in [WrestlerFSM.State.GRAPPLE_HOLD,
			WrestlerFSM.State.RUNNING_ATTACK]).is_true()
