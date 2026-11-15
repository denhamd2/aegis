extends GdUnitTestSuite
## Drive the release from the real shared player's clock, including recovery.

func fixture(move_id := "running_grapple_inverted_drop") -> Dictionary:
	var rig: GrappleRig = auto_free(GrappleRig.new())
	add_child(rig)
	var player := AnimationPlayer.new()
	rig.add_child(player)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = 2.2
	library.add_animation("clock", clip)
	player.add_animation_library("", library)
	player.play("clock")
	rig.animation_player = player
	rig._original_anim = clip
	rig._retargeted_anim_name = &"clock"
	rig._move = load("res://resources/moves/%s.tres" % move_id)
	var a: WrestlerController = auto_free(WrestlerController.new())
	var d: WrestlerController = auto_free(WrestlerController.new())
	a.paired_separation = Vector3(.02, -.04, .03)
	d.paired_separation = Vector3(.12, .33, .08)
	rig._attacker = a
	rig._defender = d
	return {"rig": rig, "player": player, "a": a, "d": d}

func sample(p: Dictionary, frame: float) -> void:
	p.player.seek(frame / 30.0, true)
	p.rig._update_separation_height()

func test_early_carry_is_unchanged_then_offsets_release_on_authored_beats() -> void:
	var p := fixture()
	sample(p, 52.5)
	assert_bool(p.rig._separation_height_captured).is_false()
	var proposal := Vector3(.3, .6, .2)
	assert_vector(p.rig._constrain_separation(proposal, .45)).is_equal_approx(proposal.limit_length(.45), Vector3.ONE * .00001)
	sample(p, 55.0)
	assert_bool(p.rig._separation_height_captured).is_false()
	sample(p, 55.5)
	assert_bool(p.rig._separation_height_captured).is_true()
	sample(p, 57.0)
	assert_float(p.rig._constrain_separation(Vector3(.8, .9, .8), .45).y).is_equal_approx(.165, .00001)
	assert_float(p.rig._constrain_separation(Vector3(.8, -.9, .8), .10, true).y).is_equal_approx(-.02, .00001)
	assert_float(p.rig._constrain_separation(Vector3(.8, .9, .8), .45).length()).is_less_equal(.450001)
	# Extra solver passes cannot compound the release or reintroduce height.
	for pass_index in 6:
		assert_float(p.rig._constrain_separation(Vector3(0, .8, 0), .45).y).is_equal_approx(.165, .00001)
	sample(p, 59.0)
	assert_float(p.rig._constrain_separation(Vector3(.1, .9, .1), .45).y).is_equal_approx(0.0, .00001)
	assert_float(p.rig._constrain_separation(Vector3(.1, -.9, .1), .10, true).y).is_equal_approx(0.0, .00001)

func test_height_release_stays_closed_after_root_playback_is_restored() -> void:
	var p := fixture()
	sample(p, 55.5)
	sample(p, 59.0)
	p.rig._original_anim = null
	p.player.stop()
	p.rig._update_separation_height()
	assert_float(p.rig._constrain_separation(Vector3(.1, .33, 0), .45).y).is_equal_approx(0.0, .00001)

func test_other_moves_keep_the_existing_three_dimensional_fitting() -> void:
	var p := fixture("finisher_spear")
	sample(p, 60.0)
	assert_bool(p.rig._separation_height_captured).is_false()
	var proposal := Vector3(.3, .6, .2)
	assert_vector(p.rig._constrain_separation(proposal, .45)).is_equal_approx(proposal.limit_length(.45), Vector3.ONE * .00001)

func test_no_contact_settle_keeps_the_prescribed_release_height() -> void:
	var p := fixture()
	for body: WrestlerController in [p.a, p.d]:
		body.skeleton = Skeleton3D.new()
		body.add_child(body.skeleton)
		body.anim_player = AnimationPlayer.new()
		body.add_child(body.anim_player)
	p.a._is_grapple_attacker = false
	sample(p, 55.5)
	sample(p, 57.0)
	p.rig._separate_models()
	assert_float(p.a.paired_separation.y).is_equal_approx(-.02, .00001)
	assert_float(p.d.paired_separation.y).is_equal_approx(.165, .00001)

func test_configured_release_windows_are_ordered_inside_the_clip() -> void:
	for recipe: Dictionary in PairedRecipes.RECIPES.values():
		if not recipe.has("separation_height_release"):
			continue
		var window: Vector2 = recipe["separation_height_release"]
		assert_float(window.x).is_greater_equal(0.0)
		assert_float(window.y).is_greater(window.x)
		assert_float(window.y).is_less_equal(1.0)

func test_grip_fade_finishes_before_the_authored_impact() -> void:
	var move: MoveDef = load("res://resources/moves/running_grapple_inverted_drop.tres")
	var fade_start := int(round(move.total_frames() * PairedRecipes.attacker_grip_until(move.animation_pair_id)))
	var fade_ticks := int(ceil(1.0 / WrestlerController.IK_BLEND_PER_TICK))
	assert_int(fade_start + fade_ticks).is_less_equal(118)

func test_real_pair_releases_its_grip_and_height_on_the_shared_clock() -> void:
	var result: Dictionary = await PairClearance.measure(self,
			"running_grapple_inverted_drop", PackedStringArray(["cody", "roman"]), true)
	var rows: Array = result["trace"]
	var before := _trace_at(rows, 54.5)
	var fade := _trace_at(rows, 55.0)
	var released := _trace_at(rows, 58.0)
	var impact := _trace_at(rows, 59.0)
	assert_float(before.get("grip_blend", -1.0)).is_equal_approx(1.0, .00001)
	assert_float(fade.get("grip_blend", 1.0)).is_less(1.0)
	assert_float(released.get("grip_blend", -1.0)).is_equal_approx(0.0, .00001)
	assert_float((impact.get("separation_attacker", Vector3.INF) as Vector3).y).is_equal_approx(0.0, .00001)
	assert_float((impact.get("separation_defender", Vector3.INF) as Vector3).y).is_equal_approx(0.0, .00001)

func _trace_at(rows: Array, source_frame: float) -> Dictionary:
	for row: Dictionary in rows:
		if absf(float(row["seconds"]) - source_frame / 30.0) < .000001:
			return row
	fail("Missing paired-clock sample at source frame %s" % source_frame)
	return {}
