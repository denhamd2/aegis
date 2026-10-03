extends Node
## The in-match replay (InstantReplay) on a rendered match: replays set to
## FREQUENT, a signature move announced on the grapple rig the way a real one
## is, and a frame grabbed mid-replay and after it. Prints whether the match
## paused and came back.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 960x540 tools/probe/instant_replay_shot.tscn -- --out /tmp/ir

var _out := "/tmp/ir"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	process_mode = Node.PROCESS_MODE_ALWAYS
	CameraSettings.replays = CameraSettings.Replays.FREQUENT
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	scene.entrances = false
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	# Headless, the buffer records nothing (ReplayBuffer._ready); switched on
	# here so the logic -- pause, play, hand back -- can be checked without a
	# renderer. No frames are saved headless.
	var buffer: ReplayBuffer = scene.get_node("ReplayBuffer")
	buffer.set_process(true)
	# Two seconds of match in the buffer before the move, so the run-up is
	# there to replay.
	while buffer.now() < 2.0:
		await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var rig: GrappleRig = scene.get_node("GrappleRig")
	# Nobody throws a real move over the announced one.
	for w: WrestlerController in [a, b]:
		w.is_ai = false
		if w.ai:
			w.ai.set_physics_process(false)
	# The real thing: his signature, played through the rig, which announces
	# its start and its end the way every move does.
	b.global_position = a.global_position + (-a.global_transform.basis.z) * 0.9
	rig.begin(a, b, a.signature_move)
	var ir: InstantReplay = scene.get_node("InstantReplay")
	var shot := false
	var deadline := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().paused and not shot and ir._t > 0.6:
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(_out + "/during.png")
			shot = true
			print("IR paused mid-replay, replays=%d, %.2f-%.2f" % [ir.replays, ir._from, ir._to])
		if shot and not get_tree().paused:
			break
	for i in 30:
		await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out + "/after.png")
	print("IR after: paused=%s replays=%d" % [get_tree().paused, ir.replays])
	get_tree().quit()
