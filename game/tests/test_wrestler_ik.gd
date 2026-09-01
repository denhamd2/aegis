extends GdUnitTestSuite
## WrestlerController's grip IK -- the arm chains that pull a wrestler's hands
## onto his opponent while gripping.
##
## Paired grapple clips animate only the two root transforms, and each
## skeleton is posed by its own single-character clip, which has no idea
## another body exists. So an attacker performed a lifting motion *near* the
## defender without ever touching him. SkeletonIK3D derives from
## SkeletonModifier3D and therefore runs after the AnimationMixer writes the
## pose, letting the clip supply the body while IK places the arms on top.
##
## This is presentation only: it writes bone poses and marker positions, never
## position/velocity/FSM state, so it must never change a match outcome. Six
## seeds were checked to produce byte-identical results with it wired in.
##
## These tests cover the rig and the targeting maths. Whether the *pose* comes
## out right is not assertable here and was checked by rendering close-ups --
## Skeleton3D.get_bone_global_pose() returns the pre-modifier pose and reports
## no movement even when a modifier is demonstrably working, and a
## BoneAttachment3D (which does read the post-modifier pose) deadlocks against
## an IK modifier on the same skeleton.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")

func _make_wrestler() -> WrestlerController:
	var wrestler: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(wrestler)
	return wrestler

## A gripping pair: `wrestler` holds `opponent`, squared up 1.25m apart, which
## is roughly the live tie-up separation.
func _make_gripping_pair() -> Array:
	var wrestler := _make_wrestler()
	var opponent := _make_wrestler()
	wrestler.global_position = Vector3(-0.625, 0.0, 0.0)
	opponent.global_position = Vector3(0.625, 0.0, 0.0)
	wrestler.opponent = opponent
	wrestler.fsm.current_state = WrestlerFSM.State.TIE_UP
	return [wrestler, opponent]

func test_builds_one_ik_chain_per_arm() -> void:
	var wrestler := _make_wrestler()
	assert_int(wrestler._arm_ik.size()).is_equal(2)
	assert_str(String(wrestler._arm_ik[0].root_bone)).is_equal("upperarm_l")
	assert_str(String(wrestler._arm_ik[0].tip_bone)).is_equal("hand_l")
	assert_str(String(wrestler._arm_ik[1].root_bone)).is_equal("upperarm_r")
	assert_str(String(wrestler._arm_ik[1].tip_bone)).is_equal("hand_r")
	assert_int(wrestler._grip_targets.size()).is_equal(2)

## start() resolves the bone names against the parent skeleton. Called before
## the node is configured and parented it silently resolves them to -1 and the
## solver logs a build_chain error every frame while doing nothing.
func test_both_solvers_are_running() -> void:
	var wrestler := _make_wrestler()
	await await_millis(50)
	for ik in wrestler._arm_ik:
		assert_bool(ik.is_running()).is_true()

## Zero blend at rest means a wrestler who never grapples is posed exactly as
## he was before any of this existed.
func test_starts_with_no_blend() -> void:
	var wrestler := _make_wrestler()
	assert_float(wrestler._grip_blend).is_equal_approx(0.0, 0.0001)
	for ik in wrestler._arm_ik:
		assert_float(ik.interpolation).is_equal_approx(0.0, 0.0001)

func test_measures_a_plausible_arm_reach() -> void:
	var wrestler := _make_wrestler()
	# ~0.55m on this 1.83m rig (upper arm 0.274 + forearm 0.273).
	assert_float(wrestler._arm_reach).is_between(0.4, 0.7)

func test_grips_during_tie_up_and_as_the_grapple_attacker() -> void:
	var wrestler := _make_wrestler()
	wrestler.fsm.current_state = WrestlerFSM.State.TIE_UP
	assert_bool(wrestler._is_gripping_state()).is_true()

	wrestler.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	wrestler._is_grapple_attacker = true
	assert_bool(wrestler._is_gripping_state()).is_true()

## The wrestler being thrown shouldn't be reaching for anything.
func test_does_not_grip_as_the_grapple_defender() -> void:
	var wrestler := _make_wrestler()
	wrestler.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	wrestler._is_grapple_attacker = false
	assert_bool(wrestler._is_gripping_state()).is_false()

func test_does_not_grip_in_free_movement_or_strikes() -> void:
	var wrestler := _make_wrestler()
	for state in [WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION,
			WrestlerFSM.State.RUN, WrestlerFSM.State.STRIKE,
			WrestlerFSM.State.HIT_REACT, WrestlerFSM.State.DOWN]:
		wrestler.fsm.current_state = state
		assert_bool(wrestler._is_gripping_state()).override_failure_message(
			"should not grip in %s" % WrestlerFSM.State.keys()[state]
		).is_false()

