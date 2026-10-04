extends GdUnitTestSuite
## The gameplay camera does not orbit: its bearing is held, and a change of
## side-on is a CUT -- instant, rare, and never sooner than a few seconds after
## the last. The owner: "no constant orbiting".

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
	var big_steps := 0
	var last := NAN
	var t := 0.0
	while t < 24.0:
		var turn := TAU * t / 24.0
		b.global_position = a.global_position + Vector3(sin(turn), 0.0, cos(turn)) * 1.4
		_tick(camera)
		var yaw := _yaw(camera, a, b)
		if not is_nan(last):
			var step := absf(angle_difference(last, yaw))
			worst = maxf(worst, step)
			if step > 0.15:
				big_steps += 1
		last = yaw
		t += DT
	# A cut is allowed to move it a long way in one frame; what is not allowed
	# is a continuous swing, and only a few cuts in a full circle.
	assert_int(camera.bearing_cuts).override_failure_message(
			"%d cuts in a full turn of the pair (a cut per 57 degrees is the floor)" % camera.bearing_cuts).is_less_equal(8)
	assert_int(big_steps).override_failure_message("%d jumps vs %d cuts" % [
			big_steps, camera.bearing_cuts]).is_less_equal(camera.bearing_cuts + 1)
	CameraSettings.coverage = CameraSettings.Coverage.GAMEPLAY


func test_a_small_turn_does_not_move_the_camera_at_all() -> void:
	var m := _scene()
	var camera: MatchCamera = m["camera"]
	var a: Node3D = m["a"]
	var b: Node3D = m["b"]
	a.global_position = Vector3(-0.7, 0.0, 0.0)
	b.global_position = Vector3(0.7, 0.0, 0.0)
	for _i in 120:
		_tick(camera)
	var before := _yaw(camera, a, b)
	# The pair turn 30 degrees about each other: well inside the deadzone.
	var turn := deg_to_rad(30.0)
	b.global_position = a.global_position + Vector3(cos(turn), 0.0, sin(turn)) * 1.4
	for _i in 600:
		_tick(camera)
	assert_float(absf(angle_difference(before, _yaw(camera, a, b)))).is_less(0.12)
	assert_int(camera.bearing_cuts).is_equal(0)


func test_cuts_come_at_least_a_few_seconds_apart() -> void:
	var m := _scene()
	var camera: MatchCamera = m["camera"]
	var a: Node3D = m["a"]
	var b: Node3D = m["b"]
	a.global_position = Vector3(-0.7, 0.0, 0.0)
	var cut_times := []
	var seen := 0
	var t := 0.0
	while t < 40.0:
		# Spin fast: a worst case for a camera that chases.
		var turn := TAU * t / 8.0
		b.global_position = a.global_position + Vector3(sin(turn), 0.0, cos(turn)) * 1.4
		_tick(camera)
		if camera.bearing_cuts != seen:
			seen = camera.bearing_cuts
			cut_times.append(t)
		t += DT
	for i in range(1, cut_times.size()):
		assert_float(cut_times[i] - cut_times[i - 1]).override_failure_message(
				"cuts at %s" % [cut_times]).is_greater_equal(MatchCamera.GAMEPLAY_POST_CUT_HOLD - 0.05)
