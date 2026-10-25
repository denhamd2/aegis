extends Node
class_name FootballGraphicsController
## CPU/GPU work timing is distinct from VSync-limited frame duration.
var profile: FootballGraphicsProfile
var quality := 1.0
var gpu_available := false
var gpu_ms := 0.0
var cpu_render_ms := 0.0
var _elapsed := 0.0
var _headroom := 0.0
var _samples: Array[float] = []
var _last_size := Vector2i.ZERO
var _effective_scale := 1.0
var _session: Node

func _ready() -> void:
	_session = get_parent()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	configure()

func configure() -> void:
	profile = FootballGraphicsProfile.from_id(_session.graphics_profile)
	quality = 1.0; _headroom=0; _samples.clear()
	var viewport := get_viewport()
	viewport.use_taa = profile.id==&"custom" and _session.temporal_aa and RenderingServer.get_current_rendering_method()=="forward_plus"
	viewport.msaa_3d = Viewport.MSAA_2X if profile.id==&"balanced_60" or viewport.use_taa else Viewport.MSAA_4X
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if profile.id==&"balanced_60" and RenderingServer.get_current_rendering_method()=="forward_plus" else Viewport.SCALING_3D_MODE_BILINEAR
	if DisplayServer.get_name()!="headless":
		Engine.max_fps=profile.fps_limit
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_apply_resolution()

static func resolution_scale(pixel_size: Vector2i, factor: float) -> float:
	if pixel_size.x<=0 or pixel_size.y<=0: return 1.0
	return clampf(minf(1.0,minf(1920.0/pixel_size.x,1080.0/pixel_size.y))*factor,.1,1.0)

func _apply_resolution() -> void:
	# Use the physical window, never the already-scaled render target. Reading
	# that target feeds adaptive scale back into the Retina cap and oscillates.
	var size := DisplayServer.window_get_size(get_window().get_window_id())
	var target := resolution_scale(size,quality) if profile.id==&"balanced_60" else 1.0
	if absf(target-_effective_scale)>.001 or size!=_last_size:
		get_viewport().scaling_3d_scale=target
		_effective_scale=target;_last_size=size

func feed_gpu_sample(milliseconds: float, seconds: float) -> void:
	# A zero headless/unsupported timer is unavailable data, never a fast GPU.
	gpu_available=milliseconds>0
	if profile.id!=&"balanced_60" or not gpu_available: return
	if milliseconds>profile.gpu_budget_ms:
		quality=maxf(profile.minimum_quality,quality-.05);_headroom=0
	elif milliseconds<11.0:
		_headroom+=seconds
		if _headroom>=5:
			quality=minf(profile.maximum_quality,quality+.05);_headroom=0
	else: _headroom=0

func _process(delta: float) -> void:
	if profile==null: return
	var viewport := get_viewport().get_viewport_rid()
	gpu_ms=RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	cpu_render_ms=RenderingServer.viewport_get_measured_render_time_cpu(viewport)+RenderingServer.get_frame_setup_time_cpu()
	if gpu_ms>0: _samples.append(gpu_ms)
	_elapsed+=delta
	if _elapsed>=1:
		var mean := 0.0
		for value in _samples: mean+=value
		feed_gpu_sample(mean/maxi(1,_samples.size()),_elapsed)
		_samples.clear();_elapsed=0
	_apply_resolution()

func metrics() -> Dictionary:
	return {"profile":str(profile.id),"quality":quality,"scale":_effective_scale,
		"gpu_available":gpu_available,"gpu_ms":gpu_ms,"cpu_render_ms":cpu_render_ms,
		"renderer":RenderingServer.get_current_rendering_method(),
		"driver":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(),"viewport":str(_last_size)}
