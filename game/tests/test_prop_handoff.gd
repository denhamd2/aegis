extends GdUnitTestSuite
## The props at Roman's entrance (PropHandoff): the belt and the ula fala go
## wrestler -> Aubrey -> timekeeper -> table, one at a time, each in a hand, on
## a shoulder or on the table at every tick -- never hidden, never a pop.
##
## Driven by hand: the director, Aubrey, the timekeeper, the hand-off and every
## AnimationPlayer are stepped here at 60 Hz, because a headless test has no
## frames to run them.

const MATCH := "res://scenes/match.tscn"
const DT := 1.0 / 60.0
## The fastest a prop may move in one tick without it being a pop: a hand
## swinging a belt is ~4 m/s; this is 12.
const MAX_STEP := 0.20


func _roman_match() -> Dictionary:
	var scene: Node = load(MATCH).instantiate()
	scene.entrances = true
	(scene.get_node("WrestlerA") as WrestlerController).entrance_style = "roman"
	(scene.get_node("WrestlerB") as WrestlerController).entrance_style = ""
	add_child(scene)
	auto_free(scene)
	return {"scene": scene,
			"director": scene.get_node("EntranceDirector"),
			"ref": scene.get_node("RefereeActor"),
			"keeper": scene.get_node("Timekeeper"),
			"handoff": scene.get_node("PropHandoff"),
			"roman": scene.get_node("WrestlerA")}


func _step(m: Dictionary) -> void:
	(m["director"] as EntranceDirector)._physics_process(DT)
	(m["ref"] as RefereeActor)._process(DT)
	(m["keeper"] as Timekeeper)._process(DT)
	(m["handoff"] as PropHandoff)._process(DT)
	for p: AnimationPlayer in [(m["ref"] as RefereeActor)._player,
			(m["keeper"] as Timekeeper)._player]:
		if p:
			p.advance(DT)


## Runs the whole entrance, calling `each` every tick; returns the ticks run.
func _run(m: Dictionary, each: Callable) -> int:
	var rang := [false]
	(m["director"] as EntranceDirector).bell.connect(func(): rang[0] = true)
	var ticks := 0
	while not rang[0] and ticks < 40000:
		_step(m)
		ticks += 1
		each.call()
	return ticks


func test_the_stand_for_helper_puts_two_hands_on_one_point() -> void:
	# He faces +Z with his left hand out; she faces him with her right.
	var giver := Vector3(-0.4, 0.0, -0.6)
	var gf := Vector3(0, 0, 1)
	var spot := PropHandoff.stand_for(giver, gf, PropHandoff.HAND_L, PropHandoff.REF_RECEIVE)
	var his := giver + gf.cross(Vector3.UP) * PropHandoff.HAND_L.x + gf * PropHandoff.HAND_L.y
	var tf := -gf
	var hers := spot + tf.cross(Vector3.UP) * PropHandoff.REF_RECEIVE.x + tf * PropHandoff.REF_RECEIVE.y
	assert_vector(hers).is_equal_approx(his, Vector3.ONE * 0.001)
	# Roman's other hand puts her somewhere else.
	var other := PropHandoff.stand_for(giver, gf, PropHandoff.HAND_R, PropHandoff.REF_RECEIVE)
	assert_float(other.distance_to(spot)).is_greater(0.2)


func test_both_props_end_on_the_table_in_order() -> void:
	var m := _roman_match()
	var handoff: PropHandoff = m["handoff"]
	var seen := {}
	var tick := [0]
	_run(m, func():
		tick[0] += 1
		var key := "%d" % handoff.step
		if not seen.has(key):
			seen[key] = tick[0]
			print("HANDOFF step ", key, " at tick ", tick[0], " beat ", (m["director"] as EntranceDirector)._beat,
					" ref ", (m["ref"] as RefereeActor).global_position, " mode ", (m["ref"] as RefereeActor).mode,
					" roman ", (m["roman"] as WrestlerController).global_position))
	assert_array(handoff.delivered).is_equal(["title", "fala"])
	# By the whole sequence, not by the bell cutting it short.
	assert_int(handoff.completed).is_equal(2)
	assert_int(handoff.carried.size()).is_equal(2)
	for c: PropHandoff.Carried in handoff.carried:
		assert_bool(c.on_table()).override_failure_message("%s is not on the table" % c.kind).is_true()
		var p := c.pivot.global_position
		var table: Vector3 = PropHandoff.TABLE_AT
		assert_float(absf(p.x - table.x)).is_less(Timekeeper.TABLE_SIZE.x * 0.5 + 0.05)
		assert_float(absf(p.z - table.z)).is_less(Timekeeper.TABLE_SIZE.z * 0.5)
		assert_float(p.y - (table.y + Timekeeper.TABLE_SIZE.y)).is_between(-0.02, 0.2)
	assert_bool(handoff.is_idle()).is_true()


