extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var session := root.get_node("MatchSession")
	var controller: FootballGraphicsController=session.graphics
	assert(controller!=null and controller.profile.id==&"balanced_60")
	assert(absf(controller.resolution_scale(Vector2i(3840,2160),1)-.5)<.001,"Retina cannot quadruple the 3D budget")
	assert(controller.resolution_scale(Vector2i(1280,720),1)==1,"Small windows are not supersampled")
	assert(controller.resolution_scale(Vector2i(1920,1080),.8)==.8)
	controller.feed_gpu_sample(0,20)
	assert(not controller.gpu_available and controller.quality==1,"Unavailable GPU timers cannot report success")
	for step in 10: controller.feed_gpu_sample(22,1)
	assert(is_equal_approx(controller.quality,.8),"Resolution has a quality floor")
	for step in 4: controller.feed_gpu_sample(8,1)
	assert(is_equal_approx(controller.quality,.8),"Recovery has hysteresis")
	controller.feed_gpu_sample(8,1)
	assert(controller.quality>.8)
	var path:="user://graphics_test.cfg"
	session.graphics_profile=&"custom";session.cinematic_motion_blur=true
	assert(session.save_preferences(path)==OK)
	session.graphics_profile=&"balanced_60";session.load_preferences(path)
	assert(session.graphics_profile==&"custom" and session.cinematic_motion_blur)
	session.load_preferences("user://absent_graphics_test.cfg")
	assert(session.graphics_profile==&"balanced_60","Legacy and absent settings migrate to Balanced 60")
	session.apply_preferences()
	assert(root.msaa_3d==Viewport.MSAA_2X and not root.use_taa)
	DirAccess.remove_absolute(path)
	print("GRAPHICS_BUDGET PASS: Retina cap, adaptive floor/hysteresis, unavailable timers, migration and persistence")
	quit()
