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
	assert_int(WrestlerController.CHAIN_REVERSAL_HEAD_START).is_less(WrestlerController.CHAIN_READ_TICKS)
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
