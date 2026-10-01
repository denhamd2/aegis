extends Node
## Frames of a live AI match as the match camera shows it, for whole-frame
## look measurement against references (tools/refs/measure_look.py).
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan --resolution 640x360 \
##       --fixed-fps 30 tools/probe/match_look.tscn -- --out /tmp/look --every 30 --frames 900

var _out := "/tmp/look"
var _every := 30
var _frames := 900
var _seed := 3


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--out": _out = args[i + 1]
			"--every": _every = int(args[i + 1])
			"--frames": _frames = int(args[i + 1])
			"--seed": _seed = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)
	var pair := Roster.pair_from_spec("")
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], _seed)
	scene.entrances = false
	add_child(scene)
	for w in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
		(w as WrestlerController).is_ai = true
	for f in _frames:
		await RenderingServer.frame_post_draw
		if f % _every == 0 and f > 0:
			get_viewport().get_texture().get_image().save_jpg("%s/m_%05d.jpg" % [_out, f], 0.92)
	get_tree().quit()