func test_blend_ramps_in_by_a_fixed_step_per_tick() -> void:
	var pair := _make_gripping_pair()
	var wrestler: WrestlerController = pair[0]

	wrestler._update_grip_ik()
	assert_float(wrestler._grip_blend).is_equal_approx(
		WrestlerController.IK_BLEND_PER_TICK, 0.0001
	)
	wrestler._update_grip_ik()
	assert_float(wrestler._grip_blend).is_equal_approx(
		WrestlerController.IK_BLEND_PER_TICK * 2.0, 0.0001
	)
	# and it reaches the solvers, not just the field
	assert_float(wrestler._arm_ik[0].interpolation).is_equal_approx(
		wrestler._grip_blend, 0.0001
	)

func test_blend_saturates_at_one_and_ramps_back_out() -> void:
	var pair := _make_gripping_pair()
	var wrestler: WrestlerController = pair[0]
	for _i in 20:
		wrestler._update_grip_ik()
	assert_float(wrestler._grip_blend).is_equal_approx(1.0, 0.0001)

	wrestler.fsm.current_state = WrestlerFSM.State.IDLE
	wrestler._update_grip_ik()
	assert_float(wrestler._grip_blend).is_equal_approx(
		1.0 - WrestlerController.IK_BLEND_PER_TICK, 0.0001
	)
	for _i in 20:
		wrestler._update_grip_ik()
	assert_float(wrestler._grip_blend).is_equal_approx(0.0, 0.0001)

## No opponent to grip: blend out quietly rather than erroring or latching on.
func test_no_opponent_is_a_no_op() -> void:
	var wrestler := _make_wrestler()
	wrestler.fsm.current_state = WrestlerFSM.State.TIE_UP
	wrestler.opponent = null

	wrestler._update_grip_ik()

	assert_bool(wrestler._aim_grip_targets()).is_false()
	assert_float(wrestler._grip_blend).is_equal_approx(0.0, 0.0001)

## The clips hold the two bodies 0.8-1.2m apart while an arm spans only
## ~0.55m, so targets are clamped onto the reach sphere rather than rejected
## -- a hard reach test would never engage at all.
func test_grip_targets_are_clamped_within_arm_reach() -> void:
	var pair := _make_gripping_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	opponent.global_position = Vector3(50.0, 0.0, 0.0) # far out of reach

	assert_bool(wrestler._aim_grip_targets()).is_true()

	var shoulder_bone := wrestler.skeleton.find_bone(
		WrestlerController.ARM_CHAINS[0]["root"]
	)
	var shoulder: Vector3 = wrestler.skeleton.global_transform \
			* wrestler.skeleton.get_bone_global_pose(shoulder_bone).origin
	var span := shoulder.distance_to(wrestler._grip_targets[0].global_position)
	assert_float(span).is_less_equal(wrestler._arm_reach + 0.001)

## Within reach the target is used verbatim, so hands land on the opponent
## rather than stopping short of him.
func test_a_reachable_grip_is_not_clamped() -> void:
	var pair := _make_gripping_pair()
	var wrestler: WrestlerController = pair[0]
	var root_bone: String = WrestlerController.ARM_CHAINS[0]["root"]
	var shoulder_bone := wrestler.skeleton.find_bone(root_bone)
	var shoulder: Vector3 = wrestler.skeleton.global_transform \
			* wrestler.skeleton.get_bone_global_pose(shoulder_bone).origin
	var close_target := shoulder + Vector3(0.0, 0.0, -0.1)

	var result := wrestler._reachable(root_bone, close_target)

	assert_vector(result).is_equal_approx(close_target, Vector3.ONE * 0.001)

## A lifting attacker holds the hips; a squared-up one holds the chest. During
## a throw the victim's chest is overhead and behind, and reaching for it puts
## the arms somewhere that reads as nothing at all.
func test_lift_and_tie_up_aim_at_different_heights() -> void:
	var pair := _make_gripping_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	# Close enough that neither grip gets clamped, so the heights are the
	# anchors' own rather than the reach sphere's.
	opponent.global_position = Vector3(0.1, 0.0, 0.0)

	wrestler.fsm.current_state = WrestlerFSM.State.TIE_UP
	wrestler._aim_grip_targets()
	var chest_height := wrestler._grip_targets[0].global_position.y

	wrestler.fsm.current_state = WrestlerFSM.State.GRAPPLE_HOLD
	wrestler._is_grapple_attacker = true
	wrestler._aim_grip_targets()
	var hip_height := wrestler._grip_targets[0].global_position.y

	assert_float(hip_height).is_less(chest_height)
