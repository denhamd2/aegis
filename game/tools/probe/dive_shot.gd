extends Node
## Renders Cody's dive spot (core/match/dive_spot.gd) through the real
## trigger -- MatchReferee._start_dive -- with the man already down near the
## ropes, without waiting for a match to get there.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 960x540 --fixed-fps 60 tools/probe/dive_shot.tscn \
##       -- --out /tmp/dive --every 10
##
## Frames are named by tick; each segment's start is printed. --seed N sets
## the match seed, which picks the springboard's ending
## (DiveSpot.ending_of: 0 the Disaster Kick, 1 the Cutter, 2 the moonsault,
## mod 3); --from T draws nothing before tick T; --side shoots through a lit
## probe camera inside the ring instead of the match's.

var _out := "/tmp/dive"
var _every := 10
## The match seed, which picks the springboard's ending (DiveSpot.ending_of).
var _seed := 7
## Render nothing before this tick.
var _from := 0
## A probe camera instead of the match's: inside the ring, square to the
## rope side the spot plays on, with a fill light from it. The broadcast wide
## sits outside on the far diagonal, and in a probe the arena lights are
## not up, so its frames of the springboard came out near black.
var _side := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--every" and i + 1 < args.size():
			_every = int(args[i + 1])
		elif args[i] == "--seed" and i + 1 < args.size():
			_seed = int(args[i + 1])
		elif args[i] == "--from" and i + 1 < args.size():
			_from = int(args[i + 1])
		elif args[i] == "--side":
			_side = true
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), _seed)
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
	var camera: Camera3D = null
	if _side:
		# 3.4 m along the rope side from the lane, toward the ring's middle,
		# looking back at the apron and the man in front of it.
		var across := -3.4 if spot._lane > 0.0 else 3.4
		camera = Camera3D.new()
		scene.add_child(camera)
		camera.fov = 50.0
		camera.global_position = spot.at(2.3, spot._lane + across, 1.5)
		camera.look_at(spot.at(2.2, spot._lane, 1.1), Vector3.UP)
		var fill := DirectionalLight3D.new()
		scene.add_child(fill)
		fill.light_energy = 2.0
		fill.global_transform = camera.global_transform
	var done := [false]
	spot.finished.connect(func(): done[0] = true)
	var tick := 0
	var last := -1
	# One physics tick per frame and nothing drawn but the grabs, so a frame
	# shows the tick it is named by (paired_shot.gd has the same, and why).
	Engine.max_physics_steps_per_frame = 1
	RenderingServer.render_loop_enabled = false
	while not done[0] and tick < 4000:
		await get_tree().physics_frame
		tick += 1
		if is_instance_valid(spot) and spot._seg != last:
			last = spot._seg
			print("tick %d segment %d  roman %s  cody %s" % [tick, last,
					roman.global_position.snappedf(0.01), cody.global_position.snappedf(0.01)])
		if tick >= _from and tick % _every == 0:
			# MatchCamera takes `current` back when it cuts; hold the probe's.
			if camera:
				camera.current = true
			RenderingServer.render_loop_enabled = true
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			get_viewport().get_texture().get_image().save_jpg("%s/d_%04d.jpg" % [_out, tick], 0.85)
	for f in 30:
		await get_tree().physics_frame
	print("DIVE_SHOT done at %d: roman %s %s cody %s %s" % [tick,
			WrestlerFSM.State.keys()[roman.fsm.current_state], roman.global_position.snappedf(0.01),
			WrestlerFSM.State.keys()[cody.fsm.current_state], cody.global_position.snappedf(0.01)])
	get_tree().quit()
