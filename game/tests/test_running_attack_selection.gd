extends GdUnitTestSuite
## WrestlerController._maybe_start_running_attack() -- the trigger for
## RUN -> RUNNING_ATTACK, previously dead code (nothing ever called
## _start_move(RUNNING_ATTACK, ...) at all). Covers the gate directly:
## in range, running_attack_move set, opponent hittable, strike pressed.

func _make_pair() -> Array:
	var attacker: WrestlerController = auto_free(WrestlerController.new())
	var defender: WrestlerController = auto_free(WrestlerController.new())
	for w in [attacker, defender]:
		# CharacterBody3D defers global_position to the physics server, which
		# only exists once the node is actually inside a SceneTree -- outside
		# the tree, global_position writes silently no-op (reads back as
		# always zero). add_child() here (in addition to the auto_free()
		# above, which still handles cleanup) is required for the range
		# checks below to mean anything.
		add_child(w)
		w.fsm = auto_free(WrestlerFSM.new())
		w.combat = CombatSystem.new()
	attacker.fsm.current_state = WrestlerFSM.State.RUN
	attacker.opponent = defender
	attacker.global_position = Vector3.ZERO
	defender.global_position = Vector3(1.0, 0, 0) # inside STRIKE_HIT_RANGE (1.8)
	var move := MoveDef.new()
	move.animation_pair_id = &"running_attack_clothesline"
	attacker.running_attack_move = move
	return [attacker, defender]

func test_fires_when_in_range_and_strike_pressed() -> void:
	var pair := _make_pair()
	pair[0]._maybe_start_running_attack({"strike": true})
	assert_int(pair[0].fsm.current_state).is_equal(WrestlerFSM.State.RUNNING_ATTACK)
	assert_object(pair[0]._active_move).is_same(pair[0].running_attack_move)

func test_does_not_fire_without_strike_pressed() -> void:
	var pair := _make_pair()
	pair[0]._maybe_start_running_attack({"strike": false})
	assert_int(pair[0].fsm.current_state).is_equal(WrestlerFSM.State.RUN)

func test_does_not_fire_out_of_range() -> void:
	var pair := _make_pair()
	pair[1].global_position = Vector3(10.0, 0, 0)
	pair[0]._maybe_start_running_attack({"strike": true})
	assert_int(pair[0].fsm.current_state).is_equal(WrestlerFSM.State.RUN)

func test_does_not_fire_without_running_attack_move() -> void:
	var pair := _make_pair()
	pair[0].running_attack_move = null
	pair[0]._maybe_start_running_attack({"strike": true})
	assert_int(pair[0].fsm.current_state).is_equal(WrestlerFSM.State.RUN)

func test_does_not_fire_against_unhittable_opponent() -> void:
	var pair := _make_pair()
	pair[1].fsm.current_state = WrestlerFSM.State.DOWN
	pair[0]._maybe_start_running_attack({"strike": true})
	assert_int(pair[0].fsm.current_state).is_equal(WrestlerFSM.State.RUN)
