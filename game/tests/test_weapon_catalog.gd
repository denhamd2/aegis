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


func test_hockey_stick_uses_its_slapshot_profile() -> void:
	var stick := WeaponCatalog.by_id(&"hockey_stick")
	assert_str(WeaponCatalog.swing_profile(stick)).is_equal("slapshot")
	assert_str(String(WeaponCatalog.swing_move(stick).animation_pair_id)).is_equal("weapon_slapshot")
	assert_bool(WeaponCatalog.swing_path(stick).size() >= 3).is_true()


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
	# lying on the floor: its lowest point on it, not its origin
	var box := a.global_transform * a.local_bounds()
	assert_float(box.position.y).is_equal_approx(WeaponActor.ground_under(a.global_position), 0.02)


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


func test_every_swing_and_weapon_action_has_its_clip() -> void:
	var lib: AnimationLibrary = load("res://resources/animations/strike_clips.tres")
	var names := []
	for d in WeaponCatalog.all():
		names.append(String(WeaponCatalog.swing_move(d).animation_pair_id))
	for clip: String in WrestlerController.WEAPON_ACTION_CLIPS.values():
		names.append(clip.trim_prefix("strikes/"))
	for n: String in names:
		assert_bool(lib.has_animation(n)).override_failure_message("no clip %s" % n).is_true()


## A swing's path starts on the carry and comes back to it, and at the
## contact the business end is out in front of him at head-to-chest height.
func test_every_swing_path_leaves_and_returns_to_the_carry_and_lands_in_front() -> void:
	var chest := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.25, 0.0))
	var rest := Transform3D(Basis.IDENTITY, Vector3(0.3, 1.0, -0.3))
	var checked := 0
	for d in WeaponCatalog.all():
		var keys := WeaponCatalog.swing_path(d)
		if keys.is_empty():
			continue
		var a := WeaponActor.make(d, d.held)
		auto_free(a)
		add_child(a)
		var start := WeaponCatalog.path_transform(a, keys, chest, 0.0, rest)
		var end := WeaponCatalog.path_transform(a, keys, chest, 1.0, rest)
		assert_float(start.origin.distance_to(rest.origin)).is_less(0.001)
		assert_float(end.origin.distance_to(rest.origin)).is_less(0.001)
		var m := WeaponCatalog.swing_move(d)
		var placed := WeaponCatalog.path_transform(a, keys, chest, float(m.startup_frames) / m.total_frames(), rest)
		var axes := WeaponCatalog.swing_axes(a)
		# the point the path steers: the right grip, or between the hands for
		# the wide things swung square (WeaponCatalog.CENTRED_SWING)
		var grip := placed * a.marker("grips" if d.id in WeaponCatalog.CENTRED_SWING else "grip_r").origin
		var tip := grip + placed.basis * (axes[0] as Vector3) * 0.3
		assert_float(-tip.z).override_failure_message("%s lands behind him" % d.id).is_greater(0.45)
		assert_float(tip.y).override_failure_message("%s lands at %.2f" % [d.id, tip.y]).is_between(0.9, 1.9)
		checked += 1
	assert_int(checked).is_greater(25)


func test_every_weapon_has_a_sound_and_its_moves_name_it() -> void:
	for def: WeaponDef in WeaponCatalog.all():
		var heard := SfxPool.family_size(def.sound) > 0 or SfxPool.stream(def.sound) != null
		assert_bool(heard).override_failure_message("%s: no sound '%s'" % [def.id, def.sound]).is_true()
		assert_object(WeaponCatalog.of_move(WeaponCatalog.swing_move(def))).is_same(WeaponCatalog.by_id(def.id))
	assert_int(SfxPool.family_size("table_crack")).is_greater(0)
