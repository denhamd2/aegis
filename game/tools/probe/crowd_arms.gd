extends Node
## The crowd's arm motion, on frames: a fixed camera on the near bowl and the
## ringside rows across from the hard camera, the crowd held at full
## excitement, and FRAMES stills a few ticks apart. Clappers' hands should
## part and meet, the arms-up roles pump and their signs go with them, and
## nothing should tear at an elbow.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/crowd_arms.tscn -- --out /tmp/arms
##
## Presentation only: reads the arena, writes PNGs.

const MATCH_SCENE := "res://scenes/match.tscn"
const FRAMES := 4
const GAP := 4

var _out := "/tmp/crowd_arms"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var pair := Roster.pair_from_spec("roman,cody")
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	scene.match_seed = 1
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	for frame in 90:
		await get_tree().physics_frame
	var camera := Camera3D.new()
	camera.fov = 28.0
	scene.add_child(camera)
	camera.look_at_from_position(Vector3(2.0, 3.2, -1.0), Vector3(11.0, 2.4, 1.0))
	camera.make_current()
	for n in FRAMES:
		for frame in GAP:
			RenderingServer.global_shader_parameter_set("crowd_excitement", 1.0)
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/arms_%d.png" % [_out, n])
		print("  wrote %s/arms_%d.png" % [_out, n])
	get_tree().quit()
