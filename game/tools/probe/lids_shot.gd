extends Node
## Roman's eyelids (EyeLids): his eyes held open, half and shut, front and
## three-quarter.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/lids_shot.tscn -- --out /tmp/lids

var _out := "/tmp/lids"


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
	a.global_position = Vector3(-0.45, 0, 0)
	b.global_position = Vector3(0.45, 0, 0)
	a.rotation.y = atan2(-1.0, 0.0)
	b.rotation.y = atan2(1.0, 0.0)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var cam := scene.get_node("MatchCamera") as MatchCamera
	cam.set_physics_process(false)
	var lids := a.find_child("EyeLids", true, false) as EyeLids
	print("LIDS found: %s" % (lids != null))
	if lids == null:
		get_tree().quit(1)
		return
	for pivot in lids.get_children():
		var cap := pivot.get_node("Cap") as MeshInstance3D
		print("LIDS %s radius %.4f at %s" % [pivot.name, (cap.mesh as SphereMesh).radius, pivot.position])
		print("LIDS   world %s" % (pivot as Node3D).global_position)
	for side in ["L", "R"]:
		var iris := a.find_child("RomanIris_Eye_" + side, true, false) as Node3D
		print("LIDS iris %s world %s" % [side, (iris.get_child(0) as Node3D).global_position])
	for closure: float in [0.0, 0.5, 1.0]:
		lids.hold(closure)
		for view: String in ["front", "34"]:
			for _i in 12:
				await RenderingServer.frame_post_draw
			var iris := a.find_child("RomanIris_Eye_L", true, false) as Node3D
			var eye := (iris.get_child(0) as Node3D).global_position
			var mid := eye + Vector3(0.0, 0.0, -0.032)
			var from := mid + (Vector3(0.6, 0.02, 0.0) if view == "front" else Vector3(0.45, 0.05, 0.40))
			cam.set_entrance_shot(from, mid, 8.0, true)
			cam._clear_focus()
			for _i in 12:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					"%s/lids_%s_%d.png" % [_out, view, int(closure * 100)])
	print("LIDS done")
	get_tree().quit()
