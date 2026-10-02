extends Node
## Close-ups of a ring corner: the posts, the turnbuckle hardware between each
## post and its pad, and the pads (core/ring/ring_builder.gd "Corners").
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1280x720 tools/probe/corner_shot.tscn -- --out /tmp/corner

var _out := "/tmp/corner"

const SHOTS := [
	# name, eye, look, fov
	["inside_34", Vector3(1.4, 1.3, 1.9), Vector3(3.05, 0.85, 3.05), 38.0],
	["side_on", Vector3(3.9, 1.1, 1.2), Vector3(3.05, 0.85, 3.05), 34.0],
	["from_outside", Vector3(4.6, 1.5, 4.6), Vector3(2.9, 0.85, 2.9), 40.0],
	["macro", Vector3(2.55, 0.95, 3.55), Vector3(3.1, 0.85, 3.1), 30.0],
	["steps_ref", Vector3(5.4, 0.45, -1.4), Vector3(3.6, -0.55, -3.6), 46.0],
	["steps_high", Vector3(5.6, 2.4, -5.6), Vector3(3.5, -0.6, -3.5), 44.0],
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	for w in ["WrestlerA", "WrestlerB"]:
		var n := scene.get_node_or_null(w) as Node3D
		if n:
			n.global_position = Vector3(0, -50, 0)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	for shot: Array in SHOTS:
		cam.fov = shot[3]
		cam.look_at_from_position(shot[1], shot[2])
		for _i in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, shot[0]])
	print("CORNER_SHOT done")
	get_tree().quit()
