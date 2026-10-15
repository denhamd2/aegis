extends GdUnitTestSuite
## Export, placement and light-coverage regressions for the owner's New.png.
## Actual appearance is reviewed from Forward+ captures, not these assertions.

const Look := preload("res://core/arena/textured_crowd_look.gd")


func test_textured_variants_preserve_seat_origins_uvs_masks_and_budget() -> void:
	var root: Node3D = auto_free((load(Look.MODEL) as PackedScene).instantiate())
	var spec := Look.manifest()
	assert_int(spec["variants"].size()).is_equal(24)
	for i in 24:
		var name := "Fan%02d" % i
		var fan := root.find_child(name, true, false) as MeshInstance3D
		assert_object(fan).is_not_null()
		if fan == null:
			continue
		var box := fan.get_aabb()
		assert_float(box.position.y).is_between(-0.02, 0.15)
		assert_float(box.end.y).is_between(1.05, 2.3)
		var arrays := fan.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var arm: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var masks: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert_int(indices.size() / 3).is_less_equal(int(spec["variant_budget"]))
		assert_int(uv.size()).is_equal(points.size())
		assert_int(arm.size()).is_equal(points.size())
		assert_int(masks.size()).is_equal(points.size())
		assert_int(normals.size()).is_equal(points.size())
		assert_int(tangents.size()).is_equal(points.size() * 4)
		var coordinates := {}
		var garment := 0
		var skin := 0
		var bad_normals := 0
		for j in points.size():
			if not normals[j].is_finite() or absf(normals[j].length() - 1.0) > 0.02:
				bad_normals += 1
			coordinates[Vector2i(roundi(uv[j].x * 2048), roundi(uv[j].y * 2048))] = true
			if masks[j].r > 0.5:
				garment += 1
			if masks[j].a > 0.5:
				skin += 1
		assert_int(coordinates.size()).override_failure_message(name + " lost photographic UVs").is_greater(100)
		assert_int(garment).override_failure_message(name + " lost the garment mask").is_greater(20)
		assert_int(skin).override_failure_message(name + " lost the skin mask").is_greater(20)
		assert_float(float(garment) / points.size()).is_between(0.02, 0.7)
		assert_int(bad_normals).override_failure_message(name + " has invalid lighting normals").is_zero()


func _placements(arena: ArenaBuilder) -> Array[String]:
	var out: Array[String] = []
	for node in arena.get_children():
		if node is not MultiMeshInstance3D:
			continue
		var mm: MultiMesh = node.multimesh
		for i in mm.instance_count:
			out.append(str(mm.get_instance_transform(i)) + str(mm.get_instance_custom_data(i)))
	out.sort()
	return out


func test_section_culling_does_not_change_seeded_seats_clothes_or_density() -> void:
	var old: ArenaBuilder = auto_free(ArenaBuilder.new())
	var new: ArenaBuilder = auto_free(ArenaBuilder.new())
	var seats: Array[Transform3D] = []
	for x in 3:
		for z in 5:
			seats.append(Transform3D(Basis.IDENTITY, Vector3(x * 7.0, -1.1, z * 7.0)))
	var meshes: Array[Mesh] = [BoxMesh.new()]
	var material := ShaderMaterial.new()
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = ArenaBuilder.FLOOR_CROWD_SEED
	rng_b.seed = ArenaBuilder.FLOOR_CROWD_SEED
	old._seat_floor_fans(seats, meshes, "Test", rng_a, material)
	new._seat_floor_fans(seats, meshes, "Test", rng_b, material, [material])
	assert_array(_placements(new)).is_equal(_placements(old))
	assert_int(new.get_child_count()).is_greater(old.get_child_count())


func test_audience_washes_and_aisle_accents_stay_off_the_canvas() -> void:
	var rig: ArenaLighting = auto_free(ArenaLighting.new())
	add_child(rig)
	var count := 0
	for node in rig.get_children():
		if node is not SpotLight3D or not (String(node.name).begins_with("AudienceWash")
				or String(node.name).begins_with("AisleAccent")):
			continue
		count += 1
		var axis: Vector3 = -node.global_basis.z
		for x: float in [-3.0, 0.0, 3.0]:
			for z: float in [-3.0, 0.0, 3.0]:
				var offset: Vector3 = Vector3(x, 0.0, z) - node.global_position
				var angle := rad_to_deg(axis.angle_to(offset))
				assert_bool(offset.length() > node.spot_range or angle > node.spot_angle) \
						.override_failure_message(String(node.name) + " reaches the canvas").is_true()
	assert_int(count).is_equal(8)


func test_fixed_aisle_lights_dim_for_entrances_without_becoming_sweeping_beams() -> void:
	var rig: ArenaLighting = auto_free(ArenaLighting.new())
	add_child(rig)
	for node in rig.get_children():
		if node is not SpotLight3D or not String(node.name).begins_with("AisleAccent"):
			continue
		var rest: Transform3D = node.transform
		rig.set_look(ArenaLighting.Look.ENTRANCE)
		var entrance: float = node.light_energy
		rig._move_beams(1.0 / 60.0)
		rig.set_look(ArenaLighting.Look.MATCH)
		assert_that(node.transform).is_equal(rest)
		assert_float(node.light_energy).is_greater(entrance * 4.0)
