extends Node
## Repeatable screenshots of the shipping match scene, with renderer metadata.
## Run with a real display and Forward+: --fixed-fps 60 -- --out DIR --view master.
## A software renderer can support appearance review, never Mac performance claims.

var output := "/tmp/aegis-reference"
var view := "master"
var settle := 24
var section_only := false
var environment_only := false
var no_fog := false
var no_screen_effects := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	section_only = args.has("--section")
	environment_only = args.has("--environment-only")
	no_fog = args.has("--no-fog")
	no_screen_effects = args.has("--no-screen-effects")
	for i in maxi(args.size() - 1, 0):
		match args[i]:
			"--out": output = args[i + 1]
			"--view": view = args[i + 1]
			"--settle": settle = maxi(int(args[i + 1]), 1)
	DirAccess.make_dir_recursive_absolute(output)
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("Reference appearance capture requires the shipping Forward+ renderer.")
		get_tree().quit(2)
		return
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("cody"), Roster.by_id("roman"), 3)
	scene.entrances = false
	if section_only:
		scene.get_node("Arena").set_script(load("res://tools/probe/reference_section_arena.gd"))
	var master := scene.get_node("MatchCamera") as MatchCamera
	var camera_origin := master.hard_cam_position
	var camera_fov := master.hard_cam_fov
	var camera_aim := master.hard_cam_aim
	if no_fog or no_screen_effects:
		var world := scene.get_node("WorldEnvironment") as WorldEnvironment
		world.environment = world.environment.duplicate(true)
		if no_fog:
			world.environment.volumetric_fog_enabled = false
		if no_screen_effects:
			world.environment.ssao_enabled = false
			world.environment.ssil_enabled = false
			world.environment.ssr_enabled = false
			world.environment.glow_enabled = false
	if environment_only:
		# Asset-only mode omits actors and match logic. It is useful for a
		# bounded material review, and explicitly labelled in the manifest.
		scene.set_script(null)
		for child in scene.get_children():
			if child.name not in ["Ring", "Arena", "WorldEnvironment", "LightRig", "RingReflections"]:
				child.free()
	add_child(scene)
	print("REFERENCE_LOOK scene ready; section_only=", section_only)
	await get_tree().physics_frame
	preload("res://tools/probe/capture_window.gd").configure(get_window())
	if not environment_only:
		for item in ["WrestlerA", "WrestlerB"]:
			var wrestler := scene.get_node(item) as WrestlerController
			wrestler.is_ai = false
			wrestler.set_physics_process(false)
			if wrestler.ai:
				wrestler.ai.set_physics_process(false)
			wrestler.play_presentation_clip("strikes/face_off", true)
		var a := scene.get_node("WrestlerA") as WrestlerController
		var b := scene.get_node("WrestlerB") as WrestlerController
		a.global_position = Vector3(0.0, 0.0, -0.45)
		b.global_position = Vector3(0.0, 0.0, 0.45)
		a.look_at(b.global_position)
		b.look_at(a.global_position)
		(scene.get_node("MatchHUD") as CanvasLayer).visible = false
		master.set_physics_process(false)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = camera_fov
	camera.look_at_from_position(camera_origin, Vector3(0.0, camera_aim, 0.0))
	if view == "corner":
		camera.fov = 43.0
		camera.look_at_from_position(Vector3(-8.5, 2.1, 4.5), Vector3(-2.7, 0.0, 2.3))
	elif view == "crowd":
		camera.fov = 45.0
		camera.look_at_from_position(Vector3(4.6, 0.6, 2.0), Vector3(7.4, 0.15, 0.0))
	elif view == "bodies":
		camera.fov = 38.0
		camera.look_at_from_position(Vector3(-3.2, 1.6, 0.2), Vector3(0.0, 1.15, 0.0))
	camera.make_current()
	# Use the same --fixed-fps and settle count for each comparison capture.
	for _frame in settle:
		await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var path := output.path_join(view + ".png")
	var err := picture.save_png(path)
	var adapter := RenderingServer.get_video_adapter_name()
	var software := RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_CPU \
			or adapter.to_lower().contains("llvmpipe") or adapter.to_lower().contains("lavapipe")
	var manifest := {
		"image": path, "view": view, "seed": 3, "settle_frames": settle,
		"section_only": section_only,
		"environment_only": environment_only,
		"volumetric_fog_disabled_for_review": no_fog,
		"screen_effects_disabled_for_review": no_screen_effects,
		"width": picture.get_width(), "height": picture.get_height(),
		"pipeline": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"video_adapter": adapter, "software_rasterised": software,
		"performance_evidence": false, "os": OS.get_name(),
		"processor": OS.get_processor_name(),
		"physical_memory_mib": int(OS.get_memory_info().get("physical", 0) / 1048576),
		"godot": Engine.get_version_info().string,
	}
	var file := FileAccess.open(output.path_join(view + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	print("REFERENCE_LOOK ", JSON.stringify(manifest))
	get_tree().quit(0 if err == OK else 1)
