extends Node
class_name FootballFrameProfiler
## Explicit benchmark telemetry. Frame durations include pacing; work timers do not.
var stream: FileAccess
var frames: Array[float]=[]
var _elapsed:=0.0
var _warmup:=30.0
var _graphics: FootballGraphicsController
var output: String
var _loading_frames:=0
var _started_usec:=0
var _last_usec:=0
func mark_loading() -> void:_loading_frames=2
func begin(path: String, budget: FootballGraphicsController, warmup:=30.0) -> void:
	output=path;_graphics=budget;_warmup=warmup
	_started_usec=Time.get_ticks_usec();_last_usec=_started_usec
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	stream=FileAccess.open(path,FileAccess.WRITE)
	assert(stream!=null,"Cannot create benchmark output")
	stream.store_csv_line(["seconds","frame_ms","cpu_process_ms","cpu_physics_ms","cpu_render_ms","gpu_ms","gpu_available","quality","render_scale","draw_calls","primitives","static_memory_bytes","phase"])
	var metadata:=budget.metrics()
	metadata.merge({"build":JSON.parse_string(FileAccess.get_file_as_string("res://data/build_info.json")),"processor":OS.get_processor_name(),"os":OS.get_name(),"os_version":OS.get_version(),"engine":Engine.get_version_info(),"warmup_seconds":warmup,"frame_clock":"Monotonic wall time; known scene-loading frames retained in CSV and excluded from frame-target statistics","scope":"Only native Mac hardware can establish M1 performance acceptance."})
	var file:=FileAccess.open(path+".json",FileAccess.WRITE);file.store_string(JSON.stringify(metadata,"  "))
func _process(_delta: float) -> void:
	if stream==null:return
	var now:=Time.get_ticks_usec();var frame_ms:float=float(now-_last_usec)/1000.0
	_last_usec=now;_elapsed=float(now-_started_usec)/1000000.0
	var m:=_graphics.metrics()
	if _elapsed>=_warmup and _loading_frames==0:frames.append(frame_ms)
	var game:=get_tree().current_scene
	var phase:="loading"
	if game!=null and game.has_method("surface_height"):
		phase="intro" if game._intro_active else ("presentation" if game._presentation_active else "play")
	if _loading_frames>0:phase="loading";_loading_frames-=1
	stream.store_csv_line([str(_elapsed),str(frame_ms),str(Performance.get_monitor(Performance.TIME_PROCESS)*1000),str(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000),str(m.cpu_render_ms),str(m.gpu_ms),str(m.gpu_available),str(m.quality),str(m.scale),str(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),str(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),str(OS.get_static_memory_usage()),phase])
func finish() -> Dictionary:
	set_process(false)
	if stream!=null:stream.flush();stream.close();stream=null
	frames.sort()
	var total:=0.0;var slow:=0
	for value in frames:
		total+=value
		if value>33.333:slow+=1
	var report:={"wall_seconds":_elapsed,"samples":frames.size(),"mean_fps":1000*frames.size()/maxf(.001,total),"p95_ms":percentile(.95),"p99_ms":percentile(.99),"over_33ms_fraction":float(slow)/maxi(1,frames.size()),"target_hardware":OS.get_name()=="macOS" and OS.get_processor_name().contains("M1"),"gpu_available":_graphics.gpu_available}
	report["meets_frame_target"]=report.target_hardware and report.gpu_available and frames.size()>=36000 and _elapsed>=900 and report.mean_fps>=59 and report.p99_ms<20 and report.over_33ms_fraction<.001
	var file:=FileAccess.open(output+".summary.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	return report
func percentile(fraction: float) -> float:
	return frames[mini(frames.size()-1,int(frames.size()*fraction))] if not frames.is_empty() else 0.0
