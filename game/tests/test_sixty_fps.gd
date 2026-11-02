extends GdUnitTestSuite
## The owner, 2 Nov: "I want the gameplay and animations all to be at 60fps".
## The match ticks at 60 Hz; the clips now carry 60 samples a second where
## they are authored (wrestling_clips.py EXPORT_FPS, imported at
## animation/fps=60, re-baked into the paired and strike libraries), and the
## base library's 30 fps motion capture plays cubic between its keys.

const CLIPS := "res://assets/animations/wrestling_clips.glb"


func _min_gap(anim: Animation, bone: String) -> float:
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D \
				and String(anim.track_get_path(t)).ends_with(":" + bone) \
				and anim.track_get_key_count(t) > 2:
			var gap := 1.0e9
			for k in range(1, anim.track_get_key_count(t)):
				gap = minf(gap, anim.track_get_key_time(t, k) - anim.track_get_key_time(t, k - 1))
			return gap
	return -1.0


func test_the_match_ticks_at_sixty() -> void:
	assert_int(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))).is_equal(60)


func test_the_authored_clips_are_sampled_at_sixty() -> void:
	var scene: Node = auto_free((load(CLIPS) as PackedScene).instantiate())
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var anim := player.get_animation("Samoan_Drop_Attacker")
	assert_float(_min_gap(anim, "spine_02")).is_equal_approx(1.0 / 60.0, 0.002)


func test_the_paired_bake_carries_the_sixty_samples() -> void:
	var lib: AnimationLibrary = load("res://resources/animations/paired_poses.tres")
	var fine := 0
	var total := 0
	for n in lib.get_animation_list():
		var gap := _min_gap(lib.get_animation(n), "spine_02")
		if gap > 0.0:
			total += 1
			if gap < 1.0 / 40.0:
				fine += 1
	assert_int(total).is_greater(50)
	assert_float(float(fine) / float(total)).is_greater(0.9)


func test_the_base_clips_play_cubic_between_keys() -> void:
	var lib := AnimationLibrary.new()
	var anim := Animation.new()
	anim.length = 1.0
	var t := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t, NodePath("Skeleton3D:spine_02"))
	for i in 4:
		anim.rotation_track_insert_key(t, i / 3.0, Quaternion(Vector3.UP, i * 0.3))
	lib.add_animation(&"walk", anim)
	assert_int(WrestlerController.smooth_between_keys(lib)).is_equal(1)
	assert_int(anim.track_get_interpolation_type(t)).is_equal(Animation.INTERPOLATION_CUBIC)
	# Through every key exactly, and idempotent.
	assert_float(anim.rotation_track_interpolate(t, 1.0 / 3.0).angle_to(Quaternion(Vector3.UP, 0.3))).is_less(0.0001)
	assert_int(WrestlerController.smooth_between_keys(lib)).is_equal(0)
