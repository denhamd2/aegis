extends Node
## Before/after frames for refs/aaa_gap.md items 10-12: Roman's eyes on Cody
## vs staring ahead, a face-off close-up with and without depth of field, the
## crowd idle vs on its feet with phones out, and replay grain.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/broadcast_shot.tscn -- --out /tmp/bc

var _out := "/tmp/bc"


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
	# Cody off Roman's line of sight, so his eyes have somewhere to go.
	a.global_position = Vector3(-0.45, 0, 0)
	b.global_position = Vector3(0.55, 0, 0.45)
	a.rotation.y = atan2(1.0, 0.0)
	b.rotation.y = atan2(-1.0, -0.45)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var crowd := scene.get_node("CrowdReaction") as CrowdReaction
	crowd.set_process(false)
	var look := scene.get_node("BroadcastLook") as BroadcastLook
	var cam := scene.get_node("MatchCamera") as MatchCamera
	cam.set_physics_process(false)
	var eye_aim := a.find_child("EyeAim", true, false) as EyeAim
	print("BROADCAST_SHOT eye aim: %s" % (eye_aim != null))
	var aim_on: Callable = eye_aim.look_target if eye_aim else Callable()

	# 12: eyes. A tight lens on his face, from in front of him.
	for mode: String in ["ahead", "on_cody"]:
		if eye_aim:
			eye_aim.look_target = aim_on if mode == "on_cody" \
					else func() -> Vector3: return Vector3.INF
		cam.set_entrance_shot(Vector3(0.15, 1.72, -0.05), Vector3(-0.45, 1.70, -0.02), 12.0, true)
		cam._clear_focus()
		await _save("eyes_%s" % mode)
	if eye_aim:
		eye_aim.look_target = aim_on

	# 10: the face-off close-up (34 degrees), without and with depth of field.
	for mode: String in ["flat", "dof"]:
		cam.set_entrance_shot(Vector3(0.9, 1.75, 2.6), Vector3(-0.2, 1.65, 0.0), 34.0, true)
		if mode == "flat":
			cam._clear_focus()
		await _save("faceoff_%s" % mode)

	# 11: the crowd, idle and then on its feet with phones out -- a wide shot
	# into the stands behind the far ropes.
	cam.set_entrance_shot(Vector3(0.0, 3.2, 7.0), Vector3(0.0, 3.0, -14.0), 50.0, true)
	for mode: String in ["idle", "roar"]:
		crowd.excitement = 1.0 if mode == "roar" else 0.0
		crowd.flash_rate = CrowdReaction.ENTRANCE_FLASH_RATE * 4.0 if mode == "roar" else 0.0
		crowd._publish()
		await _save("crowd_%s" % mode)

	# 10: grain, as a replay has it, on the match's own wide shot.
	crowd.excitement = 0.0
	crowd.flash_rate = 0.0
	crowd._publish()
	cam.set_entrance_shot(Vector3(-6.5, 3.2, 1.8), Vector3(0.0, 1.0, 0.0), 41.0, true)
	cam._clear_focus()
	for mode: String in ["live", "replay"]:
		look.set_grain(mode == "replay")
		await _save("grain_%s" % mode)
	print("BROADCAST_SHOT done")
	get_tree().quit()


func _save(name: String) -> void:
	for _i in 30:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
