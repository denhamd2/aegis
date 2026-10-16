extends GdUnitTestSuite
## Roman's reference sculpt must preserve the neck, eye rig and surface.
## The October portrait supersedes the old long-chin/narrow-jaw art target;
## actual likeness is reviewed on rendered front/three-quarter/profile views.


## Nothing below the neck moves, so the head still meets the body: every
## bump is clear of y 1.55 at the face's widest.
func test_nothing_moves_below_the_neck() -> void:
	for x in [-0.12, -0.06, 0.0, 0.06, 0.12]:
		for z in [-0.08, 0.0, 0.08, 0.16]:
			assert_vector(RomanFaceShape.offset(Vector3(x, 1.54, z))).is_equal(Vector3.ZERO)


## A local refit must not fold the mesh or accidentally edit it in centimetres.
## Positive Jacobians also protect the inverse-transpose normal transform.
func test_the_sculpt_is_symmetric_bounded_and_does_not_fold_the_face() -> void:
	var step := 0.0005
	for x in [0.0, 0.02, 0.04, 0.06, 0.08]:
		for y in [1.60, 1.625, 1.65, 1.675, 1.70, 1.725, 1.75, 1.775]:
			for z in [0.06, 0.10, 0.14, 0.17]:
				var p := Vector3(x, y, z)
				var d := RomanFaceShape.offset(p)
				var mirrored := RomanFaceShape.offset(Vector3(-x, y, z))
				assert_bool(d.is_finite()).is_true()
				assert_float(d.length()).is_less(0.015)
				assert_vector(mirrored).is_equal_approx(Vector3(-d.x, d.y, d.z), Vector3.ONE * .00001)
				var j := Basis()
				for axis in 3:
					var direction := Vector3.ZERO
					direction[axis] = 1.0
					j[axis] = direction + (RomanFaceShape.offset(p + direction * step)
							- RomanFaceShape.offset(p - direction * step)) / (2.0 * step)
				assert_float(j.determinant()).is_greater(0.35)


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
