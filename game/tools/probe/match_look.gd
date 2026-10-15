extends Node
## Frames of a live AI match as the match camera shows it, for whole-frame
## look measurement against references (tools/refs/measure_look.py).
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan --resolution 640x360 \
##       --fixed-fps 30 tools/probe/match_look.tscn -- --out /tmp/look --every 30 --frames 900

var _out := "/tmp/look"
var _every := 30
var _frames := 900
var _seed := 3
var _profile := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_profile = args.has("--profile")
	for i in args.size() - 1:
		match args[i]:
			"--out": _out = args[i + 1]
			"--every": _every = int(args[i + 1])
			"--frames": _frames = int(args[i + 1])
			"--seed": _seed = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)
	var pair := Roster.pair_from_spec("cody,roman" if _profile else "")
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], _seed)
	scene.entrances = false
	add_child(scene)
	preload("res://tools/probe/capture_window.gd").configure(get_window())
	for w in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
		(w as WrestlerController).is_ai = true
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for f in _frames:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		# Exclude startup/first-use shader warmup and avoid screenshot I/O in
		# a pacing measurement. These are total rendered-frame intervals,
		# not an invented GPU-only timing.
		if _profile and f >= 120:
			samples.append(float(now - previous) / 1000.0)
		previous = now
		if not _profile and f % _every == 0 and f > 0:
			get_viewport().get_texture().get_image().save_jpg("%s/m_%05d.jpg" % [_out, f], 0.92)
	if _profile and not samples.is_empty():
		samples.sort()
		var total := 0.0
		for value in samples:
			total += value
		var adapter := RenderingServer.get_video_adapter_name()
		var software := RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_CPU \
				or adapter.to_lower().contains("llvmpipe") or adapter.to_lower().contains("lavapipe")
		var flags := preload("res://tools/probe/capture_window.gd").runtime_flags()
		var fixed: bool = flags.fixed_fps
		var movie: bool = flags.movie_maker
		var report := {
			"pipeline": RenderingServer.get_current_rendering_method(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
			"video_adapter": adapter, "software_rasterised": software,
			"processor": OS.get_processor_name(), "os": OS.get_name(),
			"resolution": str(get_viewport().get_visible_rect().size),
			"fixed_fps": fixed, "movie_maker": movie,
			"runtime_flags_verified": flags.verified,
			"performance_evidence": flags.verified and not software and not fixed and not movie,
			"physics_ticks_per_second": Engine.physics_ticks_per_second,
			"vsync_mode": DisplayServer.window_get_vsync_mode(),
			"screen_refresh_hz": DisplayServer.screen_get_refresh_rate(),
			"sample_count": samples.size(), "mean_frame_ms": total / samples.size(),
			"seed": _seed, "wrestlers": "cody,roman",
			"mean_fps": 1000.0 * samples.size() / total,
			"p50_frame_ms": samples[int((samples.size() - 1) * 0.50)],
			"p95_frame_ms": samples[int((samples.size() - 1) * 0.95)],
			"p99_frame_ms": samples[int((samples.size() - 1) * 0.99)],
			"measurement": "rendered frame intervals after 120 warmup frames; screenshot I/O disabled",
		}
		var file := FileAccess.open(_out.path_join("frame_pacing.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
		print("MATCH_FRAME_PACING ", JSON.stringify(report))
	get_tree().quit()
