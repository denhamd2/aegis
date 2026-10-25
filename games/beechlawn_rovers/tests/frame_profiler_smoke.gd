extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var session:=root.get_node("MatchSession")
	var profiler:=FootballFrameProfiler.new();root.add_child(profiler)
	var path:="user://frame_profiler_smoke.csv"
	profiler.begin(path,session.graphics,0)
	Engine.time_scale=.01
	for frame in 12:
		OS.delay_msec(2)
		await process_frame
	Engine.time_scale=1.0
	var report:=profiler.finish()
	assert(report.samples>=10 and report.p95_ms>1,"Frame pacing must use wall time, not time-scaled engine delta")
	assert(not report.meets_frame_target,"A short headless trace cannot pass target hardware acceptance")
	assert(FileAccess.get_file_as_string(path).contains("gpu_available"))
	assert(JSON.parse_string(FileAccess.get_file_as_string(path+".json")).has("frame_clock"))
	profiler.free()
	for suffix in ["",".json",".summary.json"]:DirAccess.remove_absolute(path+suffix)
	print("FRAME_PROFILER PASS: monotonic pacing despite time scale, inspectable telemetry and no false hardware pass")
	quit()
