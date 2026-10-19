extends Node
## A man catches fire, Aubrey fetches the extinguisher and puts him out, and
## the burn marks stay (ManFire, FireCrew), frame by frame. For review.
##
##   xvfb-run -a godot --path game --rendering-driver vulkan --resolution 1280x720 \
##       --fixed-fps 30 tools/probe/fire_shot.tscn -- --out /tmp/fire [--every 1.0]

var _out := "/tmp/fire"
var _every := 1.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--out": _out = args[i + 1]
			"--every": _every = float(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	scene.entrances = false
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
	a.global_position = Vector3(-0.3, 0.0, 0.2)
	a.rotation.y = PI * 0.5
	b.global_position = Vector3(-2.2, 0.0, -1.8)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	cam.fov = 44.0
	cam.global_position = Vector3(3.9, 2.2, 3.4)
	cam.look_at(Vector3(0.0, 1.0, 0.0))
	for _i in 10:
		await RenderingServer.frame_post_draw
	var venue := VenueDamage.of(a)
	venue.start_fire(a.global_position + Vector3(0.45, 1.0, 0.1), 0.9, false)
	var man := a.find_child("ManFire", false, false) as ManFire
	var crew := scene.get_node("FireCrew") as FireCrew
	var t := 0.0
	var n := 0
	var next := 0.0
	while t < 26.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= next:
			next += _every
			await _save("fire_%02d_%s.png" % [n, "burning" if man.burning else ("out" if man.burn > 0.0 else "clear")])
			n += 1
	print("FIRE SHOT DONE burn %.2f crew_busy %s" % [man.burn, crew.busy()])
	get_tree().quit()


func _save(file: String) -> void:
	for _i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))
