extends Node
## Renders the ring entrances as a strip of frames, without the title screen.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 --fixed-fps 30 tools/probe/entrance_shots.tscn \
##       -- --out /tmp/entrance --every 30
##
## Builds match.tscn with Roman and Cody the way the title screen does, turns
## `entrances` on, and saves a frame every `--every` rendered frames until a
## second after the bell. Prints each beat as it starts, so a frame can be
## matched to what the director thought it was doing.

const MATCH_SCENE := "res://scenes/match.tscn"

var _out := "/tmp/entrance"
var _every := 30
var _frame := 0
## --until N: stop after N frames (re-rendering the start of a long run).
var _until := -1
## --faceoff: skip both entrances and start on the face-off, men on marks.
var _faceoff := false
## --sparse: draw only the frames that are saved. A software renderer takes
## ~20x real time per drawn frame; a storyboard of the whole entrance every
## few seconds then costs minutes, not an hour. The run itself is unchanged.
var _sparse := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--every" and i + 1 < args.size():
			_every = int(args[i + 1])
		elif args[i] == "--until" and i + 1 < args.size():
			_until = int(args[i + 1])
		elif args[i] == "--faceoff":
			_faceoff = true
		elif args[i] == "--sparse":
			_sparse = true
	DirAccess.make_dir_recursive_absolute(_out)
	var pair := Roster.pair_from_spec("")
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var rang := [false]
	director.bell.connect(func(): rang[0] = true)
	if _faceoff:
		for i in director._beats.size():
			if (director._beats[i] as Dictionary)["kind"] == "pair":
				for w: WrestlerController in [director._a, director._b]:
					w.global_transform = director._mark[w]
					w.visible = true
				director._beat = i
				director._start_beat()
				break
	var last_beat := -1
	var after := 0
	while after < 30:
		if _sparse:
			RenderingServer.render_loop_enabled = _frame % _every == 0
		if RenderingServer.render_loop_enabled:
			await RenderingServer.frame_post_draw
		else:
			await get_tree().process_frame
		if director._beat != last_beat and director._beat < director._beats.size():
			last_beat = director._beat
			var b: Dictionary = director._beats[last_beat]
			print("frame %d beat %d %s %s" % [_frame, last_beat, b["kind"],
					b.get("shot", "")])
		if _frame % _every == 0:
			get_viewport().get_texture().get_image().save_jpg(
					"%s/e_%05d.jpg" % [_out, _frame], 0.85)
		_frame += 1
		if _until > 0 and _frame >= _until:
			break
		if rang[0]:
			after += 1
	print("ENTRANCE_SHOTS %d frames, bell=%s" % [_frame, rang[0]])
	get_tree().quit()
