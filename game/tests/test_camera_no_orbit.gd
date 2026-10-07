extends GdUnitTestSuite
## The gameplay camera does not orbit (the owner: "no constant orbiting"; then
## "in wwe2k it stays as hard cam"), and it does not cut either: 2K26's is one
## continuous camera on one side of the ring (13 cuts in ~475 s,
## gauntlet/refs/cody_roman_2k26.md), square-on, sliding and dollying.

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
## chase would have them; the 2K26 hard cam does not move round with them --
## it keeps its side, square to the ring (match_engine_2k26.md, section 4).
func test_the_camera_keeps_its_side_through_a_full_turn() -> void:
	var m := _scene()
	var camera: MatchCamera = m["camera"]
	var a: Node3D = m["a"]
	var b: Node3D = m["b"]
	a.global_position = Vector3(-0.7, 0.0, 0.0)
	var t := 0.0
	while t < 24.0:
		var turn := TAU * t / 24.0
		b.global_position = a.global_position + Vector3(sin(turn), 0.0, cos(turn)) * 1.4
		_tick(camera)
		if t > 2.0:
			assert_float(camera.global_position.x).override_failure_message(
					"the camera left its side at %.1f s" % t).is_less(-6.0)
			assert_float((-camera.global_transform.basis.z).x).is_greater(0.98)
		t += DT
	assert_int(camera.bearing_cuts).is_equal(0)


## A man out on the floor: it cranes up on the same side and looks down.
func test_it_cranes_up_when_a_man_is_outside() -> void:
	var m := _scene()
	var camera: MatchCamera = m["camera"]
	var a: Node3D = m["a"]
	var b: Node3D = m["b"]
	a.global_position = Vector3(0.0, 0.0, 2.0)
	b.global_position = Vector3(0.0, -1.0, 4.2)
	for _i in 600:
		_tick(camera)
	assert_float(camera.global_position.y).is_greater(2.5)
	assert_float(camera.global_position.x).is_less(-6.0)


## Spread across the ring: the high wide.
func test_it_goes_high_and_wide_when_they_are_spread_out() -> void:
	var m := _scene()
	var camera: MatchCamera = m["camera"]
	var a: Node3D = m["a"]
	var b: Node3D = m["b"]
	a.global_position = Vector3(-2.5, 0.0, -2.5)
	b.global_position = Vector3(2.5, 0.0, 2.5)
	for _i in 600:
		_tick(camera)
	assert_float(camera.global_position.y).is_greater(4.0)
	assert_float(camera.fov).is_greater(MatchCamera.GAMEPLAY_FOV + 5.0)


## No event cuts in gameplay coverage: a strike, a slam or a taunt keeps the shot.
func test_the_gameplay_camera_does_not_cut_on_impacts() -> void:
	var m := _scene()
	var camera: MatchCamera = m["camera"]
	camera._held = 5.0
	assert_bool(camera._try_cut(MatchCamera.Cut.STRIKE, m["a"], m["b"])).is_false()
	assert_bool(camera._try_cut(MatchCamera.Cut.HERO, m["a"], null)).is_false()
	assert_int(camera.mode).is_equal(MatchCamera.Mode.RINGSIDE)
