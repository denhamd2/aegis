extends GdUnitTestSuite

const FIT := preload("res://core/match/roman_landing_fit.gd")
const MODEL := preload("res://scenes/roman_model.tscn")
const POSES := preload("res://resources/animations/paired_poses.tres")

func _track(animation: Animation, bone: String, type: int) -> int:
	for track in animation.get_track_count():
		if animation.track_get_type(track) == type and String(animation.track_get_path(track).get_concatenated_subnames()) == bone:
			return track
	return -1

func test_fit_respects_both_imported_parent_axes_and_keeps_approach_handoff() -> void:
	var model: RomanModel = auto_free(MODEL.instantiate())
	add_child(model)
	var source_root: Node = auto_free((load(RomanModel.BASE_RIG) as PackedScene).instantiate())
	var source_sk: Skeleton3D = model._source_skeleton(source_root)
	var source: Animation = POSES.get_animation(FIT.CLIP)
	var source_track := _track(source, "pelvis", Animation.TYPE_POSITION_3D)
	var adapted := model.adapt_animation_library(POSES, source_sk)
	var clip := adapted.get_animation(FIT.CLIP)
	for sk: Skeleton3D in model._animation_skeletons():
		var hips := sk.find_bone("J_Hips")
		var parent := sk.get_bone_parent(hips)
		var parent_basis := sk.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
		var frame := model.global_basis.inverse() * sk.global_basis * parent_basis
		var rest: Dictionary = model._rest_pair(source_sk, "pelvis", sk, "J_Hips")
		var track := clip.find_track(NodePath("%s:J_Hips" % model.get_path_to(sk)), Animation.TYPE_POSITION_3D)
		# Includes genuine half-ticks between the original 60Hz keys.
		for half_tick in range(265):
			var seconds := float(half_tick) / 120.0
			var key := source.position_track_interpolate(source_track, seconds)
			var before: Vector3 = model._retarget_key(Animation.TYPE_POSITION_3D, key, rest)
			var delta := frame * (clip.position_track_interpolate(track, seconds) - before)
			assert_float(absf(delta.x)).is_less(0.00001)
			assert_float(absf(delta.z)).is_less(0.00001)
			if seconds <= FIT.START or seconds >= FIT.END:
				assert_float(absf(delta.y)).is_less(0.00001)
			else:
				assert_float(delta.y).is_less_equal(0.00001)
		# Measured retarget fit must be a downward 22.5cm shift at this pose
		# clock, rather than a local-axis sideways correction on worn gear.
		var seconds := 58.5 / 30.0
		var key := source.position_track_interpolate(source_track, seconds)
		var before: Vector3 = model._retarget_key(Animation.TYPE_POSITION_3D, key, rest)
		var delta := frame * (clip.position_track_interpolate(track, seconds) - before)
		assert_float(delta.y * (1.905 / 1.866)).is_equal_approx(-0.225, 0.0001)

func test_source_attacker_other_moves_and_rotations_remain_unmodified() -> void:
	var model: RomanModel = auto_free(MODEL.instantiate())
	add_child(model)
	var source_root: Node = auto_free((load(RomanModel.BASE_RIG) as PackedScene).instantiate())
	var source_sk: Skeleton3D = model._source_skeleton(source_root)
	var adapted := model.adapt_animation_library(POSES, source_sk)
	# Running the helper against a library without its one selected clip is
	# a no-op; normal base/strike and attacker libraries cannot get a fit.
	var unrelated := AnimationLibrary.new()
	unrelated.add_animation("attacker", adapted.get_animation("running_grapple_inverted_drop__attacker").duplicate(true))
	var original := unrelated.get_animation("attacker")
	FIT.apply(unrelated, model._animation_skeletons(), model)
	assert_object(unrelated.get_animation("attacker")).is_same(original)
	var clip: Animation = adapted.get_animation(FIT.CLIP)
	var source: Animation = POSES.get_animation(FIT.CLIP)
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
		var path := clip.track_get_path(track)
		var sk := model.get_node(NodePath(path.get_concatenated_names())) as Skeleton3D
		var target_bone := String(path.get_concatenated_subnames())
		var canonical := ""
		for bone in RomanModel.BONE_MAP:
			if RomanModel.BONE_MAP[bone] == target_bone: canonical = bone
		if canonical == "": continue # helper tracks have their own existing tests
		var input := _track(source, canonical, Animation.TYPE_ROTATION_3D)
		if input < 0: continue
		var rest: Dictionary = model._rest_pair(source_sk, canonical, sk, target_bone)
		for seconds: float in [0.0, 49.0/30.0, 59.0/30.0, 2.2]:
			var expected: Quaternion = model._retarget_key(Animation.TYPE_ROTATION_3D, source.rotation_track_interpolate(input, seconds), rest)
			assert_float(clip.rotation_track_interpolate(track, seconds).angle_to(expected)).is_less(0.0015)
	assert_float(clip.length).is_equal(source.length)
	assert_object(POSES.get_animation(FIT.CLIP)).is_same(source)

func test_measured_source_clip_and_mesh_have_not_silently_changed() -> void:
	# Profile calibration belongs to this exact source performance and mesh.
	# Unrelated animation-library additions do not invalidate it.
	var text := FileAccess.get_file_as_string("res://resources/animations/paired_poses.tres")
	var pattern := RegEx.create_from_string(r'&"running_grapple_inverted_drop__defender": SubResource\("([^"]+)"\)')
	var found := pattern.search(text)
	assert_object(found).is_not_null()
	var header := '[sub_resource type="Animation" id="%s"]\n' % found.get_string(1)
	var section := text.get_slice(header, 1).get_slice("\n[", 0)
	assert_str(section.sha256_text()).is_equal("583f2c73410647deff901ef60e42e91623d1056b203c7811a55986590e5a8888")
	assert_str(FileAccess.get_sha256("res://assets/characters/roman_reigns.glb")).is_equal("4d6d9c3841334a88d733acc1dd1d2c036e9ebf1de1e8812be817d6769dd639b5")
