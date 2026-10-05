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


## A real cover, as the referee starts one, with the defender at `at`.
## A fresh match each time: a pinned man cannot be knocked down again.
func _cover(at: Vector3, yaw: float) -> Array:
	_scene.queue_free()
	before_test()
	await get_tree().physics_frame
	var a: WrestlerController = _scene.get_node("WrestlerA")
	var b: WrestlerController = _scene.get_node("WrestlerB")
	var referee: MatchReferee = _scene.get_node("MatchReferee")
	for w: WrestlerController in [a, b]:
		w.is_ai = false
		if w.ai:
			w.ai.set_physics_process(false)
	b.global_position = at
	b.rotation.y = yaw
	a.global_position = at + Vector3(cos(yaw), 0.0, -sin(yaw)) * 0.9
	a.last_landed_tier = CombatSystem.Tier.FINISHER
	b.fsm.transition_to(WrestlerFSM.State.STUNNED)
	b.fsm.transition_to(WrestlerFSM.State.DOWN)
	referee._pinning = true
	referee._pin_ticks = 0
	referee._pin_attacker = a
	referee._pin_defender = b
	referee._rope_side = Vector3.ZERO
	a.begin_pin(b, 7)
	for i in 40:
		await get_tree().physics_frame
	return [a, b]


## The owner's note: she counted on top of the men. Her spot is chosen round
## the pinned man's head and measured against BOTH bodies, so wherever the
## cover lands -- mid-ring, on the ropes, in a corner -- her kneeling
## footprint keeps clear of either man and stays inside the ropes.
func test_the_cover_spot_is_clear_of_both_men() -> void:
	for at: Vector3 in [Vector3(0.3, 0.0, 0.2), Vector3(2.3, 0.0, 0.4), Vector3(2.2, 0.0, -2.2),
			Vector3(-2.3, 0.0, 1.0)]:
		for yaw: float in [0.0, PI * 0.5, deg_to_rad(200.0)]:
			var pair: Array = await _cover(at, yaw)
			var spot := RefereeActor.cover_spot(pair[1], pair)
			var clear := RefereeActor.body_clearance(spot[0], pair, spot[1])
			assert_float(clear).override_failure_message("%s yaw %.0f: %.2f m" % [at, rad_to_deg(yaw),
					clear]).is_greater(0.3)
			assert_float(absf((spot[0] as Vector3).x)).is_less_equal(RefereeActor.COVER_ROPES)
			assert_float(absf((spot[0] as Vector3).z)).is_less_equal(RefereeActor.COVER_ROPES)
			# Facing the pinned man's head and shoulders, close enough to slap
			# the mat by them.
			var neck: Vector3 = (pair[1] as WrestlerController)._bone_world("neck_01")
			neck.y = 0.0
			var to_neck := neck - (spot[0] as Vector3)
			assert_float((spot[1] as Vector3).dot(to_neck.normalized())).is_greater(0.95)
			assert_float(to_neck.length()).is_less_equal(RefereeActor.COVER_RADII[-1] + 0.01)


## And the old rule, for the record: 0.62 m past his neck put her hands on
## his head -- a footprint with no clearance at all from the man she counts.
func test_the_old_fixed_spot_was_on_top_of_him() -> void:
	var pair: Array = await _cover(Vector3(0.3, 0.0, 0.2), 0.0)
	var b: WrestlerController = pair[1]
	var neck: Vector3 = b._bone_world("neck_01")
	neck.y = 0.0
	var up := (neck - Vector3(b.global_position.x, 0.0, b.global_position.z)).normalized()
	var old := neck + up * RefereeActor.COVER_REACH
	assert_float(RefereeActor.body_clearance(old, pair, -up)).is_less(0.3)
	var spot := RefereeActor.cover_spot(b, pair)
	assert_float(RefereeActor.body_clearance(spot[0], pair, spot[1])) \
		.is_greater(RefereeActor.body_clearance(old, pair, -up))


## Her way to the cover goes round the pair, never through them: a straight
## line from the far side of a man lying along the ropes is refused and a
## waypoint off the bodies is taken instead.
func test_her_route_to_the_cover_goes_round_the_bodies() -> void:
	var pair: Array = await _cover(Vector3(2.3, 0.0, 0.4), deg_to_rad(200.0))
	var spot := RefereeActor.cover_spot(pair[1], pair)
	var segments := RefereeActor.body_segments(pair)
	var from := Vector3(2.25, 0.0, -0.95)
	var at := from
	for i in 4:
		var next := RefereeActor.route_to(at, spot[0], pair)
		var clear := RefereeActor._line_clearance(at, next, segments)
		assert_float(clear).override_failure_message("leg %d %s -> %s: %.2f m off a body" % [
				i, at, next, clear]).is_greater(0.25)
		at = next
		if at == spot[0]:
			break
	assert_vector(at).is_equal(spot[0])


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


func test_raise_clip_is_authored_for_both_and_wrists_meet() -> void:
	var actor: RefereeActor = _scene.get_node("RefereeActor")
	var a: WrestlerController = _scene.get_node("WrestlerA")
	assert_bool((a.anim_player as AnimationPlayer).has_animation("strikes/win_arm_raised")).is_true()
	# Winner celebrates, Aubrey beside him, her hand_r on his hand_l.
	a.celebrate()
	actor._winner = a
	actor.global_position = a.global_position + RefereeActor.WINNER_SIDE
	a.rotation.y = PI * 0.5
	actor.rotation.y = PI * 0.5
	actor._set_mode(RefereeActor.Mode.RAISE)
	for i in 60:
		await get_tree().process_frame
	assert_float(actor.raise_hand_gap()).is_less(0.1)
