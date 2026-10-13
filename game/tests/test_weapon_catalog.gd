extends GdUnitTestSuite
## The No Holds Barred weapons (gauntlet/refs/weapons_nhb.md): every one in
## the catalogue loads, shows the states it names, can be held by its grip,
## and is inside its triangle budget; and the in-world actor throws, wears
## and breaks the same way every time.

const HAND_HELD_BUDGET := 15000
const SET_PIECE_BUDGET := 20000


func test_there_are_33_weapons_in_six_families() -> void:
	assert_int(WeaponCatalog.all().size()).is_equal(33)
	for f in WeaponDef.Family.values():
		assert_int(WeaponCatalog.in_family(f).size()).is_greater(0)


func test_every_weapon_loads_with_its_states_and_grips() -> void:
	var wrong: Array[String] = []
	for d in WeaponCatalog.all():
		var a := WeaponActor.make(d)
		auto_free(a)
		for state: String in [d.held, d.dented, d.broken, d.set_up]:
			if state != "" and not a.has_state(state):
				wrong.append("%s: no state %s" % [d.id, state])
		for state: String in d.effects.values():
			if not a.has_state(state):
				wrong.append("%s: no effect %s" % [d.id, state])
		if d.id != &"championship_belt" and a.marker("grip_r") == Transform3D.IDENTITY:
			wrong.append("%s: no grip_r" % d.id)
		if d.two_handed and d.id != &"championship_belt" and a.marker("grip_l") == Transform3D.IDENTITY:
			wrong.append("%s: two-handed with no grip_l" % d.id)
	assert_array(wrong).override_failure_message("%s" % [wrong]).is_empty()


func test_every_weapon_is_inside_its_triangle_budget() -> void:
	var over: Array[String] = []
	for d in WeaponCatalog.all():
		var a := WeaponActor.make(d)
		auto_free(a)
		var budget := SET_PIECE_BUDGET if d.family == WeaponDef.Family.SET_PIECES else HAND_HELD_BUDGET
		for state: String in a._roots:
			var tris := 0
			for node in (a._roots[state] as Node3D).find_children("", "MeshInstance3D", true, false):
				var mesh := (node as MeshInstance3D).mesh
				for s in mesh.get_surface_count():
					var arrays := mesh.surface_get_arrays(s)
					var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					tris += idx.size() / 3 if idx.size() > 0 \
							else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			if tris > budget:
				over.append("%s %s: %d" % [d.id, state, tris])
	assert_array(over).override_failure_message("%s" % [over]).is_empty()


func test_every_swing_has_a_move_with_reach() -> void:
	for d in WeaponCatalog.all():
		var m := WeaponCatalog.swing_move(d)
		assert_object(m).is_not_null()
		assert_int(m.total_frames()).is_greater(0)
		assert_bool(String(m.animation_pair_id).begins_with("weapon_")).is_true()


func _thrown() -> Array:
	var a := WeaponActor.make(WeaponCatalog.by_id(&"steel_chair"))
	add_child(a)
	auto_free(a)
	a.global_position = Vector3(4.6, 0.2, 0.0)
	a.throw(Vector3(0.0, 2.0, 3.0), Vector3(4, 0, 0), null, [])
	return [a]


func test_a_thrown_weapon_lands_and_comes_to_rest_on_the_floor() -> void:
	var a: WeaponActor = _thrown()[0]
	for i in 600:
		a._physics_process(1.0 / 60.0)
		if a.mode == WeaponActor.Mode.FLOOR:
			break
	assert_int(a.mode).is_equal(WeaponActor.Mode.FLOOR)
	assert_float(a.global_position.y).is_equal_approx(WeaponActor.ground_under(a.global_position) + 0.02, 0.01)


func test_a_throw_is_the_same_every_time() -> void:
	var a: WeaponActor = _thrown()[0]
	var b: WeaponActor = _thrown()[0]
	for i in 300:
		a._physics_process(1.0 / 60.0)
		b._physics_process(1.0 / 60.0)
	assert_vector(a.global_position).is_equal(b.global_position)


func test_wear_dents_then_a_breakable_one_breaks() -> void:
	var chair := WeaponActor.make(WeaponCatalog.by_id(&"steel_chair"))
	add_child(chair)
	auto_free(chair)
	chair.take(null)
	for i in 3:
		chair.hit(i)
	assert_str(chair.state_root).is_equal("SteelChair_Folded")
	chair.hit(3)
	assert_str(chair.state_root).is_equal("SteelChair_Bent")
	var guitar := WeaponActor.make(WeaponCatalog.by_id(&"guitar"))
	add_child(guitar)
	auto_free(guitar)
	guitar.global_position = Vector3(0, 1.0, 0)
	assert_bool(guitar.hit(7)).is_true()
	assert_int(guitar.mode).is_equal(WeaponActor.Mode.BROKEN)
	assert_str(guitar.state_root).is_equal("Guitar_Broken")
	for i in 400:
		guitar._physics_process(1.0 / 60.0)
	assert_bool(guitar.visible).is_false()
