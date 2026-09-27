extends Node
## The ring steps and the way in over them: stills from the hard camera,
## overhead and at the steps, then a wrestler stepped through the entrance
## route (ramp foot, up the diagonal flight, onto the apron, through the
## ropes) with a frame at each stage.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/steps_shot.tscn -- /tmp/steps
##
## Writes /tmp/steps_<name>.png.

var _out := "/tmp/steps"


func _ready() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_out = OS.get_cmdline_user_args()[0]
	var pair := Roster.pair_from_spec("")
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	director.set_physics_process(false)
	var cam := Camera3D.new()
	scene.add_child(cam)
	var mc: MatchCamera = scene.get_node("MatchCamera")
	var stills := {
		"hardcam": [mc.hard_cam_position, Vector3(0, 0.5, 0), mc.hard_cam_fov],
		"overhead": [Vector3(0.5, 16.0, 0.3), Vector3(0, 0, 0), 40.0],
		"steps_close": [Vector3(6.5, 2.2, -6.2), Vector3(3.6, -0.4, -3.6), 40.0],
		"steps_side": [Vector3(1.0, 1.6, -7.0), Vector3(3.8, -0.5, -3.8), 40.0],
	}
	for name: String in stills:
		var v: Array = stills[name]
		mc.current = false
		cam.current = true
		cam.fov = v[2]
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.UP)
		for _i in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])
	# The route: step the director on until each clip beat of the way in,
	# and grab it mid-beat from the steps camera.
	var want := ["strikes/climb_steps", "strikes/apron_step",
			"strikes/rope_step_through_apron"]
	var got := 0
	var guard := 0
	cam.global_position = Vector3(6.0, 1.4, -1.6)
	while got < want.size() and guard < 30000:
		guard += 1
		director._physics_process(1.0 / 60.0)
		if director._beat >= director._beats.size():
			break
		var b: Dictionary = director._beats[director._beat]
		if b.get("clip", "") == want[got] and director._tick == int(b["ticks"]) / 2:
			var w: WrestlerController = b["who"]
			cam.look_at(w.global_position + Vector3.UP * 1.0, Vector3.UP)
			for _i in 3:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					"%s_route_%d.png" % [_out, got])
			got += 1
	get_tree().quit()
