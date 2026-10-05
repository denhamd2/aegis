extends GdUnitTestSuite
## The gameplay camera does not orbit (the owner: "no constant orbiting"), and
## it does not cut either: 2K26's is one continuous camera (13 cuts in ~475 s,
## gauntlet/refs/cody_roman_2k26.md). Its bearing is held through a small turn
## of the pair, stays on the broadcast side of their line, and walks round to a
## new side-on at an operator's pace.

const MATCH := "res://scenes/match.tscn"
const DT := 1.0 / 60.0


func _scene() -> Dictionary:
	CameraSettings.coverage = CameraSettings.Coverage.GAMEPLAY
	var scene: Node = load(MATCH).instantiate()
	add_child(scene)
	auto_free(scene)
	var camera: MatchCamera = scene.get_node("MatchCamera")
	camera.mode = MatchCamera.Mode.RINGSIDE
	return {"scene": scene, "camera": camera, "a": scene.get_node("WrestlerA"),
			"b": scene.get_node("WrestlerB")}


## One tick with the master shot's own cuts out of the way: the bearing of the
## handheld is what is under test, not the cut to the hard camera.
func _tick(camera: MatchCamera) -> void:
	camera.mode = MatchCamera.Mode.RINGSIDE
	camera._held = 0.0
	camera._physics_process(DT)


## The camera's bearing about the pair, as an angle.
func _yaw(camera: MatchCamera, a: Node3D, b: Node3D) -> float:
	var mid := (a.global_position + b.global_position) * 0.5
	var d := camera.global_position - mid
	return atan2(d.x, d.z)


## The two men circle each other through a full turn, as a long grapple or a
## chase would have them; the camera must not follow them round.
func test_the_camera_does_not_orbit_with_the_pair() -> void:
	var m := _scene()
	var camera: MatchCamera = m["camera"]
	var a: Node3D = m["a"]
	var b: Node3D = m["b"]
	a.global_position = Vector3(-0.7, 0.0, 0.0)
	var worst := 0.0
	var last := NAN
	var t := 0.0
	var side := camera.ringside_bearing.normalized()
	while t < 24.0:
		var turn := TAU * t / 24.0
		b.global_position = a.global_position + Vector3(sin(turn), 0.0, cos(turn)) * 1.4
		_tick(camera)
		var yaw := _yaw(camera, a, b)
		if not is_nan(last):
			worst = maxf(worst, absf(angle_difference(last, yaw)))
		last = yaw
		# Never round the back: the camera keeps to the broadcast side.
		assert_float(camera._bearing.dot(side)).override_failure_message(
				"the camera crossed to the far side at %.1f s" % t).is_greater(-0.05)
		t += DT
	# No cuts, and no swing faster than an operator walks the apron.
	assert_int(camera.bearing_cuts).is_equal(0)
	assert_float(worst).override_failure_message("a %.3f rad jump in one tick" % worst) \
			.is_less(MatchCamera.GAMEPLAY_POST_PAN_RATE * DT * 4.0)


func test_a_small_turn_does_not_move_the_camera_at_all() -> void:
	var m := _scene()
	var camera: MatchCamera = m["camera"]
	var a: Node3D = m["a"]
	var b: Node3D = m["b"]
	a.global_position = Vector3(-0.7, 0.0, 0.0)
	b.global_position = Vector3(0.7, 0.0, 0.0)
	for _i in 120:
		_tick(camera)
	var before := camera._bearing
	# The pair turn 25 degrees about each other: inside the deadzone.
	var turn := deg_to_rad(25.0)
	b.global_position = a.global_position + Vector3(cos(turn), 0.0, sin(turn)) * 1.4
	for _i in 600:
		_tick(camera)
	assert_float(absf(before.signed_angle_to(camera._bearing, Vector3.UP))).is_less(0.01)


## A big turn is followed -- by a pan, not a cut -- and the camera ends side-on.
func test_a_big_turn_is_a_pan_that_ends_side_on() -> void:
	var m := _scene()
	var camera: MatchCamera = m["camera"]
	var a: Node3D = m["a"]
	var b: Node3D = m["b"]
	a.global_position = Vector3(-0.7, 0.0, 0.0)
	b.global_position = Vector3(0.7, 0.0, 0.0)
	for _i in 120:
		_tick(camera)
	b.global_position = a.global_position + Vector3(0.0, 0.0, 1.4)
	var worst := 0.0
	var last := camera._bearing
	for _i in 600:
		_tick(camera)
		worst = maxf(worst, absf(last.signed_angle_to(camera._bearing, Vector3.UP)))
		last = camera._bearing
	assert_float(worst).is_less(MatchCamera.GAMEPLAY_POST_PAN_RATE * DT + 0.001)
	# Side-on to a line along Z is along X.
	assert_float(absf(camera._bearing.x)).is_greater(0.95)
	assert_int(camera.bearing_cuts).is_equal(0)


## No event cuts in gameplay coverage: a strike, a slam or a taunt keeps the shot.
func test_the_gameplay_camera_does_not_cut_on_impacts() -> void:
	var m := _scene()
	var camera: MatchCamera = m["camera"]
	camera._held = 5.0
	assert_bool(camera._try_cut(MatchCamera.Cut.STRIKE, m["a"], m["b"])).is_false()
	assert_bool(camera._try_cut(MatchCamera.Cut.HERO, m["a"], null)).is_false()
	assert_int(camera.mode).is_equal(MatchCamera.Mode.RINGSIDE)
