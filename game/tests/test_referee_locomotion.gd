extends GdUnitTestSuite
## Aubrey's own feet (the owner, 2 Nov): "a proper referee walk; a side-step
## shuffle for following the action, which real refs do constantly; a jog
## matched to the speed she actually moves at, so her feet don't slide".


## Her walk, jog and side-steps are her own authored 60 fps clips, not the
## CC0 mocap played at 1.8x and 0.6x.
func test_she_moves_on_her_own_clips() -> void:
	for clip: String in [RefereeActor.WALK_CLIP, RefereeActor.JOG_CLIP,
			RefereeActor.SHUFFLE_R_CLIP, RefereeActor.SHUFFLE_L_CLIP, Timekeeper.WALK_CLIP]:
		assert_str(clip).starts_with("strikes/ref_")
	for recipe: String in ["ref_walk", "ref_jog", "ref_shuffle_r", "ref_shuffle_l"]:
		assert_bool(StrikeRecipes.RECIPES.has(recipe)).is_true()
	# Played near their own pace: the walk and the jog within 15 % of rate 1.
	var walk_rate := RefereeActor.WALK_SPEED / RefereeActor.WALK_CLIP_SPEED
	var jog_rate := RefereeActor.JOG_SPEED / RefereeActor.JOG_CLIP_SPEED
	assert_float(walk_rate).is_between(0.85, 1.15)
	assert_float(jog_rate).is_between(0.85, 1.15)


## Following the action she steps across it, eyes on the two men; going
## toward it or away from it she walks. Her model faces its +Z, so with the
## men ahead along +Z her right is -X.
func test_she_side_steps_across_the_action_and_walks_toward_it() -> void:
	var ahead := Vector3(0, 0, 2)
	assert_int(RefereeActor.shuffle_side(Vector3(-1, 0, 0), ahead)).is_equal(1)
	assert_int(RefereeActor.shuffle_side(Vector3(1, 0, 0), ahead)).is_equal(-1)
	assert_int(RefereeActor.shuffle_side(Vector3(0, 0, 1), ahead)).is_equal(0)
	assert_int(RefereeActor.shuffle_side(Vector3(0, 0, -1), ahead)).is_equal(0)
	# mostly across, a little toward: still a side-step
	assert_int(RefereeActor.shuffle_side(Vector3(-1, 0, 0.4), ahead)).is_equal(1)
	# standing still, or nothing to watch: no side-step
	assert_int(RefereeActor.shuffle_side(Vector3.ZERO, ahead)).is_equal(0)
	assert_int(RefereeActor.shuffle_side(Vector3(-1, 0, 0), Vector3.ZERO)).is_equal(0)
