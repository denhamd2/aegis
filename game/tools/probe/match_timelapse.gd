extends Node
## NEEDS A GPU. On a software rasteriser (llvmpipe, as in the cloud sandbox this
## was written in) the sim runs ~400x slower under a real renderer than
## headless (600 ticks: 2.6 s headless, over 400 s under xvfb, even with the
## render loop off), so a ten-minute match does not finish there. Use the
## headless `pace_probe` for numbers and the sparse probes (`arena_shot`,
## `entrance_shots --sparse`, `handoff_shots`) for frames.
##
## A whole AI-vs-AI match as a timelapse: one frame every --every ticks (default
## 2 s of match) plus a frame on every knockdown, finisher and pin, from the
## camera the player would see. The run is the normal sim; only the frames that
## are saved are drawn (--sparse is built in), so a ten-minute match costs the
## sim plus a few hundred frames.
##
##   xvfb-run -a godot --path game --rendering-driver vulkan --fixed-fps 60 \
##       --resolution 960x540 tools/probe/match_timelapse.tscn -- \
##       --out /tmp/match --seed 2 [--every 120] [--coverage broadcast|gameplay]
##
## Then:  ffmpeg -framerate 8 -pattern_type glob -i '/tmp/match/t_*.png' -pix_fmt yuv420p match.mp4

const MATCH_SCENE := "res://scenes/match.tscn"

var _out := "/tmp/match"
var _seed := 2
var _every := 120
var _frame := 0
var _event_frames := []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--out": _out = args[i + 1]
			"--seed": _seed = int(args[i + 1])
			"--every": _every = int(args[i + 1])
			"--coverage":
				CameraSettings.coverage = CameraSettings.Coverage.BROADCAST \
						if args[i + 1] == "broadcast" else CameraSettings.Coverage.GAMEPLAY
	DirAccess.make_dir_recursive_absolute(_out)
	var pair := Roster.pair_from_spec("roman,cody")
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], _seed)
	scene.match_seed = _seed
	add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	for w: WrestlerController in [a, b]:
		w.is_ai = true
		if w.ai:
			w.ai.setup_jitter(_seed, w.player_index)
	var won := [false]
	referee.match_won.connect(func(_w, _m): won[0] = true)
	var mark := func(label: String) -> void:
		_event_frames.append([_frame, label])
	a.knocked_down.connect(func(_w): mark.call("knockdown"))
	b.knocked_down.connect(func(_w): mark.call("knockdown"))
	var tick := 0
	var after_win := 0
	while tick < 60000 and after_win < 360:
		var save := tick % _every == 0 or not _event_frames.is_empty()
		RenderingServer.render_loop_enabled = save
		if save:
			await RenderingServer.frame_post_draw
		else:
			await get_tree().physics_frame
		if save:
			var label := "t" if _event_frames.is_empty() else "e_" + String(_event_frames[0][1])
			get_viewport().get_texture().get_image().save_png("%s/%s_%05d.png" % [_out, label, tick])
			_event_frames.clear()
		tick += 1
		_frame = tick
		if won[0]:
			after_win += 1
	print("TIMELAPSE %d ticks (%.0f s)" % [tick, tick / 60.0])
	get_tree().quit()
