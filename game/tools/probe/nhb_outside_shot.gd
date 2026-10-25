extends Node
## No Holds Barred, outside the ring: Roman rolls out through the ropes and
## the AI follows him to the floor (WrestlerAI._follow_through_ropes). Frames
## from the match camera, so the framing at floor level is what is checked.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 960x540 --fixed-fps 60 tools/probe/nhb_outside_shot.tscn \
##       -- --out /tmp/nhb --every 30 --ticks 600 [--side]
##
## --side: a fixed camera level with the apron, side-on to the rope he goes
## out through, instead of the match camera -- for the climb out itself
## (WrestlerController.RING_EXIT_PATH).

var _out := "/tmp/nhb"
var _every := 30
var _ticks := 600
var _side := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--every" and i + 1 < args.size():
			_every = int(args[i + 1])
		elif args[i] == "--ticks" and i + 1 < args.size():
			_ticks = int(args[i + 1])
	_side = args.has("--side")
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 7)
	MatchRules.set_mode(scene, MatchRules.Mode.NO_HOLDS_BARRED)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var roman: WrestlerController = scene.get_node("WrestlerA")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	referee._tying_up = false
	for w: WrestlerController in [roman, cody]:
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
		w.velocity = Vector3.ZERO
	roman.is_ai = false
	roman.global_position = Vector3(0.4, 0, -2.5)
	cody.global_position = Vector3(0.2, 0, -0.6)
	if _side:
		var cam := Camera3D.new()
		scene.add_child(cam)
		cam.fov = 45.0
		# Three-quarters from outside, clear of the ring post at (3.1, -3.1).
		cam.look_at_from_position(Vector3(4.0, 0.9, -4.6), Vector3(0.4, -0.1, -3.3))
		cam.make_current()
	await get_tree().physics_frame
	print("NHB cross started: %s" % roman.begin_rope_cross())
	var last := ""
	for tick in range(1, _ticks + 1):
		await get_tree().physics_frame
		var state := "%s/%s %s | %s/%s %s" % [
				WrestlerFSM.State.keys()[roman.fsm.current_state], roman.outside_ring,
				roman.global_position.snappedf(0.1),
				WrestlerFSM.State.keys()[cody.fsm.current_state], cody.outside_ring,
				cody.global_position.snappedf(0.1)]
		if tick % 30 == 0 or state.get_slice(" ", 0) != last.get_slice(" ", 0):
			print("tick %d  %s" % [tick, state])
		last = state
		if tick % _every == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg("%s/n_%04d.jpg" % [_out, tick], 0.85)
	get_tree().quit()
