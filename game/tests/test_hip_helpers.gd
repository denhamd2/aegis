extends GdUnitTestSuite
## Cody's corrective hip bones (HipHelpers): added at load, weighted onto the
## hip band, animated at half the thigh's swing.

const CODY := preload("res://scenes/cody_model.tscn")

func _cody() -> CodyModel:
	var model: CodyModel = auto_free(CODY.instantiate())
	add_child(model)
	return model

func test_cody_gets_a_helper_bone_per_hip_under_the_pelvis() -> void:
	var model := _cody()
	await await_millis(20)
	var skeleton := model.get_game_skeleton()
	assert_bool(HipHelpers.has_helpers(skeleton)).is_true()
	for side in ["l", "r"]:
		var helper := skeleton.find_bone(HipHelpers.helper_name(side))
		assert_int(helper).is_greater_equal(0)
		assert_int(skeleton.get_bone_parent(helper)).is_equal(skeleton.find_bone("pelvis"))
		assert_bool(skeleton.get_bone_rest(helper).is_equal_approx(
				skeleton.get_bone_rest(skeleton.find_bone("thigh_%s" % side)))).is_true()

func test_installing_twice_does_not_add_more_bones() -> void:
	var model := _cody()
	await await_millis(20)
	var skeleton := model.get_game_skeleton()
	var count := skeleton.get_bone_count()
	assert_bool(HipHelpers.install(skeleton)).is_false()
	assert_int(skeleton.get_bone_count()).is_equal(count)

func test_the_hip_band_carries_weight_on_the_helper_and_every_vertex_still_sums_to_one() -> void:
	var model := _cody()
	await await_millis(20)
	var skeleton := model.get_game_skeleton()
	var on_helper := 0
	for child in skeleton.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if mi.skin == null:
			continue
		var helper_bind := -1
		for i in mi.skin.get_bind_count():
			if mi.skin.get_bind_name(i) == HipHelpers.helper_name("l"):
				helper_bind = i
		if helper_bind < 0:
			continue
		var mesh := mi.mesh as ArrayMesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			for v in bones.size() / per:
				var total := 0.0
				for k in per:
					total += weights[v * per + k]
					if bones[v * per + k] == helper_bind and weights[v * per + k] > 0.05:
						on_helper += 1
				assert_float(total).is_equal_approx(1.0, 0.01)
	assert_int(on_helper).override_failure_message("no vertex weighted onto the left helper").is_greater(100)

func test_the_helper_turns_half_as_far_as_the_thigh() -> void:
	var model := _cody()
	await await_millis(20)
	var skeleton := model.get_game_skeleton()
	var rest := skeleton.get_bone_rest(skeleton.find_bone("thigh_l")).basis.get_rotation_quaternion()
	var swing := Quaternion(Vector3.RIGHT, deg_to_rad(90.0))
	var anim := Animation.new()
	var path := NodePath("%s:thigh_l" % model.get_path_to(skeleton))
	var t := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t, path)
	anim.track_insert_key(t, 0.0, swing * rest)
	HipHelpers.add_tracks(anim, skeleton, model.get_path_to(skeleton))
	var h := anim.find_track(NodePath("%s:%s" % [model.get_path_to(skeleton),
			HipHelpers.helper_name("l")]), Animation.TYPE_ROTATION_3D)
	assert_int(h).is_greater_equal(0)
	var q: Quaternion = anim.track_get_key_value(h, 0)
	assert_float(rad_to_deg((q * rest.inverse()).get_angle())).is_equal_approx(45.0, 0.5)
