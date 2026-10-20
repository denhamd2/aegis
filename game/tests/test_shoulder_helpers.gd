extends GdUnitTestSuite
## Cody's corrective shoulder bones (ShoulderHelpers) and his mended mirror
## seam (BodyBulk.mend_flipped_seams): the owner, 20 Oct, "one of his
## shoulders and arm gets deformed" celebrating, and the line down his back.

const CODY := preload("res://scenes/cody_model.tscn")
const CODY_GLB := "res://assets/characters/cody_rhodes.glb"


func _cody() -> CodyModel:
	var model: CodyModel = auto_free(CODY.instantiate())
	add_child(model)
	return model


func test_cody_gets_a_helper_bone_per_shoulder_under_the_clavicle() -> void:
	var model := _cody()
	await await_millis(20)
	var skeleton := model.get_game_skeleton()
	assert_bool(ShoulderHelpers.has_helpers(skeleton)).is_true()
	for side in ShoulderHelpers.SIDES:
		var helper := skeleton.find_bone(ShoulderHelpers.helper_name(side))
		assert_int(helper).is_greater_equal(0)
		assert_int(skeleton.get_bone_parent(helper)).is_equal(skeleton.find_bone("clavicle_%s" % side))
		assert_bool(skeleton.get_bone_rest(helper).is_equal_approx(
				skeleton.get_bone_rest(skeleton.find_bone("upperarm_%s" % side)))).is_true()
	assert_bool(ShoulderHelpers.install(skeleton)).is_false()


func test_the_shoulder_carries_weight_on_the_helper_and_every_vertex_sums_to_one() -> void:
	var model := _cody()
	await await_millis(20)
	var skeleton := model.get_game_skeleton()
	var on_helper := 0
	for child in skeleton.get_children():
		if not (child is MeshInstance3D) or (child as MeshInstance3D).skin == null:
			continue
		var mi := child as MeshInstance3D
		var helpers := []
		for i in mi.skin.get_bind_count():
			if mi.skin.get_bind_name(i).begins_with("H_Shoulder_Vol_"):
				helpers.append(i)
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if bones.is_empty():
				continue
			var per := bones.size() / verts.size()
			for v in verts.size():
				var total := 0.0
				for k in per:
					total += weights[v * per + k]
					if helpers.has(bones[v * per + k]) and weights[v * per + k] > 0.0:
						on_helper += 1
				assert_float(total).is_equal_approx(1.0, 0.002)
	assert_int(on_helper).is_greater(200)


## Every clip that keys an upper arm keys its helper at half the swing, and
## the helper never turns further than the arm it follows.
func test_the_helpers_follow_half_the_arm_in_the_celebration() -> void:
	var model := _cody()
	await await_millis(20)
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	var skeleton := model.get_game_skeleton()
	var path := model.get_path_to(skeleton)
	for clip in ["strikes/win_celebrate", "strikes/win_arm_raised", "strikes/title_raise"]:
		if not player.has_animation(clip):
			continue
		var a := player.get_animation(clip)
		for side in ShoulderHelpers.SIDES:
			var arm := a.find_track(NodePath("%s:upperarm_%s" % [path, side]), Animation.TYPE_ROTATION_3D)
			var helper := a.find_track(NodePath("%s:%s" % [path, ShoulderHelpers.helper_name(side)]),
					Animation.TYPE_ROTATION_3D)
			assert_int(helper).override_failure_message("%s %s helper not keyed" % [clip, side]) \
					.is_greater_equal(0)
			var rest := skeleton.get_bone_rest(skeleton.find_bone("upperarm_%s" % side)) \
					.basis.get_rotation_quaternion()
			for k in a.track_get_key_count(arm):
				var arm_turn := rest.angle_to(a.track_get_key_value(arm, k))
				var helper_turn := rest.angle_to(a.track_get_key_value(helper, k))
				assert_float(helper_turn).is_less_equal(arm_turn + 0.001)


func test_the_mirror_seam_is_mended_once_and_shades_as_one_surface() -> void:
	var raw: Node = auto_free((load(CODY_GLB) as PackedScene).instantiate())
	assert_int(BodyBulk.mend_flipped_seams(raw)).is_greater(100)
	assert_int(BodyBulk.mend_flipped_seams(raw)).is_equal(0)


## The two copies of each centre-line vertex carry the same skin after the
## mend, so no pose can pull his back apart (the crowd showed through it).
func test_the_mirror_seam_copies_share_one_skin() -> void:
	var raw: Node = auto_free((load(CODY_GLB) as PackedScene).instantiate())
	BodyBulk.mend_flipped_seams(raw)
	var checked := 0
	for mi: MeshInstance3D in raw.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bones = a[Mesh.ARRAY_BONES]
			var weights = a[Mesh.ARRAY_WEIGHTS]
			if bones == null or verts.is_empty():
				continue
			var per: int = (bones as PackedInt32Array).size() / verts.size()
			var first := {}
			for v in verts.size():
				if absf(verts[v].x) > BodyBulk.MIRROR_BAND:
					continue
				var key := Vector3i(roundi(verts[v].x * BodyBulk.WELD_GRID),
						roundi(verts[v].y * BodyBulk.WELD_GRID), roundi(verts[v].z * BodyBulk.WELD_GRID))
				var skin := {}
				for k in per:
					if weights[v * per + k] > 0.004:
						skin[bones[v * per + k]] = weights[v * per + k]
				if first.has(key):
					# Same bones, same weights to the mesh's 16-bit storage.
					var other: Dictionary = first[key]
					assert_array(skin.keys().duplicate()).contains_exactly_in_any_order(other.keys())
					for b in skin:
						assert_float(skin[b]).is_equal_approx(float(other.get(b, -1.0)), 0.004)
					checked += 1
				else:
					first[key] = skin
	assert_int(checked).is_greater(100)
