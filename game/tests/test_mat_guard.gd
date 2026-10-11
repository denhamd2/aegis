extends GdUnitTestSuite
## MatGuard: no hand or foot through the canvas, and nothing touched above it
## or off the deck.


## An arm hanging from a shoulder 0.2 m up, straight down, 0.6 m long: the hand
## is 0.4 m into the canvas. Straight down is the case where turning the arm
## "toward the raised point" is no turn at all.
func _arm(shoulder_at: Vector3) -> Skeleton3D:
	var sk: Skeleton3D = auto_free(Skeleton3D.new())
	sk.add_bone("root")
	sk.add_bone("upperarm")
	sk.add_bone("lowerarm")
	sk.add_bone("hand")
	sk.add_bone("thumb_03")
	for b in range(1, 5):
		sk.set_bone_parent(b, b - 1)
	sk.set_bone_rest(1, Transform3D(Basis(), shoulder_at))
	sk.set_bone_rest(2, Transform3D(Basis(), Vector3(0, -0.3, 0)))
	sk.set_bone_rest(3, Transform3D(Basis(), Vector3(0, -0.3, 0)))
	sk.set_bone_rest(4, Transform3D(Basis(), Vector3(0, -0.05, 0.02)))
	sk.reset_bone_poses()
	add_child(sk)
	return sk


func _guard(sk: Skeleton3D) -> MatGuard:
	var g := MatGuard.new()
	g.chains = [["upperarm", "lowerarm", "hand"]]
	sk.add_child(g)
	return g


func _low(sk: Skeleton3D) -> float:
	var y := INF
	for b in [2, 3, 4]:
		y = minf(y, (sk.global_transform * sk.get_bone_global_pose(b).origin).y)
	return y


func test_a_hand_through_the_canvas_is_lifted_onto_it() -> void:
	var sk := _arm(Vector3(0, 0.2, 0))
	var g := _guard(sk)
	assert_float(_low(sk)).is_less(-0.3)
	g._process_modification()
	assert_float(_low(sk)).is_greater_equal(MatGuard.MAT_Y - MatGuard.GIVE - 0.005)
	assert_int(g.lifts).is_greater(0)


func test_a_hand_above_the_canvas_is_left_alone() -> void:
	var sk := _arm(Vector3(0, 1.4, 0))
	var g := _guard(sk)
	var before := sk.get_bone_global_pose(1)
	g._process_modification()
	assert_bool(sk.get_bone_global_pose(1).is_equal_approx(before)).is_true()
	assert_int(g.lifts).is_equal(0)


## Past the apron there is no canvas: an arm hanging over the floor is an arm
## hanging, not an arm through the mat.
func test_an_arm_hanging_off_the_apron_is_left_alone() -> void:
	var sk := _arm(Vector3(0, 0.2, MatGuard.DECK_HALF + 0.3))
	var g := _guard(sk)
	g._process_modification()
	assert_int(g.lifts).is_equal(0)
