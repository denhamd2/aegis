extends Node
## Renders Cody's crossbody off the top (TopRopeSpot, crossbody) onto Roman
## just up off the mat below the corner, through the spot itself.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 960x540 --fixed-fps 60 tools/probe/crossbody_shot.tscn \
##       -- --out /tmp/crossbody --every 8 --from 0
##
## Frames are named by tick from --from on; each segment's start is printed.

var _out := "/tmp/crossbody"
var _every := 8
var _from := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--every" and i + 1 < args.size():
			_every = int(args[i + 1])
		elif args[i] == "--from" and i + 1 < args.size():
			_from = int(args[i + 1])
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
	roman.global_position = Vector3(1.0, 0, 1.0)
	cody.global_position = Vector3(0.2, 0, 0.4)
	await get_tree().physics_frame
	roman.fsm.transition_to(WrestlerFSM.State.STUNNED)
	roman.fsm.transition_to(WrestlerFSM.State.DOWN)
	roman.fsm.transition_to(WrestlerFSM.State.GETUP)
	var spot := TopRopeSpot.new()
	spot.name = "TopRopeSpot"
	scene.add_child(spot)
	spot.begin(cody, roman, true)
	var done := [false]
	spot.finished.connect(func(): done[0] = true)
	var tick := 0
	var last := -1
	var after := 0
	while after < 60 and tick < 2000:
		# Only the frames kept are drawn: the rest run at physics speed
		# rather than at the arena's render cost.
		var saving := tick + 1 >= _from and (tick + 1) % _every == 0
		get_viewport().disable_3d = not saving
		await get_tree().physics_frame
		tick += 1
		if done[0]:
			after += 1
		if is_instance_valid(spot) and spot._seg != last:
			last = spot._seg
			print("tick %d segment %d  roman %s %s  cody %s" % [tick, last,
					WrestlerFSM.State.keys()[roman.fsm.current_state],
					roman.global_position.snappedf(0.01), cody.global_position.snappedf(0.01)])
		if tick >= _from and tick % _every == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg("%s/c_%04d.jpg" % [_out, tick], 0.85)
	print("CROSSBODY_SHOT done at %d: roman %s %s cody %s %s pinning %s" % [tick,
			WrestlerFSM.State.keys()[roman.fsm.current_state], roman.global_position.snappedf(0.01),
			WrestlerFSM.State.keys()[cody.fsm.current_state], cody.global_position.snappedf(0.01),
			referee._pinning])
	get_tree().quit()
