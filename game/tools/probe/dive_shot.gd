extends Node
## Renders Cody's dive spot (core/match/dive_spot.gd) through the real
## trigger -- MatchReferee._start_dive -- with the man already down near the
## ropes, without waiting for a match to get there.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 960x540 --fixed-fps 60 tools/probe/dive_shot.tscn \
##       -- --out /tmp/dive --every 10
##
## Frames are named by tick; each segment's start is printed.

var _out := "/tmp/dive"
var _every := 10


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--every" and i + 1 < args.size():
			_every = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 7)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var roman: WrestlerController = scene.get_node("WrestlerA")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	referee._tying_up = false
	for w: WrestlerController in [roman, cody]:
		w.is_ai = false
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
		w.velocity = Vector3.ZERO
	roman.global_position = Vector3(1.8, 0, 0.4)
	cody.global_position = Vector3(0.6, 0, 0.2)
	await get_tree().physics_frame
	roman.fsm.transition_to(WrestlerFSM.State.STUNNED)
	roman.fsm.transition_to(WrestlerFSM.State.DOWN)
	roman._move_ticks_remaining = 100000
	await get_tree().physics_frame
	cody._submission_move_used = true
	referee._start_dive(cody, roman)
	var spot: DiveSpot = scene.get_node("DiveSpot")
	var done := [false]
	spot.finished.connect(func(): done[0] = true)
	var tick := 0
	var last := -1
	while not done[0] and tick < 4000:
		await get_tree().physics_frame
		tick += 1
		if is_instance_valid(spot) and spot._seg != last:
			last = spot._seg
			print("tick %d segment %d  roman %s  cody %s" % [tick, last,
					roman.global_position.snappedf(0.01), cody.global_position.snappedf(0.01)])
		if tick % _every == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg("%s/d_%04d.jpg" % [_out, tick], 0.85)
	for f in 30:
		await get_tree().physics_frame
	print("DIVE_SHOT done at %d: roman %s %s cody %s %s" % [tick,
			WrestlerFSM.State.keys()[roman.fsm.current_state], roman.global_position.snappedf(0.01),
			WrestlerFSM.State.keys()[cody.fsm.current_state], cody.global_position.snappedf(0.01)])
	get_tree().quit()
