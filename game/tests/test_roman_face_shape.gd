extends GdUnitTestSuite
## Roman's face to 2K26 (core/match/roman_face_shape.gd): a long, lean face
## with a heavy brow, sculpted at load without touching the neck or the eyes.


## Nothing below the neck moves, so the head still meets the body: every
## bump is clear of y 1.55 at the face's widest.
func test_nothing_moves_below_the_neck() -> void:
	for x in [-0.12, -0.06, 0.0, 0.06, 0.12]:
		for z in [-0.08, 0.0, 0.08, 0.16]:
			assert_vector(RomanFaceShape.offset(Vector3(x, 1.54, z))).is_equal(Vector3.ZERO)


## The shape: the brow forward and down, the chin longer, the cheeks in.
func test_the_brow_comes_down_and_the_chin_lengthens() -> void:
	var brow := RomanFaceShape.offset(Vector3(0.031, 1.738, 0.125))
	assert_float(brow.z).is_greater(0.004)
	assert_float(brow.y).is_less(0.0)
	assert_float(RomanFaceShape.offset(Vector3(0.0, 1.600, 0.11)).y).is_less(-0.008)
	assert_float(RomanFaceShape.offset(Vector3(0.07, 1.675, 0.06)).x).is_less(-0.005)
	assert_float(RomanFaceShape.offset(Vector3(-0.07, 1.675, 0.06)).x).is_greater(0.005)


## The eyes turn about their bones and the lids are placed off those bones,
## so the eye meshes are left exactly where the model put them.
func test_the_eyes_are_left_where_their_bones_are() -> void:
	var model: Node3D = (load("res://assets/characters/roman_reigns.glb") as PackedScene).instantiate()
	auto_free(model)
	var before := {}
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		before[mi] = mi.mesh
	assert_int(RomanFaceShape.apply(model)).is_greater(1000)
	var eyes := 0
	for mi: MeshInstance3D in before:
		if RomanFaceShape._fixed(mi):
			eyes += 1
			assert_object(mi.mesh).is_same(before[mi])
	assert_int(eyes).is_greater_equal(2)
