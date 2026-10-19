extends GdUnitTestSuite
## The rocket launcher's damage to the building (VenueDamage): what a rocket
## runs into, what a blast wrecks, and that it stays wrecked and the fires
## stay lit (the owner, 19 Oct).

const MATCH_SCENE := "res://scenes/match.tscn"


func _match() -> Node:
	var scene: Node = auto_free(load(MATCH_SCENE).instantiate())
	MatchRules.set_mode(scene, MatchRules.Mode.NO_HOLDS_BARRED)
	add_child(scene)
	return scene


func _target(d: VenueDamage, target_name: String) -> VenueDamage.Target:
	for t: VenueDamage.Target in d.targets:
		if t.name == target_name:
			return t
	return null


func test_the_match_registers_every_piece_a_rocket_can_wreck() -> void:
	var scene := _match()
	await get_tree().process_frame
	var d := VenueDamage.of(scene.get_node("WrestlerA"))
	d.ensure_targets()
	var kinds := {}
	for t: VenueDamage.Target in d.targets:
		kinds[t.kind] = int(kinds.get(t.kind, 0)) + 1
	assert_int(int(kinds.get(VenueDamage.Kind.BARRICADE, 0))).is_equal(ArenaBuilder.barricade_panels().size())
	assert_int(int(kinds.get(VenueDamage.Kind.DESK, 0))).is_equal(1)
	assert_int(int(kinds.get(VenueDamage.Kind.RING_POST, 0))).is_equal(4)
	assert_int(int(kinds.get(VenueDamage.Kind.RING_APRON, 0))).is_equal(4)
	assert_int(int(kinds.get(VenueDamage.Kind.RING_STEPS, 0))).is_equal(2)
	assert_int(int(kinds.get(VenueDamage.Kind.SCREEN, 0))).is_equal(3)


func test_a_rocket_at_the_desk_wrecks_it_for_good() -> void:
	var scene := _match()
	await get_tree().process_frame
	var d := VenueDamage.of(scene.get_node("WrestlerA"))
	d.ensure_targets()
	var desk := scene.find_child("CommentaryDeskTop", true, false) as MeshInstance3D
	var before := desk.mesh.get_faces().size()
	# fired from the ring straight at it
	var hit := d.ray(Vector3(0.0, 0.8, 2.0), Vector3(0.0, -0.2, 12.0))
	assert_bool(hit.is_empty()).is_false()
	assert_object(hit["target"]).is_not_null()
	assert_str((hit["target"] as VenueDamage.Target).name).is_equal("CommentaryDesk")
	d.blast(hit["point"], hit["normal"], hit["target"])
	assert_bool(_target(d, "CommentaryDesk").damaged).is_true()
	# its worktop gone from the venue mesh, the damaged desk standing there
	assert_int(desk.mesh.get_faces().size()).is_less(before)
	assert_object(d.get_node_or_null("Damaged_CommentaryDesk")).is_not_null()
	# a second rocket does not rebuild or duplicate it
	d.blast(hit["point"], hit["normal"], hit["target"])
	assert_int(d.find_children("Damaged_CommentaryDesk*", "", false, false).size()).is_equal(1)


func test_a_blast_by_a_barricade_blows_that_panel_open() -> void:
	var scene := _match()
	await get_tree().process_frame
	var d := VenueDamage.of(scene.get_node("WrestlerA"))
	d.ensure_targets()
	var panel: Array = ArenaBuilder.barricade_panels()[0]
	var at: Vector3 = panel[0]
	d.blast(Vector3(at.x, ArenaBuilder.FLOOR_Y + 0.6, at.z) - (panel[2] as Vector3) * 0.3,
			-(panel[2] as Vector3))
	assert_bool(_target(d, "Barricade00").damaged).is_true()
	assert_object(d.get_node_or_null("Damaged_Barricade00")).is_not_null()


func test_a_screen_hit_smashes_it_and_starts_a_fire_that_never_goes_out() -> void:
	var scene := _match()
	await get_tree().process_frame
	var d := VenueDamage.of(scene.get_node("WrestlerA"))
	d.ensure_targets()
	var wall := _target(d, "SideScreenR")
	var face := wall.box * Vector3(0.0, 0.0, wall.half.z)
	# from the deck in front of it
	var hit := d.ray(face + wall.box.basis.z * 4.0, face - wall.box.basis.z)
	assert_object(hit.get("target")).is_same(wall)
	d.blast(hit["point"], hit["normal"], hit["target"])
	assert_int(wall.overlays.size()).is_equal(1)
	assert_int(d.fires.size()).is_equal(1)
	for i in 30:
		await get_tree().process_frame
	var flames := d.fires[0].get_node("Flames") as GPUParticles3D
	assert_bool(flames.emitting).is_true()
	assert_bool(flames.one_shot).is_false()


