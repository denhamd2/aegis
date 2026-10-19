extends GdUnitTestSuite
## Camera motion blur (MotionBlur): Forward+ only, never on a frame that cut,
## and switchable from OPTIONS > MOTION BLUR.

const MATCH_SCENE := preload("res://scenes/match.tscn")


func before_test() -> void:
	CameraSettings.motion_blur = true


func after_test() -> void:
	CameraSettings.motion_blur = true


func _camera() -> MatchCamera:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	return scene.get_node("MatchCamera")


func test_only_forward_plus_has_the_velocity_buffer_it_needs() -> void:
	assert_bool(MotionBlur.supported("forward_plus")).is_true()
	assert_bool(MotionBlur.supported("mobile")).is_false()
	assert_bool(MotionBlur.supported("gl_compatibility")).is_false()
	# and the camera attaches it exactly when the renderer can run it
	var camera := _camera()
	var expected := MotionBlur.supported(RenderingServer.get_current_rendering_method())
	assert_bool(camera.motion_blur != null).is_equal(expected)


func test_the_shader_compiles() -> void:
	# Needs a GPU device; headless has none, and the render probes cover it.
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		return
	var spirv := MotionBlur.compile(rd)
	assert_str(spirv.compile_error_compute).is_empty()
	rd.free()


func test_open_play_gets_the_light_shutter_and_off_gets_none() -> void:
	var camera := _camera()
	assert_float(camera.blur_intensity()).is_equal(MatchCamera.BLUR_BASE)
	CameraSettings.motion_blur = false
	assert_float(camera.blur_intensity()).is_equal(0.0)


func test_a_frame_that_cut_is_not_blurred() -> void:
	var camera := _camera()
	camera._cut_guard.cut_frame = Engine.get_process_frames()
	assert_float(camera.blur_intensity()).is_equal(0.0)
	camera._cut_guard.cut_frame = Engine.get_process_frames() - 5
	assert_float(camera.blur_intensity()).is_equal(MatchCamera.BLUR_BASE)


func test_the_options_row_switches_it() -> void:
	var row := -1
	for i in TitleScreen.CAMERA_ROWS.size():
		if TitleScreen.CAMERA_ROWS[i][0] == "MOTION BLUR":
			row = i
	assert_int(row).is_equal(5)
	var screen: TitleScreen = auto_free(TitleScreen.new())
	screen.camera_row = row
	assert_int(screen.camera_option(row)).is_equal(0)
	screen.step_camera_option(1)
	assert_bool(CameraSettings.motion_blur).is_false()
	assert_int(screen.camera_option(row)).is_equal(1)
	screen.step_camera_option(1)
	assert_bool(CameraSettings.motion_blur).is_true()
