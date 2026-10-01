extends Node
## Roman and Cody side by side in the face-off stance, orthographic and
## side-on, with a line every 5 cm from 1.60 to 1.95 m -- the stature check
## by eye (Roster stature_m).
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 900x900 tools/probe/stature_shot.tscn -- --out /tmp/st.png

func _ready() -> void:
	var out := "/tmp/stature.png"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
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
	for k in 8:
		var y := 1.60 + 0.05 * k
		var bar := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(2.4, 0.002 if k % 2 else 0.004, 0.01)
		bar.mesh = m
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1, 0.3, 0.3) if k % 2 == 0 else Color(0.3, 1, 0.3)
		bar.material_override = mat
		bar.position = Vector3(0, y, 1.0)
		scene.add_child(bar)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.7
	scene.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.72, 4.0), Vector3(0, 1.72, 0))
	cam.make_current()
	for _i in 30:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("STATURE_SHOT a %.3f b %.3f" % [a.physique_height, b.physique_height])
	get_tree().quit()