func test_a_rocket_into_the_crowd_sets_it_alight() -> void:
	var scene := _match()
	await get_tree().process_frame
	var d := VenueDamage.of(scene.get_node("WrestlerA"))
	# out over the barricade on the hard-camera side, low
	var hit := d.ray(Vector3(4.0, 1.0, 0.0), Vector3(20.0, 0.5, 0.0))
	assert_bool(bool(hit.get("crowd", false))).is_true()
	d.blast(hit["point"], hit["normal"], null, true)
	assert_int(d.fires.size()).is_equal(1)
	# another beside it feeds the same fire
	d.blast(hit["point"] + Vector3(0.0, 0.0, 0.8), Vector3.UP, null, true)
	assert_int(d.fires.size()).is_equal(1)
	assert_float(d.fires[0].scale.x).is_greater(1.0)


func test_cutting_a_box_takes_only_the_triangles_inside_it() -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.0, 1.0, 1.0)
	box.subdivide_width = 7
	mi.mesh = box
	add_child(mi)
	auto_free(mi)
	var before := mi.mesh.get_faces().size() / 3
	var removed := VenueDamage.cut_box(mi, Transform3D(Basis(), Vector3(1.5, 0.0, 0.0)), Vector3(0.5, 1.0, 1.0))
	assert_int(removed).is_greater(0)
	assert_int(mi.mesh.get_faces().size() / 3).is_equal(before - removed)
	assert_int(VenueDamage.cut_box(mi, Transform3D(Basis(), Vector3(9.0, 0.0, 0.0)), Vector3.ONE)).is_equal(0)


func test_a_rocket_that_goes_wide_flies_on_into_the_building() -> void:
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.global_position = Vector3(0.0, 0.0, 0.0)
	b.global_position = Vector3(0.0, 0.0, 2.0)
	var rpg := WeaponStock.of(a).pull(WeaponCatalog.by_id(&"rpg"))
	a.take_weapon(rpg)
	a._launcher_miss = Vector2(15.0, -2.0)
	assert_bool(a._ranged_reaches()).is_false()       # a miss never hurts him
	rpg.global_transform = WeaponActor.grip_frame(a) * rpg.marker("grip_r").affine_inverse()
	rpg.fire(1, a, a._launcher_miss)
	var d := VenueDamage.of(a)
	for i in 240:
		await get_tree().physics_frame
		if not d.history.is_empty() or not d.fires.is_empty() or d.find_children("Scorch*", "", false, false).size() > 0:
			break
	assert_int(d.find_children("Scorch*", "", false, false).size()).is_greater(0)


func test_misses_are_rolled_from_the_seed() -> void:
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	a.match_seed = 77
	var first: Array = []
	for i in 40:
		first.append(a._launcher_miss_roll())
	a._launcher_shots = 0
	var misses := 0
	for i in 40:
		var m: Vector2 = a._launcher_miss_roll()
		assert_vector(m).is_equal(first[i])
		if m != Vector2.ZERO:
			misses += 1
			assert_float(absf(m.x)).is_between(WrestlerController.LAUNCHER_MISS_YAW.x,
					WrestlerController.LAUNCHER_MISS_YAW.y)
	assert_int(misses).is_between(8, 28)


func test_a_post_hit_takes_the_post_and_its_pads_out_of_the_ring_model() -> void:
	var scene := _match()
	await get_tree().process_frame
	var d := VenueDamage.of(scene.get_node("WrestlerA"))
	d.ensure_targets()
	var post := _target(d, "PostES")
	assert_object(post).is_not_null()
	var ring := scene.find_child("RingMeshes", true, false)
	var before := {}
	for part: String in ["PostMesh", "TurnbucklePads"]:
		before[part] = (ring.find_child(part, true, false) as MeshInstance3D).mesh.get_faces().size()
	d.blast(post.box.origin, Vector3.UP, post)
	for part: String in ["PostMesh", "TurnbucklePads"]:
		assert_int((ring.find_child(part, true, false) as MeshInstance3D).mesh.get_faces().size()) \
				.override_failure_message("%s untouched" % part).is_less(int(before[part]))
	assert_object(d.get_node_or_null("Damaged_PostES")).is_not_null()
