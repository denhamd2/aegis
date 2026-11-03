extends GdUnitTestSuite
## The owner, 3 Nov: on his M1 MacBook "at times the gameplay can become a bit
## janky and animations can get a bit like stop motion". The 3D is rendered
## under the Retina panel's size and upscaled, AUTO holding 60 fps.

const FramePacer := preload("res://core/render/frame_pacer.gd")


func after_test() -> void:
	GraphicsSettings.set_quality(GraphicsSettings.Quality.AUTO)


func test_auto_is_the_default_and_moves_the_3d_resolution() -> void:
	assert_int(GraphicsSettings.current()).is_equal(GraphicsSettings.Quality.AUTO)
	var s := GraphicsSettings.settings_for(GraphicsSettings.Quality.AUTO, 0.7)
	assert_float(float(s[0])).is_equal_approx(0.7, 0.001)
	assert_bool(bool(s[2])).is_true()
	# never under its floor
	s = GraphicsSettings.settings_for(GraphicsSettings.Quality.AUTO, 0.1)
	assert_float(float(s[0])).is_equal(GraphicsSettings.MIN_SCALE)


func test_auto_steps_down_when_frames_run_long_and_back_up_when_short() -> void:
	# a 60 fps frame is 16.7 ms
	assert_float(FramePacer.step_scale(0.85, 22.0)).is_equal_approx(0.80, 0.001)
	assert_float(FramePacer.step_scale(0.80, 10.0)).is_equal_approx(0.85, 0.001)
	# in the band between, it holds -- no hunting
	assert_float(FramePacer.step_scale(0.85, 15.0)).is_equal_approx(0.85, 0.001)
	# and stays inside its range
	assert_float(FramePacer.step_scale(GraphicsSettings.MIN_SCALE, 40.0)) \
			.is_equal(GraphicsSettings.MIN_SCALE)
	assert_float(FramePacer.step_scale(GraphicsSettings.MAX_SCALE, 5.0)) \
			.is_equal(GraphicsSettings.MAX_SCALE)


func test_high_is_the_full_look_and_the_others_render_less() -> void:
	var high: Array = GraphicsSettings.TIERS[GraphicsSettings.Quality.HIGH]
	assert_float(float(high[0])).is_equal(1.0)
	assert_int(int(high[1])).is_equal(Viewport.MSAA_4X)
	var perf: Array = GraphicsSettings.TIERS[GraphicsSettings.Quality.PERFORMANCE]
	var bal: Array = GraphicsSettings.TIERS[GraphicsSettings.Quality.BALANCED]
	assert_float(float(perf[0])).is_less(float(bal[0]))
	assert_float(float(bal[0])).is_less(1.0)


func test_a_mac_upscales_with_metalfx() -> void:
	assert_int(GraphicsSettings.upscaler("metal")).is_equal(Viewport.SCALING_3D_MODE_METALFX_SPATIAL)
	assert_int(GraphicsSettings.upscaler("vulkan")).is_equal(Viewport.SCALING_3D_MODE_FSR)


func test_apply_sets_the_viewport() -> void:
	var vp := SubViewport.new()
	auto_free(vp)
	add_child(vp)
	GraphicsSettings.apply(vp, GraphicsSettings.Quality.PERFORMANCE)
	assert_float(vp.scaling_3d_scale).is_equal_approx(0.6, 0.001)
	assert_int(vp.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	assert_int(vp.scaling_3d_mode).is_not_equal(Viewport.SCALING_3D_MODE_BILINEAR)
	GraphicsSettings.apply(vp, GraphicsSettings.Quality.HIGH)
	assert_float(vp.scaling_3d_scale).is_equal(1.0)
	assert_int(vp.scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_BILINEAR)


func test_the_options_menu_has_graphics() -> void:
	var row := -1
	for i in TitleScreen.CAMERA_ROWS.size():
		if TitleScreen.CAMERA_ROWS[i][0] == "GRAPHICS":
			row = i
	assert_int(row).is_equal(6)
	assert_int((TitleScreen.CAMERA_ROWS[row][1] as Array).size()) \
			.is_equal(GraphicsSettings.Quality.size())
	assert_int(TitleScreen.camera_option(row)).is_equal(GraphicsSettings.Quality.AUTO)
