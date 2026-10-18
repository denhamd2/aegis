extends GdUnitTestSuite
## Fight Forever coverage, the default (gauntlet/refs/aew_ff_animation_review.md):
## a high wide camera on one side; every grapple cuts in close, with the stage
## behind, and back out wide on the impact; ordinary strikes stay wide, a
## signature or special strike gets a short close-up.

const MATCH_SCENE := preload("res://scenes/match.tscn")


func before_test() -> void:
	CameraSettings.coverage = CameraSettings.Coverage.FIGHT_FOREVER
	CameraSettings.cuts = true


func _match() -> Node:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	return scene


func _move(startup: int, active: int, recovery: int, file := "") -> MoveDef:
	var m := MoveDef.new()
	m.startup_frames = startup
	m.active_frames = active
	m.recovery_frames = recovery
	if file != "":
		# by its animation's name: a second MoveDef cannot take the path of
		# one the match has already loaded
		m.animation_pair_id = StringName(file)
	return m


func test_it_is_the_default_coverage() -> void:
	assert_int(CameraSettings.Coverage.FIGHT_FOREVER).is_equal(CameraSettings.coverage)
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	assert_int(camera.master_mode()).is_equal(MatchCamera.Mode.RINGSIDE)
	camera.mode = MatchCamera.Mode.RINGSIDE
	assert_float(camera.shot_fov()).is_equal_approx(MatchCamera.FF_FOV, 0.001)
	assert_float(camera.shot_hold()).is_equal(INF)


func test_the_game_camera_is_high_and_on_one_side() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: Node3D = scene.get_node("WrestlerA")
	var b: Node3D = scene.get_node("WrestlerB")
	camera.mode = MatchCamera.Mode.RINGSIDE
	for pos: Array in [[Vector3(-1, 0, -1), Vector3(1, 0, 1)], [Vector3(1, 0, 1), Vector3(-1, 0, -1)],
			[Vector3(0, 0, 2), Vector3(0, 0, -2)]]:
		a.global_position = pos[0]
		b.global_position = pos[1]
		for i in 120:
			camera._physics_process(1.0 / 60.0)
		var mid := (a.global_position + b.global_position) * 0.5
		# up high, looking down onto the canvas
		assert_float(camera.global_position.y - mid.y).is_greater(3.5)
		# always on the hard camera's side, however the pair stand
		assert_float(camera.global_position.x).is_less(mid.x - 5.0)


func test_a_grapple_cuts_in_close_toward_the_stage_and_out_on_the_impact() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.global_position = Vector3(-0.5, 0, 0)
	b.global_position = Vector3(0.5, 0, 0)
	camera.mode = MatchCamera.Mode.RINGSIDE
	var move := _move(60, 6, 34)
	camera._on_grapple_started(a, b, move)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.EVENT_CUT)
	assert_float(camera._cut_ff_impact).is_equal_approx(0.6 - MatchCamera.FF_IMPACT_LEAD, 0.001)
	assert_bool(camera.is_close_up()).is_true()
	assert_bool(camera._event_shot(1.0 / 60.0)).is_true()
	var mid := (a.global_position + b.global_position) * 0.5
	assert_float(camera.global_position.distance_to(mid)).is_less(3.5)
	assert_float(camera.global_position.y).is_between(0.9, 1.4)
	# looking toward the stage (-Z), so the screens are behind the pair
	assert_float(camera.global_position.z).is_greater(mid.z + 1.5)
	# no paired move playing any more -- the impact has passed: out wide
	camera.grapple_rig = null
	camera._update_mode(1.0 / 60.0)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.RINGSIDE)


func test_the_close_up_pulls_back_for_a_man_held_overhead() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.global_position = Vector3(-0.5, 0, 0)
	b.global_position = Vector3(0.5, 0, 0)
	await get_tree().process_frame
	camera.mode = MatchCamera.Mode.RINGSIDE
	camera._on_grapple_started(a, b, _move(60, 6, 34))
	camera._event_shot(1.0 / 60.0)
	var mid := Vector3(0, 0, 0)
	var standing := camera.global_position.distance_to(mid)
	# Hoisted: a metre off the mat, as a Tiger Driver holds him; the lens
	# measures from the lower man's feet.
	camera._on_grapple_started(a, b, _move(60, 6, 34))
	b.global_position.y = 1.0
	await get_tree().process_frame
	camera._event_shot(1.0 / 60.0)
	var top := camera._pair_top()
	assert_float(top).is_greater(2.5)
	var held := camera.global_position.distance_to(mid)
	assert_float(held).is_greater(standing + 0.5)
	# and the top of him is inside the vertical field of view
	var to_top := Vector3(0.5, top, 0) - camera.global_position
	var aim := -camera.global_transform.basis.z
	var up_angle := rad_to_deg(asin(clampf(to_top.normalized().y, -1, 1))) \
			- rad_to_deg(asin(clampf(aim.y, -1, 1)))
	assert_float(up_angle).is_less(camera.fov * 0.5)


func test_ordinary_strikes_stay_wide_and_a_signature_strike_cuts() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	camera.grapple_rig = null
	camera.mode = MatchCamera.Mode.RINGSIDE
	camera._held = 5.0
	var punch := _move(12, 4, 24, "strike_cross")
	punch.damage_head = 12.0
	camera._on_move_landed(a, b, punch)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.RINGSIDE)
	var sig := _move(52, 8, 24, "signature_superman_punch")
	sig.damage_head = 14.0
	camera._on_move_landed(a, b, sig)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.EVENT_CUT)
	assert_float(camera._cut_hold).is_equal_approx(MatchCamera.FF_STRIKE_HOLD, 0.001)


func test_running_attacks_and_dives_stay_wide() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	camera.mode = MatchCamera.Mode.RINGSIDE
	for file: String in ["running_cyclone_kick", "dive_tope_suicida", "ground_stomp_body"]:
		camera._on_grapple_started(a, b, _move(18, 5, 46, file))
		assert_int(camera.mode).override_failure_message(file).is_equal(MatchCamera.Mode.RINGSIDE)
	# a standing grapple cuts in
	camera._on_grapple_started(a, b, _move(60, 6, 34, "power_bodyslam"))
	assert_int(camera.mode).is_equal(MatchCamera.Mode.EVENT_CUT)
