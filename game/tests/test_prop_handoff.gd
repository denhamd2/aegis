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


## Roman then Cody: the belt, the necklace and the coat all reach the table.
func _both_match() -> Dictionary:
	var scene: Node = load(MATCH).instantiate()
	scene.entrances = true
	(scene.get_node("WrestlerA") as WrestlerController).entrance_style = "roman"
	(scene.get_node("WrestlerB") as WrestlerController).entrance_style = "cody"
	add_child(scene)
	auto_free(scene)
	return {"scene": scene,
			"director": scene.get_node("EntranceDirector"),
			"ref": scene.get_node("RefereeActor"),
			"keeper": scene.get_node("Timekeeper"),
			"handoff": scene.get_node("PropHandoff"),
			"roman": scene.get_node("WrestlerA"),
			"cody": scene.get_node("WrestlerB")}


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


func test_cody_s_coat_is_handed_on_and_lies_on_the_table() -> void:
	var m := _both_match()
	var handoff: PropHandoff = m["handoff"]
	var director: EntranceDirector = m["director"]
	var cody: WrestlerController = m["cody"]
	var last := {}
	var worst := [0.0]
	var most := [0]
	var holders := {}
	var skinned_back := [false]
	var coat_off := [false]
	_run(m, func():
		most[0] = maxi(most[0], handoff.in_motion())
		for c: PropHandoff.Carried in handoff.carried:
			var now := c.pivot.global_position
			if c.kind == "coat":
				if last.has(c):
					worst[0] = maxf(worst[0], now.distance_to(last[c]))
				last[c] = now
				var h := String(c.holder.get("type", ""))
				if h == "bone":
					h = "%s:%s" % [(c.holder["actor"] as Node).name, c.holder["bone"]]
				holders[h] = true
		var coat: EntranceCoat = director._coats.get(cody)
		if coat and coat._root:
			if coat._root.visible and coat_off[0]:
				skinned_back[0] = true
			if not coat._root.visible:
				coat_off[0] = true)
	# One at a time, each by the whole sequence (the order is the card's).
	var sorted := handoff.delivered.duplicate()
	sorted.sort()
	assert_array(sorted).is_equal(["coat", "fala", "title"])
	assert_int(handoff.completed).is_equal(3)
	assert_int(most[0]).override_failure_message("two props in transit at once").is_equal(1)
	assert_float(worst[0]).override_failure_message(
			"the coat moved %.3f m in one tick" % worst[0]).is_less(MAX_STEP)
	assert_bool(coat_off[0]).is_true()
	assert_bool(skinned_back[0]).override_failure_message("the worn coat came back").is_false()
	# Cody's hand, Aubrey's hand and shoulder, the keeper's, the table.
	assert_bool(holders.has("table")).is_true()
	assert_int(holders.size()).is_greater_equal(4)
	var table: Vector3 = PropHandoff.TABLE_AT
	var zs := {}
	for c: PropHandoff.Carried in handoff.carried:
		assert_bool(c.on_table()).override_failure_message("%s is not on the table" % c.kind).is_true()
		var p := c.pivot.global_position
		assert_float(absf(p.z - table.z)).is_less(Timekeeper.TABLE_SIZE.z * 0.5)
		zs[c.kind] = p.z
	var coat_c: PropHandoff.Carried = null
	for c: PropHandoff.Carried in handoff.carried:
		if c.kind == "coat":
			coat_c = c
	assert_object(coat_c).is_not_null()
	# The coat is flat on the top, and clear of the belt and the necklace.
	assert_float(coat_c.pivot.global_position.y - (table.y + Timekeeper.TABLE_SIZE.y)).is_between(0.0, 0.1)
	assert_float(absf(zs["coat"] - zs["title"])).is_greater(0.3)
	assert_float(absf(zs["coat"] - zs["fala"])).is_greater(0.3)
	# Their footprints along the table do not overlap.
	var spans := {}
	for c: PropHandoff.Carried in handoff.carried:
		var lo := INF
		var hi := -INF
		for mi: MeshInstance3D in c.pivot.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			var box := mi.global_transform * mi.get_aabb()
			lo = minf(lo, box.position.z)
			hi = maxf(hi, box.end.z)
		spans[c.kind] = Vector2(lo, hi)
	for pair: Array in [["coat", "title"], ["coat", "fala"], ["title", "fala"]]:
		var a: Vector2 = spans[pair[0]]
		var b: Vector2 = spans[pair[1]]
		assert_bool(a.y < b.x or b.y < a.x).override_failure_message(
				"%s %s overlaps %s %s" % [pair[0], a, pair[1], b]).is_true()
	# One coat, in one place: the prop sits under exactly one pivot.
	var count := 0
	for n in m["scene"].find_children("FoldedCoat", "Node3D", true, false):
		count += 1
		# ...and it is where its pivot is (carried by it, not left behind).
		assert_vector((n as Node3D).global_position).is_equal_approx(
				coat_c.pivot.global_position, Vector3.ONE * 0.01)
		assert_object(n.get_parent()).is_same(coat_c.pivot)
	assert_int(count).is_equal(1)


func test_skipping_after_the_coat_is_called_puts_it_on_the_table() -> void:
	var m := _both_match()
	var director: EntranceDirector = m["director"]
	var handoff: PropHandoff = m["handoff"]
	var ticks := 0
	var called := false
	while not called and ticks < 40000:
		_step(m)
		ticks += 1
		for c: PropHandoff.Carried in handoff.carried:
			if c.kind == "coat":
				called = true
	director.skip()
	assert_bool(called).is_true()
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
