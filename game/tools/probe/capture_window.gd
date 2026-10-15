extends RefCounted
## Probe-only pixel sizing. The game's maximized startup must not silently
## replace the requested resolution during a reference/performance capture.


static func configure(window: Window) -> Vector2i:
	var pixels := Vector2i(1920, 1080)
	# Godot consumes engine flags before exposing get_cmdline_args(). Pass
	# the probe's desired pixel size after -- as well as the window CLI flag.
	var args := OS.get_cmdline_user_args()
	var index := args.find("--capture-resolution")
	if index >= 0 and index + 1 < args.size():
		var parts := args[index + 1].split("x")
		if parts.size() == 2 and int(parts[0]) > 0 and int(parts[1]) > 0:
			pixels = Vector2i(int(parts[0]), int(parts[1]))
	if DisplayServer.get_name() != "headless":
		window.mode = Window.MODE_WINDOWED
		window.content_scale_size = pixels
		window.size = pixels
	return pixels


static func runtime_flags() -> Dictionary:
	# Read only our own process command after sampling. Engine flags such as
	# --fixed-fps are absent from OS.get_cmdline_args(), so checking that array
	# would incorrectly label fixed-time captures as performance evidence.
	var output: Array = []
	if OS.get_name() not in ["macOS", "Linux"] \
			or OS.execute("/bin/ps", ["-ww", "-p", str(OS.get_process_id()), "-o", "command="], output) != 0:
		return {"verified": false, "fixed_fps": false, "movie_maker": false}
	var command := " ".join(output)
	var fixed := RegEx.create_from_string("(?:^|\\s)--fixed-fps(?:[=\\s]|$)")
	var movie := RegEx.create_from_string("(?:^|\\s)--write-movie(?:[=\\s]|$)")
	return {"verified": not command.strip_edges().is_empty(),
		"fixed_fps": fixed.search(command) != null,
		"movie_maker": movie.search(command) != null}
