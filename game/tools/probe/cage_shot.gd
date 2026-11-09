extends Node
## Renders the Steel Cage (gauntlet/refs/steel_cage.md) through the real match
## scene in STEEL_CAGE mode: the cage round the ring, a man climbing out of it
## with the other down, the other man climbing after him and pulling him off,
## and a man calling for the door and going out through it.
##
##   xvfb-run -a godot --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/cage_shot.tscn -- --out /tmp/cage
##
## Forward+ through lavapipe takes minutes a frame, so it grabs a handful of
## named beats, not every tick. --beats a,b,... picks some; --wide adds a
## probe camera at the broadcast's distance on the hard-camera side, lit, for
## frames the match camera's framing would not show.

var _out := "/tmp/cage"
var _wide := false
var _only: Array[String] = []

## Beat name -> [scenario, tick].
const BEATS := [
	["establish", "climb", 1],
	["climb_low", "climb", 90],
	["climb_high", "climb", 250],
	["over_top", "climb", 360],
	["chase", "chase", 170],
	["pulled_off", "chase", 214],
	["door_call", "door", 240],
	["door_exit", "door", 330],
	["escaped", "climb", 590],
	["ram", "ram", 26],
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--wide":
			_wide = true
		elif args[i] == "--beats" and i + 1 < args.size():
			for b: String in args[i + 1].split(","):
				_only.append(b)
	DirAccess.make_dir_recursive_absolute(_out)
	Engine.max_physics_steps_per_frame = 1
	for scenario: String in ["climb", "chase", "door", "ram"]:
		var wanted: Array = []
		for beat: Array in BEATS:
			if beat[1] == scenario and (_only.is_empty() or _only.has(beat[0])):
				wanted.append(beat)
		if wanted.is_empty():
			continue
		await _run(scenario, wanted)
	print("CAGE_SHOT done")
	get_tree().quit()


func _run(scenario: String, beats: Array) -> void:
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 7,
			false, MatchRules.Mode.STEEL_CAGE)
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var roman: WrestlerController = scene.get_node("WrestlerA")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var escape: CageEscape = scene.get_node("CageEscape")
	referee._tying_up = false
	for w: WrestlerController in [roman, cody]:
		w.is_ai = false
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
		w.velocity = Vector3.ZERO
	match scenario:
		"climb", "chase":
			cody.global_position = Vector3(2.45, 0, 0.6)
			cody.rotation.y = atan2(-1.0, 0.0)
			roman.global_position = Vector3(0.2, 0, -0.4) if scenario == "climb" \
					else Vector3(1.6, 0, 1.5)
		"door":
			roman.global_position = Vector3(-2.45, 0, 0.1)
			roman.rotation.y = atan2(1.0, 0.0)
			cody.global_position = Vector3(0.8, 0, -0.6)
		"ram":
			roman.global_position = Vector3(0.0, 0, 0.2)
			cody.global_position = Vector3(1.0, 0, 0.2)
	await get_tree().physics_frame
	if scenario == "climb" or scenario == "door":
		var down := roman if scenario == "climb" else cody
		down.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
		down.fsm.transition_to(WrestlerFSM.State.DOWN)
		down.knockdown_tier = CombatSystem.Tier.FINISHER
		down._move_ticks_remaining = 100000
		down.set_physics_process(false)
	var camera := _probe_camera(scene) if _wide else null
	var by_tick := {}
	for beat: Array in beats:
		by_tick[int(beat[2])] = beat[0]
	var last_tick := 0
	for t: int in by_tick:
		last_tick = maxi(last_tick, t)
	RenderingServer.render_loop_enabled = false
	for tick in range(1, last_tick + 1):
		match scenario:
			"climb", "chase":
				if tick == 1:
					escape.begin(cody)
				if scenario == "chase" and tick == 60:
					roman.global_position = escape.chase_spot(cody, roman.global_position)
					escape.begin(roman)
			"door":
				if tick == 1:
					roman.is_ai = true
					escape.begin(roman)
			"ram":
				if tick == 1:
					cody._irish_whip_target = roman
					cody._irish_whip_rebounded = false
					cody._irish_whip_cage = true
					cody.velocity = Vector3(WrestlerController.IRISH_WHIP_LAUNCH_SPEED, 0, 0)
					cody._irish_whip_launch_velocity = cody.velocity
					cody.fsm.transition_to(WrestlerFSM.State.IRISH_WHIP)
		await get_tree().physics_frame
		if by_tick.has(tick):
			if camera:
				camera.current = true
			RenderingServer.render_loop_enabled = true
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			var path := "%s/%s.jpg" % [_out, by_tick[tick]]
			get_viewport().get_texture().get_image().save_jpg(path, 0.88)
			print("beat %s tick %d  roman %s %s  cody %s %s" % [by_tick[tick], tick,
					WrestlerFSM.State.keys()[roman.fsm.current_state],
					roman.global_position.snappedf(0.01),
					WrestlerFSM.State.keys()[cody.fsm.current_state],
					cody.global_position.snappedf(0.01)])
	RenderingServer.render_loop_enabled = true
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


## The hard-camera side (-X), at a broadcast wide's distance and height, the
## ring filling the frame, with a fill from the camera (the probe has no
## arena lights up through an entrance).
func _probe_camera(scene: Node) -> Camera3D:
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 48.0
	camera.global_position = Vector3(-9.5, 4.6, 3.2)
	camera.look_at(Vector3(0.4, 1.6, 0.2), Vector3.UP)
	return camera
