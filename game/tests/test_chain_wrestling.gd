extends GdUnitTestSuite
## Phase 4, chain wrestling (gauntlet/refs/animation_gap.md): out of a lock-up
## the holder steers a hold with the stick -- forward a headlock, back a
## go-behind, either side a wristlock -- and the man in it can reverse into
## the counter. Each hold is a paired link that ends with both men squared up
## again, so any link follows any other.


func test_the_stick_picks_the_hold_relative_to_his_facing() -> void:
	var facing_neg_z := Basis.IDENTITY # facing -Z
	assert_str(WrestlerController.chain_hold_for(Vector2(0, -1), facing_neg_z)).is_equal("headlock")
	assert_str(WrestlerController.chain_hold_for(Vector2(0, 1), facing_neg_z)).is_equal("waistlock")
	assert_str(WrestlerController.chain_hold_for(Vector2(1, 0), facing_neg_z)).is_equal("wristlock")
	assert_str(WrestlerController.chain_hold_for(Vector2(-1, 0), facing_neg_z)).is_equal("wristlock")
	# Turned to face +X, "forward" is +X.
	var facing_pos_x := Basis(Vector3.UP, -PI / 2.0)
	assert_str(WrestlerController.chain_hold_for(Vector2(1, 0), facing_pos_x)).is_equal("headlock")
	# A nudge is no pick.
	assert_str(WrestlerController.chain_hold_for(Vector2(0.2, 0), facing_neg_z)).is_equal("")


func test_every_hold_has_a_counter_that_is_a_hold() -> void:
	for hold: String in WrestlerController.CHAIN_HOLDS:
		assert_bool(WrestlerController.CHAIN_HOLDS.has(WrestlerController.CHAIN_COUNTER[hold])).is_true()
	assert_bool(WrestlerController.CHAIN_HOLDS.has(WrestlerController.CHAIN_COUNTER[""])).is_true()


func test_the_reversal_window_sits_inside_the_read() -> void:
	var w := WrestlerController.CHAIN_REVERSAL_WINDOW
	assert_int(w.x).is_greater(0)
	assert_int(w.y).is_less(WrestlerController.CHAIN_READ_TICKS)
	# The AI reads inside it too.
	assert_int(WrestlerAI.CHAIN_READ_TICK).is_between(w.x, w.y)


func test_each_link_is_an_authored_pair_that_holds_something() -> void:
	for hold: String in WrestlerController.CHAIN_HOLDS:
		var move: MoveDef = WrestlerController.CHAIN_HOLDS[hold]
		var id := String(move.animation_pair_id)
		assert_bool(PairedRecipes.RECIPES[id].has("authored")).is_true()
		assert_float(PairedRecipes.TRAJECTORIES[id]["length"]).is_equal(1.8)
		var family := PairedContacts.family(move)
		assert_str(family).is_not_empty()
		assert_str(family).is_not_equal("none")
		# Wear, not a way through the match.
		var damage := move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs
		assert_float(damage).is_between(1.0, 4.0)


## A link ends with the two squared up -- facing each other, clear of each
## other and near the lock-up's distance -- so the next link's lead-in is a
## step, not a walk round.
func test_each_link_ends_with_the_two_squared_up() -> void:
	for hold: String in WrestlerController.CHAIN_HOLDS:
		var id := String((WrestlerController.CHAIN_HOLDS[hold] as MoveDef).animation_pair_id)
		var spec: Dictionary = PairedRecipes.TRAJECTORIES[id]
		var ends := {}
		for role: String in ["attacker", "defender"]:
			var p: Array = spec[role]["pos"].back()
			var r: Array = spec[role]["rot"].back()
			var yaw := deg_to_rad(float(r[2]))
			ends[role] = [Vector3(p[1], 0, p[3]), Vector3(-sin(yaw), 0, -cos(yaw))]
		var a: Array = ends["attacker"]
		var d: Array = ends["defender"]
		var gap: float = (d[0] - a[0]).length()
		assert_float(gap).override_failure_message("%s ends %.2f m apart" % [id, gap]).is_between(0.75, 1.1)
		var a_to_d: Vector3 = (d[0] - a[0]).normalized()
		assert_float((a[1] as Vector3).dot(a_to_d)).override_failure_message(
				"%s: the holder ends facing away" % id).is_greater(0.9)
		assert_float((d[1] as Vector3).dot(-a_to_d)).override_failure_message(
				"%s: the man held ends facing away" % id).is_greater(0.9)


