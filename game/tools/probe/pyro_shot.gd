extends Node
## The entrance pyro on Vulkan frames: Roman's flame bursts and Cody's shells
## over the set and over the ring, each fired on an empty set and grabbed as
## it peaks.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 960x540 tools/probe/pyro_shot.tscn -- --out /tmp/pyro

var _out := "/tmp/pyro"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	scene.entrances = false
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	for n in ["WrestlerA", "WrestlerB"]:
		var w: WrestlerController = scene.get_node(n)
		w.set_physics_process(false)
		if w.ai:
			w.ai.set_physics_process(false)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var rig := get_tree().get_first_node_in_group("arena_lighting") as ArenaLighting
	rig.set_look(ArenaLighting.Look.ENTRANCE)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	cam.fov = 58.0
	for shot: Array in [["roman", 0.45, Vector3(0, 3.2, -12.0), Vector3(0, 5.0, -36.0)],
			["cody_hit", 0.9, Vector3(0, 3.2, -12.0), Vector3(0, 7.0, -36.0)],
			["over_ring", 0.8, Vector3(-7.5, 2.0, 7.5), Vector3(0, 3.5, 0)]]:
		var pyro := EntrancePyro.new()
		scene.add_child(pyro)
		cam.look_at_from_position(shot[2], shot[3])
		pyro.fire(shot[0])
		var t0 := Time.get_ticks_msec()
		# Simulated time, not wall time: the emitters run at fixed fps.
		var frames := int(float(shot[1]) * 60.0)
		for i in frames:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, shot[0]])
		print("PYRO %s after %d frames (%d ms)" % [shot[0], frames, Time.get_ticks_msec() - t0])
		pyro.queue_free()
		for i in 30:
			await get_tree().physics_frame
	get_tree().quit()
