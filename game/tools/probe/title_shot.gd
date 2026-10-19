extends Node
## The title presented after the match (TitlePresentation), for review: a
## frame every `--every` seconds from the table to the winner holding it up,
## from a fixed ringside camera on the timekeeper's side.
##
##   xvfb-run -a godot --path game --rendering-driver vulkan --resolution 1280x720 \
##       --fixed-fps 30 tools/probe/title_shot.tscn -- --out /tmp/title [--every 1.5]

var _out := "/tmp/title"
var _every := 1.5


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--out": _out = args[i + 1]
			"--every": _every = float(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 0)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [a, b]:
		w.set_physics_process(false)
		if w.ai:
			w.ai.set_physics_process(false)
	a.global_position = Vector3(0.4, 0.0, 0.6)
	a.rotation.y = PI * 0.5
	b.global_position = Vector3(-1.2, 0.0, -1.0)
	b.lay_out_after_match()
	a.celebrate()
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	cam.fov = 46.0
	cam.global_position = Vector3(5.6, 1.6, -1.2)
	cam.look_at(Vector3(2.0, 0.6, 2.4))
	for _i in 10:
		await RenderingServer.frame_post_draw
	await _save("title_00_on_table.png")
	var title := TitlePresentation.of(scene)
	title.present(a, scene.get_node("RefereeActor"))
	var t := 0.0
	var n := 1
	var next := _every
	while not title.is_done() and t < 45.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		# follow the belt: wide on the table side, then on the winner
		var target := title.belt.global_position
		cam.look_at(target.lerp(a.global_position + Vector3.UP * 1.2, 0.35))
		if t >= next:
			next += _every
			await _save("title_%02d_%s.png" % [n, title.holder()])
			n += 1
	for _i in 30:
		await get_tree().process_frame
	cam.global_position = a.global_position + Vector3(0.0, 1.5, 3.4)
	cam.look_at(a.global_position + Vector3.UP * 1.6)
	await _save("title_99_raised.png")
	print("TITLE SHOT DONE %.1f s" % t)
	get_tree().quit()


func _save(file: String) -> void:
	for _i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))