func _chain_pair(swapped: bool) -> Array[WrestlerController]:
	const WRESTLER := preload("res://scenes/wrestler.tscn")
	var a: WrestlerController = auto_free(WRESTLER.instantiate())
	var b: WrestlerController = auto_free(WRESTLER.instantiate())
	var pair_root: Node3D = auto_free(Node3D.new())
	add_child(pair_root)
	a.name = &"WrestlerA"
	b.name = &"WrestlerB"
	var rig := GrappleRig.new()
	var trajectories := AnimationPlayer.new()
	trajectories.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	trajectories.add_animation_library(&"", preload("res://resources/animations/paired_moves.tres"))
	rig.add_child(trajectories)
	rig.animation_player = trajectories
	pair_root.add_child(rig)
	var holder := b if swapped else a
	var held := a if swapped else b
	for wrestler: WrestlerController in [a, b]:
		pair_root.add_child(wrestler)
		wrestler.set_physics_process(false)
		wrestler.is_ai = false
		wrestler.grapple_rig = rig
		wrestler.opponent = held if wrestler == holder else holder
		wrestler.fsm.transition_to(WrestlerFSM.State.TIE_UP)
	holder.position.x = -0.45
	held.position.x = 0.45
	holder.combat.record_tier(0)
	holder._is_grapple_attacker = true
	holder.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	held.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	return [holder, held]


func _chain_tick(holder: WrestlerController, held: WrestlerController,
		swapped: bool, holder_input: Dictionary, held_input: Dictionary) -> void:
	var referee := MatchReferee.new()
	referee.wrestler_a = held if swapped else holder
	referee.wrestler_b = holder if swapped else held
	holder._read_reversal(holder_input)
	held._read_reversal(held_input)
	holder._chain_input_this_tick = holder_input
	held._chain_input_this_tick = held_input
	referee._resolve_tick()
	referee.free()


func test_window_edges_start_the_paired_counter_once_in_either_slot() -> void:
	var window := WrestlerController.CHAIN_REVERSAL_WINDOW
	for swapped: bool in [false, true]:
		for tick: int in [window.x, window.y]:
			var pair := _chain_pair(swapped)
			var holder := pair[0]
			var held := pair[1]
			holder._chain_read = tick
			var health_before := holder.combat.health()
			_chain_tick(holder, held, swapped, {"chain": "headlock"}, {"reversal": true})
			assert_bool(held.grapple_rig.is_active()).is_true()
			assert_bool(holder._is_grapple_attacker).is_false()
			assert_bool(held._is_grapple_attacker).is_true()
			assert_str(held.chain_hold).is_equal("waistlock")
			assert_int(held.chain_reversals).is_equal(1)
			assert_int(held._reversal_lockout).is_equal(0)
			assert_float(held.combat.stamina).is_equal_approx(
					1.0 - CombatSystem.STAMINA_REVERSAL, 0.0001)

			_chain_tick(held, holder, not swapped, {}, {"reversal": true})
			assert_int(holder.chain_reversals).is_equal(0)

			var played := false
			var landed: Array[MoveDef] = []
			held.chain_hold_landed.connect(func(_a, _d, move): landed.append(move))
			for _tick in 160:
				if not held.grapple_rig.is_active():
					break
				await get_tree().physics_frame
				if held.grapple_rig.animation_player.current_animation == &"chain_waistlock":
					played = true
			assert_bool(played).is_true()
			assert_array(landed).is_equal([WrestlerController.CHAIN_HOLDS["waistlock"]])
			assert_float(holder.combat.health()).is_less(health_before)
			assert_str(held.chain_hold).is_empty()
			assert_int(held._chain_read).is_equal(0)
			assert_int(held.fsm.current_state).is_equal(WrestlerFSM.State.GRAPPLE_HOLD)
			assert_int(holder.fsm.current_state).is_equal(WrestlerFSM.State.GRAPPLE_HOLD)


