extends GdUnitTestSuite
## refs/aaa_gap.md items 10-12: broadcast finish (entrance depth of field,
## vignette, replay grain), the crowd reacting, and eyes that look.

# --- 10: broadcast finish ----------------------------------------------------

func test_only_close_up_lenses_lose_their_background() -> void:
	# The wide entrance lens and the match master stay sharp.
	assert_float(MatchCamera.dof_amount_for(53.0)).is_equal(0.0)
	assert_float(MatchCamera.dof_amount_for(41.0)).is_equal(0.0)
	# The face-off close-up (34) blurs; a tighter lens blurs more.
	assert_float(MatchCamera.dof_amount_for(34.0)).is_greater(0.0)
	assert_float(MatchCamera.dof_amount_for(22.0)).is_greater(
			MatchCamera.dof_amount_for(34.0))


func test_an_entrance_close_up_focuses_on_the_subject_and_the_bell_clears_it() -> void:
	var cam: MatchCamera = auto_free(MatchCamera.new())
	add_child(cam)
	cam.set_entrance_shot(Vector3(0, 1.7, 3), Vector3(0, 1.7, 0), 34.0, true)
	var dof := cam.attributes as CameraAttributesPractical
	assert_object(dof).is_not_null()
	assert_bool(dof.dof_blur_far_enabled).is_true()
	assert_float(dof.dof_blur_far_distance).is_equal_approx(3.0 + MatchCamera.DOF_MARGIN, 0.01)
	cam.resume_master()
	assert_object(cam.attributes).is_null()


func test_grain_only_on_a_replay() -> void:
	var live: BroadcastLook = auto_free(BroadcastLook.new())
	add_child(live)
	var mat := (live.get_node("Finish") as ColorRect).material as ShaderMaterial
	assert_float(mat.get_shader_parameter("grain")).is_equal(0.0)
	assert_float(mat.get_shader_parameter("vignette")).is_greater(0.0)
	live.set_grain(true)
	assert_float(mat.get_shader_parameter("grain")).is_equal_approx(BroadcastLook.GRAIN, 0.001)

# --- 11: the crowd -----------------------------------------------------------

func test_big_moves_pop_the_crowd_and_jabs_do_not() -> void:
	var jab: MoveDef = load("res://resources/moves/strike_jab.tres")
	var suplex: MoveDef = load("res://resources/moves/grapple_vertical_suplex.tres")
	var cutter: MoveDef = load("res://resources/moves/signature_cody_cutter.tres")
	assert_float(CrowdReaction.move_pop(jab)).is_equal(0.0)
	assert_float(CrowdReaction.move_pop(suplex)).is_between(0.3, CrowdReaction.POP_MOVE_MAX)
	assert_float(CrowdReaction.move_pop(cutter)).is_equal(CrowdReaction.POP_SIGNATURE)


func test_excitement_halves_every_half_life() -> void:
	assert_float(CrowdReaction.decayed(1.0, CrowdReaction.HALF_LIFE)).is_equal_approx(0.5, 0.001)
	# Never below a held floor.
	assert_float(CrowdReaction.decayed(1.0, 60.0, 0.8)).is_equal_approx(0.8, 0.001)


func test_a_kickout_after_two_is_a_near_fall_pop() -> void:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	var crowd: CrowdReaction = auto_free(CrowdReaction.new())
	add_child(crowd)
	crowd._referee = referee
	referee._pinning = true
	for count in [1, 2]:
		referee._pin_count_shown = count
		crowd._process(0.1)
	assert_float(crowd.excitement).is_between(0.55, 0.7)
	# He kicks out.
	referee._pinning = false
	referee._pin_count_shown = 0
	crowd._process(0.0)
	assert_float(crowd.excitement).is_equal_approx(CrowdReaction.POP_NEAR_FALL, 0.001)


func test_the_finish_holds_the_crowd_up() -> void:
	var crowd: CrowdReaction = auto_free(CrowdReaction.new())
	add_child(crowd)
	crowd._on_match_won(null, "pinfall")
	for i in 60:
		crowd._process(0.1)
	assert_float(crowd.excitement).is_greater_equal(0.8)

# --- 12: eyes ------------------------------------------------------------------

## A head bone at 1.7 m and an eye bone just in front of it, looking +Z.
func _head() -> Skeleton3D:
	var sk: Skeleton3D = auto_free(Skeleton3D.new())
	sk.add_bone("Head")
	sk.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0)))
	sk.add_bone("J_Eye_L")
	sk.set_bone_parent(1, 0)
	# A rolled eye bone, as a real rig's are: the aim must work in its frame.
	sk.set_bone_rest(1, Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0.03, 0.05, 0.08)))
	sk.reset_bone_poses()
	add_child(sk)
	return sk


func test_an_eye_turns_to_look_at_its_target() -> void:
	var sk := _head()
	var eye := sk.get_bone_global_pose(1)
	var target := eye.origin + Vector3(0.6, 0.1, 2.0)
	var q := EyeAim.aim_rotation(sk, 1, target)
	var rest := sk.get_bone_rest(1)
	sk.set_bone_pose_rotation(1, rest.basis.get_rotation_quaternion() * q)
	var posed := sk.get_bone_global_pose(1)
	# The rest line of sight (+Z in the skeleton), carried by the new pose.
	var forward_local := sk.get_bone_global_rest(1).basis.inverse() * EyeAim.REST_FORWARD
	var sight := (posed.basis * forward_local).normalized()
	assert_float(sight.angle_to((target - posed.origin).normalized())).is_less(0.01)


func test_an_eye_does_not_roll_to_look_behind_him() -> void:
	var sk := _head()
	var behind := sk.get_bone_global_pose(1).origin + Vector3(0.0, 0.0, -2.0)
	assert_bool(EyeAim.aim_rotation(sk, 1, behind).is_equal_approx(Quaternion.IDENTITY)).is_true()

# --- The lock-up (owner-flagged: two men gripping air) -----------------------

## A tie-up held 1.2 m apart closes to chest-to-chest on the MODELS, half
## each; one already close does not move; the edge of range is capped.
func test_a_lock_up_closes_to_chest_to_chest() -> void:
	var gap := 1.2
	var slide := WrestlerController.lock_up_slide(gap)
	assert_float(gap - 2.0 * slide).is_equal_approx(WrestlerController.LOCK_UP_GAP, 0.001)
	assert_float(WrestlerController.lock_up_slide(0.5)).is_equal(0.0)
	assert_float(WrestlerController.lock_up_slide(3.0)).is_equal(WrestlerController.LOCK_UP_MAX_SLIDE)
