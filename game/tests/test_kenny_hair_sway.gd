extends GdUnitTestSuite
## The owner, 8 Nov: "his hair should be able to move as it's long".


func test_the_lengths_swing_against_his_motion_and_settle() -> void:
	var offset := Vector3.ZERO
	var vel := Vector3.ZERO
	# He lunges forward (+x): the lengths are thrown back (-x).
	offset = KennyModel.step_sway(offset, vel, Vector3(20.0, 0.0, 0.0), 1.0 / 60.0)
	vel = KennyModel._last_sway_vel
	for i in 6:
		offset = KennyModel.step_sway(offset, vel, Vector3.ZERO, 1.0 / 60.0)
		vel = KennyModel._last_sway_vel
	assert_float(offset.x).is_less(-0.001)
	# Never further than SWAY_MAX, however hard he is thrown.
	var hard := KennyModel.step_sway(Vector3.ZERO, Vector3.ZERO, Vector3(5000.0, 0.0, 0.0), 1.0 / 60.0)
	assert_float(hard.length()).is_less_equal(KennyModel.SWAY_MAX + 1e-5)
	# And, left alone, back to rest within a few seconds.
	for i in 300:
		offset = KennyModel.step_sway(offset, vel, Vector3.ZERO, 1.0 / 60.0)
		vel = KennyModel._last_sway_vel
	assert_float(offset.length()).is_less(0.002)


func test_his_lengths_wear_the_swaying_card_shader() -> void:
	var model: Node = auto_free(load("res://scenes/kenny_model.tscn").instantiate())
	add_child(model)
	var swaying := 0
	for mi: MeshInstance3D in model.find_children("Curl*", "MeshInstance3D", true, false):
		var mat := mi.material_override
		if mi.name == "CurlCap":
			assert_object(mat).is_instanceof(StandardMaterial3D)
		else:
			assert_object(mat).is_instanceof(ShaderMaterial)
			swaying += 1
	assert_int(swaying).is_equal(3)