func test_one_prop_at_a_time_and_never_hidden_or_popping() -> void:
	var m := _roman_match()
	var handoff: PropHandoff = m["handoff"]
	var last := {}
	var worst := [0.0]
	var most := [0]
	var hidden := []
	_run(m, func():
		most[0] = maxi(most[0], handoff.in_motion())
		for c: PropHandoff.Carried in handoff.carried:
			if not c.pivot.is_inside_tree():
				hidden.append("%s left the tree" % c.kind)
			for child in c.pivot.get_children():
				if child is Node3D and not (child as Node3D).visible:
					hidden.append("%s hidden" % c.kind)
			var now := c.pivot.global_position
			if last.has(c):
				worst[0] = maxf(worst[0], now.distance_to(last[c]))
			last[c] = now)
	assert_int(most[0]).override_failure_message("two props in transit at once").is_equal(1)
	assert_array(hidden).override_failure_message("%s" % [hidden.slice(0, 3)]).is_empty()
	assert_float(worst[0]).override_failure_message(
			"a prop moved %.3f m in one tick" % worst[0]).is_less(MAX_STEP)


## Nobody walks through anybody: the three of them stay a body apart on the
## ground plane, except the ones on purpose at arm's length.
func test_nobody_walks_through_anybody() -> void:
	var m := _roman_match()
	var worst := [9.0]
	var ref: RefereeActor = m["ref"]
	var keeper: Timekeeper = m["keeper"]
	var roman: WrestlerController = m["roman"]
	var other: WrestlerController = m["scene"].get_node("WrestlerB")
	_run(m, func():
		for pair: Array in [[ref, keeper], [ref, roman], [keeper, roman], [ref, other]]:
			var a: Vector3 = (pair[0] as Node3D).global_position
			var b: Vector3 = (pair[1] as Node3D).global_position
			if pair[1] == roman or pair[1] == other:
				if not (pair[1] as Node3D).visible:
					continue
			worst[0] = minf(worst[0], Vector2(a.x - b.x, a.z - b.z).length()))
	assert_float(worst[0]).override_failure_message(
			"two bodies came within %.2f m" % worst[0]).is_greater(0.45)


func test_aubrey_is_back_at_her_spot_when_the_bell_goes() -> void:
	var m := _roman_match()
	_run(m, func(): pass)
	var ref: RefereeActor = m["ref"]
	assert_bool(ref.mode == RefereeActor.Mode.PARK or ref.mode == RefereeActor.Mode.FOLLOW).is_true()


func test_skipping_the_entrance_puts_the_props_on_the_table_not_nowhere() -> void:
	var m := _roman_match()
	var director: EntranceDirector = m["director"]
	var handoff: PropHandoff = m["handoff"]
	# Run until the belt is taken, then skip.
	var ticks := 0
	while handoff.carried.is_empty() and ticks < 20000:
		_step(m)
		ticks += 1
	director.skip()
	for c: PropHandoff.Carried in handoff.carried:
		assert_bool(c.on_table()).is_true()
	assert_bool(handoff.is_idle()).is_true()


func test_the_timekeeper_has_a_table_with_a_bell() -> void:
	var m := _roman_match()
	var keeper: Timekeeper = m["keeper"]
	assert_object(keeper.table).is_not_null()
	assert_object(keeper.table.get_node_or_null("Bell")).is_not_null()
	assert_vector(keeper.table.global_position).is_equal_approx(PropHandoff.TABLE_AT, Vector3.ONE * 0.01)


## The necklace is held by its neck: the grip has to be found on the rig it is
## built on, or it would float a metre and a half above whoever carries it.
func test_the_necklace_is_carried_by_its_neck() -> void:
	var m := _roman_match()
	var director: EntranceDirector = m["director"]
	var handoff: PropHandoff = m["handoff"]
	var props: EntranceProps
	var guard := 0
	while handoff.carried.size() < 2 and guard < 40000:
		_step(m)
		guard += 1
		for p in director._props.values():
			props = p
	assert_float(props.fala_neck_rest().y).is_greater(0.8)
	var fala: PropHandoff.Carried = handoff.carried[1]
	assert_str(fala.kind).is_equal("fala")
	# Its mesh sits within a metre of the point it is held by, not 1.4 m above.
	for mi: MeshInstance3D in fala.pivot.find_children("*", "MeshInstance3D", true, false):
		var centre := mi.global_transform * mi.get_aabb().get_center()
		assert_float(centre.distance_to(fala.pivot.global_position)).is_less(0.6)
