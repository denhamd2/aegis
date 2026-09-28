extends Node
## The ring keys' shadows on the mat, hard (light_size 0) and soft
## (ArenaLighting.KEY_LIGHT_SIZE): refs/aaa_gap.md item 8.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/shadow_shot.tscn -- --out /tmp/shadow

var _out := "/tmp/shadow"


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
	a.global_position = Vector3(-0.6, 0, 0.3)
	b.global_position = Vector3(0.6, 0, -0.3)
	a.rotation.y = atan2(-1.0, 0.0)
	b.rotation.y = atan2(1.0, 0.0)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var keys := scene.find_children("Key*", "SpotLight3D", true, false)
	var tops := scene.find_children("Top*", "SpotLight3D", true, false)
	print("SHADOW_SHOT keys: %d tops: %d" % [keys.size(), tops.size()])
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	# "hard" is the rig before item 8: hard key shadows, shadowless top fill.
	for size: float in [0.0, ArenaLighting.KEY_LIGHT_SIZE]:
		for key: SpotLight3D in keys:
			key.light_size = size
		for top: SpotLight3D in tops:
			top.shadow_enabled = size > 0.0
			top.light_size = size
		for shot: Array in [["feet", Vector3(0.0, 1.3, 2.6), Vector3(0.0, 0.1, 0.0), 40.0],
				["wide", Vector3(0.0, 3.4, 5.5), Vector3(0.0, 0.6, 0.0), 45.0]]:
			cam.fov = shot[3]
			cam.look_at_from_position(shot[1], shot[2])
			for _i in 30:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					"%s/%s_%s.png" % [_out, shot[0], "soft" if size > 0.0 else "hard"])
	print("SHADOW_SHOT done")
	get_tree().quit()
