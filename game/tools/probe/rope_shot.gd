extends Node
## Close-up of the live ropes (core/ring/ring_ropes.gd) through Cody's dive
## spot: the rebound off the far ropes, the tope through them and the
## springboard off the middle rope -- the three ways a body meets them.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 960x540 --fixed-fps 60 tools/probe/rope_shot.tscn \
##       -- --out /tmp/ropes --every 2
##
## Prints the largest rope deflection each segment reaches.

var _out := "/tmp/ropes"
var _every := 2


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
	var ropes := scene.find_child("LiveRopes", true, false) as RingRopes
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
	spot._camera = null
	var cam := Camera3D.new()
	cam.fov = 45.0
	scene.add_child(cam)
	cam.make_current()
	var done := [false]
	spot.finished.connect(func(): done[0] = true)
	var tick := 0
	var seg := -1
	var peak := 0.0
	while not done[0] and tick < 4000:
		await get_tree().physics_frame
		tick += 1
		if not is_instance_valid(spot):
			break
		if spot._seg != seg:
			if seg >= 0:
				print("segment %d peak rope deflection %.3f m" % [seg, peak])
			seg = spot._seg
			peak = 0.0
		peak = maxf(peak, ropes.max_deflection())
		var shot := _shot(seg, cody, roman)
		if shot.is_empty():
			continue
		cam.look_at_from_position(shot[0], shot[1])
		if tick % _every == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_jpg("%s/r_%02d_%04d.jpg" % [_out, seg, tick], 0.85)
	print("ROPE_SHOT done at %d" % tick)
	get_tree().quit()


## Close cameras on the three rope beats; nothing rendered for the rest.
func _shot(seg: int, cody: WrestlerController, roman: WrestlerController) -> Array:
	match seg:
		4:
			# The far ropes from above and along them, so their give out of
			# the ring reads as a bend in a straight line.
			return [Vector3(-1.3, 2.6, 2.4), Vector3(-3.1, 0.7, 0.4)]
		6:
			# The tope, from inside the ring, looking out over the ropes he
			# goes through to the floor.
			return [Vector3(0.9, 1.9, 2.4), Vector3(3.4, 0.5, 0.4)]
		10:
			# Rolling in under the bottom rope, from outside.
			return [Vector3(5.2, 0.9, 1.8), Vector3(3.1, 0.2, -0.1)]
		12, 13:
			# The springboard, from inside, square to the rope he stands on.
			return [Vector3(1.0, 1.5, -1.3), Vector3(3.0, 0.9, 0.9)]
	return []
