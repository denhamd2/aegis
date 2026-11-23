extends GdUnitTestSuite
## Exercise the real begin/finish path without models or an arena. Simulation
## frame durations must not stretch when game time is slowed for presentation.


func test_fallback_finishes_on_the_same_simulation_frame_under_slow_motion() -> void:
	var original_scale := Engine.time_scale
	var durations: Array[int] = []
	for scale: float in [1.0, .5]:
		Engine.time_scale = scale
		var rig := GrappleRig.new()
		add_child(rig)
		var a := CharacterBody3D.new()
		var d := CharacterBody3D.new()
		add_child(a)
		add_child(d)
		a.set_physics_process(true)
		d.set_physics_process(true)
		a.position = Vector3(-.4, 0, 0)
		d.position = Vector3(.4, 0, 0)
		var move := MoveDef.new()
		move.startup_frames = 2
		move.active_frames = 2
		move.recovery_frames = 3
		var finished: Array[int] = []
		rig.grapple_finished.connect(func(_a, _d): finished.append(Engine.get_physics_frames()))
		var start := Engine.get_physics_frames()
		rig.begin(a, d, move)
		for _tick in 200:
			await get_tree().physics_frame
			if not rig.is_active(): break
		assert_int(finished.size()).is_equal(1)
		if not finished.is_empty():
			durations.append(finished[0] - start)
			assert_int(finished[0] - start).is_equal(rig.lead_in_ticks + move.total_frames())
		assert_bool(a.is_physics_processing()).is_true()
		assert_bool(d.is_physics_processing()).is_true()
		rig.free()
		a.free()
		d.free()
	Engine.time_scale = original_scale
	assert_int(durations.size()).is_equal(2)
	if durations.size() == 2: assert_int(durations[0]).is_equal(durations[1])


func test_cancelled_lead_in_cannot_finish_a_replacement_grapple() -> void:
	var rig: GrappleRig = auto_free(GrappleRig.new())
	var a: CharacterBody3D = auto_free(CharacterBody3D.new())
	var d: CharacterBody3D = auto_free(CharacterBody3D.new())
	for node: Node in [rig, a, d]:
		add_child(node)
	a.set_physics_process(true)
	d.set_physics_process(true)
	a.position.x = -0.4
	d.position.x = 0.4
	var move := MoveDef.new()
	var finished: Array[int] = []
	rig.grapple_finished.connect(func(_a, _d): finished.append(Engine.get_physics_frames()))
	rig.begin(a, d, move)
	rig.cancel()
	var start := Engine.get_physics_frames()
	rig.begin(d, a, move)
	var duration := rig.lead_in_ticks + move.total_frames()
	for tick in 200:
		await get_tree().physics_frame
		if not rig.is_active():
			break
	assert_array(finished).is_equal([start + duration])
	assert_bool(a.is_physics_processing()).is_true()
	assert_bool(d.is_physics_processing()).is_true()
