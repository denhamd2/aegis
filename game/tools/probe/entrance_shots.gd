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


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--every" and i + 1 < args.size():
			_every = int(args[i + 1])
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
	var last_beat := -1
	var after := 0
	while after < 30:
		await RenderingServer.frame_post_draw
		if director._beat != last_beat and director._beat < director._beats.size():
			last_beat = director._beat
			var b: Dictionary = director._beats[last_beat]
			print("frame %d beat %d %s %s" % [_frame, last_beat, b["kind"],
					b.get("shot", "")])
		if _frame % _every == 0:
			get_viewport().get_texture().get_image().save_jpg(
					"%s/e_%05d.jpg" % [_out, _frame], 0.85)
		_frame += 1
		if rang[0]:
			after += 1
	print("ENTRANCE_SHOTS %d frames, bell=%s" % [_frame, rang[0]])
	get_tree().quit()
