extends GdUnitTestSuite
## The referee in the ring (RefereeActor on AubreyModel): she is in every
## match, her clips resolve on her own skeleton, she stays on the far side
## from the hard camera, kneels past the pinned man's head for a cover, and
## her slap lands on the count tick.

var _scene: Node


func before_test() -> void:
	_scene = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(_scene, pair[0], pair[1], 3)
	_scene.entrances = false
	add_child(_scene)


func after_test() -> void:
	_scene.queue_free()


func test_she_is_in_the_match_and_live_from_the_bell() -> void:
	var actor: RefereeActor = _scene.get_node("RefereeActor")
	assert_object(actor).is_not_null()
	# No entrances: the bell is tick 1, so she is already working.
	assert_int(actor.mode).is_equal(RefereeActor.Mode.FOLLOW)


func test_every_referee_clip_resolves_on_her_skeleton() -> void:
	var actor: RefereeActor = _scene.get_node("RefereeActor")
	var player := actor.model.get_node("AnimationPlayer") as AnimationPlayer
	for clip in ["strikes/ref_stand", "strikes/ref_watch", "strikes/ref_count_down",
			"strikes/ref_slap", "strikes/ref_count_up", "strikes/ref_call_bell",
			"strikes/ref_raise_hand", RefereeActor.WALK_CLIP, RefereeActor.JOG_CLIP]:
		assert_bool(player.has_animation(clip)).override_failure_message(clip).is_true()
		var animation := player.get_animation(clip)
		var root := player.get_node(player.root_node)
		for t in animation.get_track_count():
			var path := animation.track_get_path(t)
			var skeleton := root.get_node_or_null(NodePath(path.get_concatenated_names())) as Skeleton3D
			assert_object(skeleton).override_failure_message("%s: %s" % [clip, path]).is_not_null()
			assert_int(skeleton.find_bone(path.get_concatenated_subnames())).is_greater_equal(0)


func test_only_the_pelvis_keeps_a_position_track() -> void:
	# Her proportions are her own: the base rig's bone offsets are dropped.
	var actor: RefereeActor = _scene.get_node("RefereeActor")
	var player := actor.model.get_node("AnimationPlayer") as AnimationPlayer
	var animation := player.get_animation("strikes/ref_slap")
	for t in animation.get_track_count():
		if animation.track_get_type(t) == Animation.TYPE_POSITION_3D:
			assert_str(String(animation.track_get_path(t).get_concatenated_subnames())).is_equal("pelvis")


func test_she_keeps_to_the_far_side_of_the_hard_camera() -> void:
	var actor: RefereeActor = _scene.get_node("RefereeActor")
	for i in 90:
		await get_tree().process_frame
	# The hard camera is out at -X; she works the +X half of the pair.
	var a: Vector3 = _scene.get_node("WrestlerA").global_position
	var b: Vector3 = _scene.get_node("WrestlerB").global_position
	assert_float(actor.global_position.x).is_greater((a.x + b.x) * 0.5)


func test_the_cover_spot_is_past_the_head_facing_down_the_body() -> void:
	var b: WrestlerController = _scene.get_node("WrestlerB")
	var at := RefereeActor.cover_spot(b)
	var spot: Vector3 = at[0]
	var facing: Vector3 = at[1]
	var neck: Vector3 = b._bone_world("neck_01")
	var hips := Vector3(b.global_position.x, 0.0, b.global_position.z)
	neck.y = 0.0
	# Further from the hips than the neck is, and looking back at them.
	assert_float(spot.distance_to(hips)).is_greater(neck.distance_to(hips))
	assert_float(facing.dot((hips - spot).normalized())).is_greater(0.9)


func test_the_slap_lands_on_the_count_tick() -> void:
	var actor: RefereeActor = _scene.get_node("RefereeActor")
	var player := actor.model.get_node("AnimationPlayer") as AnimationPlayer
	# ref_slap's palm meets the mat on its authored frame 12 of 30 fps.
	var contact := 12.0 / 30.0
	assert_float(player.get_animation("strikes/ref_slap").length).is_greater(contact)
	var ticks := float(RefereeActor.SLAP_LEAD) / Engine.physics_ticks_per_second
	assert_float(ticks).is_equal_approx(contact, 0.001)
	# And every count leaves room for the lead.
	assert_int(MatchReferee.COUNT_TICKS[0]).is_greater(RefereeActor.SLAP_LEAD)
