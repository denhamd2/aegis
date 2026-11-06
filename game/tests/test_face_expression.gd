extends GdUnitTestSuite
## Detailed roster faces have both runtime pain controls after their rest
## sculpt and material work, and each control actually moves face vertices.


func test_detailed_wrestlers_have_two_deforming_pain_shapes() -> void:
	for name: String in ["roman", "cody", "kenny"]:
		var scene := load("res://scenes/%s_model.tscn" % name) as PackedScene
		var model := scene.instantiate() as Node3D
		add_child(model)
		var expression := FaceExpression.new()
		expression.install(model)
		assert_int(expression.meshes.size()).override_failure_message(name).is_greater(0)
		var deforming := [false, false]
		for mi in expression.meshes:
			assert_int(mi.mesh.get_blend_shape_count()).is_equal(2)
			for s in mi.mesh.get_surface_count():
				var shapes := mi.mesh.surface_get_blend_shape_arrays(s)
				for key in 2:
					var vertices := shapes[key][Mesh.ARRAY_VERTEX] as PackedVector3Array
					for v in vertices:
						if v.length_squared() > 0.00000001:
							deforming[key] = true
		assert_bool(deforming[0]).override_failure_message(name + " open").is_true()
		assert_bool(deforming[1]).override_failure_message(name + " clench").is_true()
		expression.free()
		remove_child(model)
		model.free()
