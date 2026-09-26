extends GdUnitTestSuite
## A standing wrestler stays off a downed man's body, and walks to the side of
## his chest to cover him. See WrestlerController's "A downed man's body"
## block; tools/probe/limb_clearance.tscn is the rendered-pose measurement
## (259 visible overlap ticks over five seeds before, 7 after).

func _downed(at: Vector3, yaw_deg: float) -> WrestlerController:
	var w: WrestlerController = auto_free(WrestlerController.new())
	add_child(w)
	w.global_position = at
	w.rotation.y = deg_to_rad(yaw_deg)
	return w


func test_a_clear_position_is_left_alone() -> void:
	var push := WrestlerController.body_clearance_push(Vector3(2.0, 0.0, 0.0),
			Vector3(0.0, 0.0, -0.75), Vector3(0.0, 0.0, 0.65))
	assert_vector(push).is_equal(Vector3.ZERO)


## Straight out from the line, never along it, and never more than one tick's
## worth -- the guard cancels a step, it does not shove.
func test_an_overlap_is_pushed_straight_out_and_capped() -> void:
	var push := WrestlerController.body_clearance_push(Vector3(0.1, 0.0, 0.3),
			Vector3(0.0, 0.0, -0.75), Vector3(0.0, 0.0, 0.65))
	assert_float(push.z).is_equal_approx(0.0, 0.0001)
	assert_float(push.x).is_greater(0.0)
	assert_float(push.length()).is_less_equal(WrestlerController.BODY_PUSH_MAX_M + 0.0001)


## The feet end counts: the raised knees are what went through the standing
## man on the owner's video.
func test_standing_on_his_boots_is_an_overlap() -> void:
	var push := WrestlerController.body_clearance_push(Vector3(0.0, 0.0, 0.8),
			Vector3(0.0, 0.0, -0.75), Vector3(0.0, 0.0, 0.65))
	assert_float(push.length()).is_greater(0.0)


func test_the_approach_is_beside_his_chest_on_my_side() -> void:
	var victim := _downed(Vector3.ZERO, 0.0)
	var spot := WrestlerController.cover_approach_spot(victim, Vector3(1.5, 0.0, 1.5))
	var local := victim.global_transform.affine_inverse() * spot
	assert_float(local.z).is_equal_approx(-WrestlerController.COVER_TOWARD_HEAD_M, 0.01)
	assert_float(local.x).is_greater(WrestlerController.BODY_CLEAR_M)


## Seed 4's corner: his head over the ropes, my side outside the ring. The spot
## must be one a man can stand on AND clear of the body.
func test_by_the_ropes_the_approach_takes_the_side_that_exists() -> void:
	var victim := _downed(Vector3(-2.04, 0.0, 2.55), 180.0)
	var spot := WrestlerController.cover_approach_spot(victim, Vector3(-2.55, 0.0, 2.55))
	assert_float(absf(spot.x)).is_less_equal(WrestlerController.STANDABLE_M + 0.001)
	assert_float(absf(spot.z)).is_less_equal(WrestlerController.STANDABLE_M + 0.001)
	var line := WrestlerController.downed_body_line(victim)
	var flat := Vector3(spot.x, 0.0, spot.z)
	var clear := flat.distance_to(
			Geometry3D.get_closest_point_to_segment(flat, line[0], line[1]))
	assert_float(clear).is_greater_equal(WrestlerController.BODY_CLEAR_M)


func test_a_cover_is_made_from_beside_the_torso_not_the_feet() -> void:
	var victim := _downed(Vector3.ZERO, 0.0)
	# His head is up -Z, his feet down +Z.
	assert_bool(WrestlerController.is_beside_torso(victim, Vector3(0.7, 0.0, -0.4))).is_true()
	assert_bool(WrestlerController.is_beside_torso(victim, Vector3(0.3, 0.0, 1.0))).is_false()
