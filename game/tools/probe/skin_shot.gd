extends Node
## Skin close-ups, dry and soaked: the pore layer and the sweat film
## (SkinLook, Sweat; gauntlet/refs/aaa_gap.md items 5-6).
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/skin_shot.tscn -- --out /tmp/skin
##
## --wet A,B,... shoots named wetness points instead of the dry/soaked pair.
## The sweat round that re-scaled Sweat.FULL_SECONDS needed the skin at the
## wetness a man actually HAS two minutes into a match, before and after --
## the film at a given wetness did not change, when he reaches it did.

var _out := "/tmp/skin"
var _wets: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			continue
		match args[i]:
			"--out": _out = args[i + 1]
			"--wet":
				_wets = Array(args[i + 1].split(",")).map(func(s): return float(s))
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [a, b]:
		w.set_physics_process(false)
		if w.ai:
			w.ai.set_physics_process(false)
		w.play_presentation_clip("strikes/face_off", true)
	a.global_position = Vector3(-0.45, 0, 0)
	b.global_position = Vector3(0.45, 0, 0)
	a.rotation.y = atan2(-1.0, 0.0)
	b.rotation.y = atan2(1.0, 0.0)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	for wet: float in (_wets if not _wets.is_empty() else [Sweat.BASE, 1.0]):
		for w: WrestlerController in [a, b]:
			var sweat := w.get_node_or_null("Sweat") as Sweat
			if sweat:
				sweat.set_process(false)
				for m in sweat.materials:
					SkinLook.set_wetness(m, wet)
		for shot: Array in [["roman_face", Vector3(-0.2, 1.72, 0.75), Vector3(-0.38, 1.70, 0.0), 30.0],
				["cody_face", Vector3(0.2, 1.70, 0.75), Vector3(0.38, 1.68, 0.0), 30.0],
				["torsos", Vector3(0.0, 1.45, 2.1), Vector3(0.0, 1.35, 0.0), 42.0]]:
			cam.fov = shot[3]
			cam.look_at_from_position(shot[1], shot[2])
			for _i in 30:
				await RenderingServer.frame_post_draw
			var tag := ("w%03d" % int(round(wet * 100.0))) if not _wets.is_empty() \
					else ("wet" if wet > 0.5 else "dry")
			get_viewport().get_texture().get_image().save_png(
					"%s/%s_%s.png" % [_out, shot[0], tag])
	print("SKIN_SHOT done, sweat nodes: %s %s" % [a.get_node_or_null("Sweat") != null,
			b.get_node_or_null("Sweat") != null])
	get_tree().quit()
