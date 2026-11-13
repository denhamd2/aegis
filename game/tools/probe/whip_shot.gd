extends Node
## Renders the Irish whip and a rope run through the real match scene, every
## few ticks, so the flow can be read off frames (the owner, 11 Nov: "the
## animation for the Irish whip and running the ropes looks very clunky").
##
##   godot --path game --rendering-driver opengl3 --resolution 960x540 \
##       tools/probe/whip_shot.tscn -- --out /tmp/whip [--scenario whip|rope_run] \
##       [--every 3] [--ticks 180]
##
## Writes <out>/<scenario>_<tick>.jpg and prints each man's state, speed and
## facing per tick to <out>/<scenario>.txt.

var _out := "/tmp/whip"
var _scenarios: Array[String] = ["whip", "rope_run"]
var _every := 3
var _ticks := 180


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--out": _out = args[i + 1]
			"--scenario": _scenarios = [args[i + 1]]
			"--every": _every = int(args[i + 1])
			"--ticks": _ticks = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)
	Engine.max_physics_steps_per_frame = 1
	await get_tree().process_frame
	for s in _scenarios:
		await _run(s)
	print("WHIP_SHOT done")
	get_tree().quit()


func _run(scenario: String) -> void:
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 7)
	# The ring and the two men only: the arena bowl takes minutes a frame in
	# software GL, and the flow is what is being read.
	for heavy in ["Arena", "RingReflections", "MatchHUD", "MatchCamera"]:
		if scene.has_node(heavy):
			scene.get_node(heavy).free()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.6
	scene.add_child(sun)
	get_tree().root.add_child(scene)
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
	# The whip is staged as the tutorial's (3:01.70): the runner with his back
	# to the near ropes, swung through and sent across the ring. The rope
	# run keeps the centre start.
	var off := 1.75 if scenario == "whip" else 0.0  # release -> rope ~38 f (loop 7: swing ends 0.22 m further out)
	roman.global_position = Vector3(-0.4 + off, 0, 0.0)
	cody.global_position = Vector3(0.4 + off, 0, 0.0)
	roman.look_at(Vector3(5, 0, 0), Vector3.UP)
	cody.look_at(Vector3(-5, 0, 0), Vector3.UP)
	await get_tree().physics_frame
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 62.0
	camera.global_position = Vector3(0.8, 1.9, 5.6)
	camera.look_at(Vector3(0.8, 1.0, 0.0), Vector3.UP)
	camera.current = true
	var log := FileAccess.open("%s/%s.txt" % [_out, scenario], FileAccess.WRITE)
	RenderingServer.render_loop_enabled = false
	var last_yaw := {roman: roman.rotation.y, cody: cody.rotation.y}
	for tick in range(1, _ticks + 1):
		if tick == 1:
			if scenario == "whip":
				roman._begin_irish_whip()
			else:
				cody.begin_rope_run()
		if scenario == "rope_run" and cody.is_whip_returning():
			cody._maybe_start_running_attack({"strike": true})
		camera.current = true
		await get_tree().physics_frame
		var line := "t%03d" % tick
		for w: WrestlerController in [roman, cody]:
			var v := Vector2(w.velocity.x, w.velocity.z).length()
			var dy := rad_to_deg(wrapf(w.rotation.y - float(last_yaw[w]), -PI, PI))
			last_yaw[w] = w.rotation.y
			line += "  %s %-14s v%5.2f yaw%7.1f d%6.1f x%6.2f z%6.2f %s" % [w.name.right(1),
					WrestlerFSM.State.keys()[w.fsm.current_state], v,
					rad_to_deg(w.rotation.y), dy, w.global_position.x, w.global_position.z,
					w.anim_tree.get("parameters/playback").get_current_node() if w.anim_tree else ""]
		log.store_line(line)
		if tick == 3:
			var vc := get_viewport().get_camera_3d()
			print("CAM ", vc.get_path() if vc else "none", " ", vc.global_position if vc else "")
		if tick % _every == 0:
			# Close on the runner, side-on, so his limbs read in a parity sheet
			# (the reviewer, 12 Nov: "figures about 80 px tall"). --wide keeps
			# the old fixed shot of the whole ring.
			if not OS.get_cmdline_user_args().has("--wide"):
				var mid := (cody.global_position * 0.7 + roman.global_position * 0.3)
				camera.fov = 50.0
				camera.global_position = Vector3(mid.x, 1.45, mid.z + 3.6)
				camera.look_at(Vector3(mid.x, 0.95, mid.z), Vector3.UP)
			RenderingServer.render_loop_enabled = true
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			get_viewport().get_texture().get_image().save_jpg(
					"%s/%s_%03d.jpg" % [_out, scenario, tick], 0.85)
	RenderingServer.render_loop_enabled = true
	log.close()
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
