extends GdUnitTestSuite
## BodyBulk (gauntlet/refs/characters/review): muscle built onto the supplied
## bodies at load, along each vertex's normal by the weight of the bones it
## follows -- and nothing moved that follows none of them.


func _arrays(bones: PackedInt32Array, weights: PackedFloat32Array) -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0)])
	a[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP])
	a[Mesh.ARRAY_BONES] = bones
	a[Mesh.ARRAY_WEIGHTS] = weights
	return a


func test_a_vertex_moves_by_its_weighted_gain_along_its_normal() -> void:
	# Two vertices, four influences each: the first half on bind 3 (gain
	# 0.02) and half on bind 5 (no gain); the second all on bind 5.
	var a := _arrays(PackedInt32Array([3, 5, 0, 0, 5, 0, 0, 0]),
			PackedFloat32Array([0.5, 0.5, 0, 0, 1.0, 0, 0, 0]))
	var moved := BodyBulk.inflate(a, {3: 0.02})
	assert_int(moved).is_equal(1)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	assert_vector(v[0]).is_equal_approx(Vector3(0, 0.01, 0), Vector3.ONE * 1e-6)
	assert_vector(v[1]).is_equal(Vector3(1, 0, 0))


func test_both_men_are_built_up_and_their_heads_are_not() -> void:
	for path in ["res://assets/characters/cody_rhodes.glb", "res://assets/characters/roman_reigns.glb"]:
		var root: Node = (load(path) as PackedScene).instantiate()
		add_child(root)
		var sk: Skeleton3D = root.find_child("Skeleton3D", true, false)
		var gains := BodyBulk.CODY if path.contains("cody") else BodyBulk.ROMAN
		assert_int(BodyBulk.apply(root, sk, gains)).override_failure_message(
				"%s: nothing built up" % path).is_greater(500)
		root.queue_free()
	# No head bone is in either table.
	for gains: Dictionary in [BodyBulk.CODY, BodyBulk.ROMAN]:
		for name: String in gains:
			assert_bool(name.to_lower().contains("head")).is_false()
