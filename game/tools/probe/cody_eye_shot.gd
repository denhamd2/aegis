extends Node
## Cody's eyes (tools/assets/rig_cody_eyes.py + EyeAim): close-ups staring
## ahead and on Roman, and each eye's line of sight against the line to
## Roman's eyes, read inside EyeAim's own modification_processed -- the only
## moment the modified bone pose is readable.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/cody_eye_shot.tscn -- --out /tmp/ce

var _out := "/tmp/ce"
var _gaze := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
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
	# Roman off Cody's line of sight, so Cody's eyes have somewhere to go.
	b.global_position = Vector3(0.45, 0, 0)
	a.global_position = Vector3(-0.55, 0, 0.40)
	b.rotation.y = atan2(1.0, 0.0)     # facing -X
	a.rotation.y = atan2(-1.0, -0.40)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var cam := scene.get_node("MatchCamera") as MatchCamera
	cam.set_physics_process(false)
	var aim := b.find_child("EyeAim", true, false) as EyeAim
	print("CODY_EYES eye aim: %s" % (aim != null))
	if aim == null:
		get_tree().quit(1)
		return
	var on := aim.look_target
	aim.modification_processed.connect(_on_processed.bind(aim, on))
	var sk := aim.get_skeleton()
	for mode: String in ["ahead", "on_roman"]:
		aim.look_target = on if mode == "on_roman" else func() -> Vector3: return Vector3.INF
		for _i in 30:
			await RenderingServer.frame_post_draw
		var eye := sk.global_transform * sk.get_bone_global_rest(sk.find_bone("Eye_L")).origin
		var head := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
		var mid := eye.lerp(head, 0.0)
		cam.set_entrance_shot(mid + Vector3(-0.6, 0.03, 0.06), mid + Vector3(0, 0, 0.03), 9.0, true)
		cam._clear_focus()
		for _i in 20:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/cody_eyes_%s.png" % [_out, mode])
		for side in ["L", "R"]:
			print("CODY_EYES gaze %s %s: %.1f deg off Roman" % [mode, side, _gaze.get(side, -1.0)])
	get_tree().quit()


func _on_processed(aim: EyeAim, target: Callable) -> void:
	var sk := aim.get_skeleton()
	var goal: Vector3 = target.call()
	for side in ["L", "R"]:
		var bone := sk.find_bone("Eye_" + side)
		var pose := sk.global_transform * sk.get_bone_global_pose(bone)
		var fwd: Vector3 = aim.sight_local.get("Eye_" + side,
				sk.get_bone_global_rest(bone).basis.inverse() * EyeAim.REST_FORWARD)
		var sight := (pose.basis * fwd).normalized()
		_gaze[side] = rad_to_deg(sight.angle_to((goal - pose.origin).normalized()))
