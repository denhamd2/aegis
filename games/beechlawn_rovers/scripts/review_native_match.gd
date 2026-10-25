extends SceneTree
## A stationary capture of the actual 11v11 scene and shipping broadcast camera.
## No review lighting, replacement stadium or gameplay camera is substituted.
var options: Dictionary = {}

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair := argument.substr(2).split("=", true, 1)
			options[pair[0]] = pair[1]
	call_deferred("_capture")

func _capture() -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus" or not options.has("capture-dir"):
		push_error("Native match capture requires Forward+ and --capture-dir=...")
		quit(2)
		return
	var session := root.get_node("MatchSession")
	session.launched_from_menu = false
	session.camera_preset = &"close_broadcast"
	session.camera_height = 0.0
	session.camera_zoom = 0.0
	session.camera_angle = 0.0
	session.weather_preset = &"sunny"
	var game := load("res://scenes/match_11v11.tscn").instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.call("_set_players_physics_enabled", false)
	var rig := game.get_node("BroadcastCamera")
	rig.call("reset_tracking")
	rig.set_process(false)
	for _frame in range(3):
		await RenderingServer.frame_post_draw
		print("NATIVE_MATCH_DRAW ", _frame + 1)
	paused = true
	var output := str(options["capture-dir"])
	DirAccess.make_dir_recursive_absolute(output)
	var image := root.get_texture().get_image()
	if image.save_png(output.path_join("match_broadcast.png")) != OK:
		quit(2)
		return
	# The team's arrays are the authoritative actor inventory, independent of groups.
	var home: Array = game.get("_home_players")
	var away: Array = game.get("_away_players")
	var official_count := get_nodes_in_group("match_officials").size()
	var report := {
		"rendering_method":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),
		"vendor":RenderingServer.get_video_adapter_vendor(),
		"api":RenderingServer.get_video_adapter_api_version(),
		"display_server":DisplayServer.get_name(), "godot":Engine.get_version_info().string,
		"resolution":[image.get_width(),image.get_height()], "msaa_3d":root.msaa_3d,
		"scene":"res://scenes/match_11v11.tscn", "camera":"close_broadcast",
		"weather":"sunny", "sun_shadows":game.get_node("Sun").shadow_enabled,
		"home_players":home.size(), "away_players":away.size(), "officials":official_count,
		"phase":"stationary kickoff", "warmup_frames":3,
		"scope":"Actual Forward+ match still; no native Mac timing or graphics parity claim.",
	}
	assert(home.size() == 11 and away.size() == 11 and official_count == 1)
	var file := FileAccess.open(output.path_join("match_broadcast.json"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(report,"  ") + "\n")
	print("BEECHLAWN_NATIVE_CAPTURE ", JSON.stringify(report))
	quit()