func test_an_outside_window_read_cannot_steal_the_hold_or_charge_twice() -> void:
	var window := WrestlerController.CHAIN_REVERSAL_WINDOW
	for swapped: bool in [false, true]:
		for tick: int in [window.x - 1, window.y + 1]:
			var pair := _chain_pair(swapped)
			var holder := pair[0]
			var held := pair[1]
			holder._chain_read = tick
			_chain_tick(holder, held, swapped, {"chain": "wristlock"}, {"reversal": true})
			assert_bool(held.grapple_rig.is_active()).is_false()
			assert_bool(held._chain_reversal_spent).is_true()
			_chain_tick(holder, held, swapped, {}, {"reversal": true})
			assert_int(held.chain_reversals).is_equal(0)
			assert_float(held.combat.stamina).is_equal_approx(
					1.0 - CombatSystem.STAMINA_REVERSAL, 0.0001)
			holder._chain_read = WrestlerController.CHAIN_READ_TICKS - 1
			_chain_tick(holder, held, swapped, {}, {})
			assert_bool(holder.grapple_rig.is_active()).is_true()
			assert_str(holder.chain_hold).is_equal("wristlock")
			holder.grapple_rig.cancel()
	# Let the cancelled lead-in observe the cancellation before freeing its rig.
	await get_tree().physics_frame


func test_counter_cancelled_at_rig_start_clears_both_roles_and_its_callback() -> void:
	for swapped: bool in [false, true]:
		var pair := _chain_pair(swapped)
		var holder := pair[0]
		var held := pair[1]
		var rig := holder.grapple_rig
		rig.grapple_started.connect(func(_a, _d, _move): rig.cancel(), CONNECT_ONE_SHOT)
		holder._chain_read = WrestlerController.CHAIN_REVERSAL_WINDOW.x
		_chain_tick(holder, held, swapped, {}, {"reversal": true})
		assert_bool(rig.is_active()).is_false()
		assert_bool(rig.grapple_finished.is_connected(held._on_chain_link_finished)).is_false()
		for wrestler: WrestlerController in pair:
			assert_int(wrestler.fsm.current_state).is_equal(WrestlerFSM.State.IDLE)
			assert_bool(wrestler._is_grapple_attacker).is_false()
			assert_float(wrestler.combat.health()).is_equal(1.0)


func test_an_interrupted_read_releases_the_other_wrestler() -> void:
	for holder_leaves: bool in [false, true]:
		var pair := _chain_pair(false)
		var holder := pair[0]
		var held := pair[1]
		var leaving := holder if holder_leaves else held
		leaving.fsm.transition_to(WrestlerFSM.State.IDLE)
		_chain_tick(holder, held, false, {}, {"reversal": true})
		for wrestler: WrestlerController in pair:
			assert_int(wrestler.fsm.current_state).is_equal(WrestlerFSM.State.IDLE)
			assert_bool(wrestler._is_grapple_attacker).is_false()
			assert_int(wrestler.chain_reversals).is_equal(0)


func test_leaving_the_hold_during_counter_playback_cancels_the_pair() -> void:
	for holder_leaves: bool in [false, true]:
		var pair := _chain_pair(false)
		var holder := pair[0]
		var held := pair[1]
		var rig := holder.grapple_rig
		holder._chain_read = WrestlerController.CHAIN_REVERSAL_WINDOW.x
		_chain_tick(holder, held, false, {}, {"reversal": true})
		assert_bool(rig.is_active()).is_true()
		var leaving := held if holder_leaves else holder
		leaving.fsm.transition_to(WrestlerFSM.State.IDLE)
		_chain_tick(held, holder, true, {}, {})
		assert_bool(rig.is_active()).is_false()
		assert_bool(rig.grapple_finished.is_connected(held._on_chain_link_finished)).is_false()
		for wrestler: WrestlerController in pair:
			assert_int(wrestler.fsm.current_state).is_equal(WrestlerFSM.State.IDLE)
			assert_bool(wrestler._is_grapple_attacker).is_false()
			assert_float(wrestler.combat.health()).is_equal(1.0)
			assert_bool(wrestler._active_move == null).is_true()
	await get_tree().physics_frame
