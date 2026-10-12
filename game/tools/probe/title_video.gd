extends Node
## Records the whole opening -- landing screen, wrestler select, VS card, and
## the match it launches -- as a numbered frame sequence for encoding to video.
##
## Usage:
##   xvfb-run -a godot4 --path game --resolution 1280x720 --fixed-fps 30 \
##       tools/probe/title_video.tscn -- --out /tmp/frames --match-seconds 40
##   (add --resume to carry on from the frames already in --out)
##   ffmpeg -framerate 30 -i /tmp/frames/f_%05d.jpg -c:v libx264 out.mp4
##
## --fixed-fps 30 against the project's 60Hz physics means two physics ticks
## per rendered frame and a fixed delta, so the recording is deterministic and
## one saved frame is exactly 1/30s of match time: encode at 30 and it plays
## back at real speed.
##
## Frames are JPEG, not PNG. A minute of 1280x720 PNG is over a gigabyte in a
## container with a fixed disk allowance; the same run in JPEG is ~150MB and
## the difference is invisible after H.264.
##
## The screen is driven by calling _accept() rather than by feeding synthetic
## input events, which is what tools/probe/title_launch.gd does and what the
## suite exercises. Phase timing (the VS hold, the fade) is left to
## TitleScreen._process -- this probe only renders and saves.
##
## The whole show (master plan stage 8) is this probe with --watch and a long
## --match-seconds: tools/capture/show_reel.sh runs it, resumes it, mixes the
## sound and cuts the QA stills from --out/timeline.txt.

const TITLE_SCENE := "res://scenes/title.tscn"

## Beats of the opening, in seconds. Long enough to read on screen: the menu
## and the cards are the two places a viewer needs a moment to see what he is
## being shown.
const HOLD_TITLE := 2.2
## The longest the recording follows the post-match before it stops anyway.
const POST_MATCH_CAP := 60.0
const HOLD_BEFORE_PICK := 1.9
const HOLD_BETWEEN_PICKS := 1.9

var _out_dir := "/tmp/frames"
var _match_seconds := 40.0
var _frame := 0
var _fps := 30.0
## Set from the referee's match_won. A member rather than a local captured by
## the connected lambda: GDScript lambdas capture locals BY VALUE, so assigning
## to a captured `var over` inside one leaves the outer copy false forever and
## the recording runs its whole budget past the finish.
var _match_over := false
## --resume: frames already on disk from an interrupted run. The recording is
## deterministic (fixed fps, presses on fixed frame counts), so the game is
## re-run to that frame without drawing or saving, then carries on. A two-hour
## software-rendered recording otherwise dies with the container.
var _resume := false
## --audio-only: the same run, drawn by nobody and saved nowhere, for a
## Movie Maker pass that only wants the sound (--write-movie x.avi at a tiny
## --resolution). The run is frame-for-frame the recorded one, so the .wav
## lines up with the JPEGs; see the note on _first_process_frame.
var _audio_only := false
## Engine process frame the first saved JPEG is, printed so an audio pass
## (whose Movie Maker frame 0 is the engine's first frame) can be trimmed to it.
var _first_process_frame := -1
var _resume_at := 0
## Two things made a run unrepeatable, so --resume could never line up:
## TitleScreen._launch() seeds the match with randi_range() off an engine RNG
## Godot randomizes at start-up, and the launch waits on threaded preloads,
## which finish after however much wall time the renderer happened to take.
## Seeding the global RNG and loading the scenes into the cache up front makes
## both a fixed number of frames. Held here so the cache keeps them.
var _seed := 2
## The sound log (--out/sound_log.txt): every audio player in the tree as it
## starts, changes level and stops, by frame. tools/capture/mix_sound_log.py
## rebuilds the soundtrack from it and the source files. A Movie Maker sound
## pass is exact too, but on the Vulkan software renderer it read back every
## 1080p frame and ran at a minute of sound an hour; the log costs nothing,
## comes out of the same run as the pictures, and is rewritten from frame 0
## on a --resume, which re-simulates every frame anyway.
var _sound_log: FileAccess
var _sound_players: Array = []
var _sound_state := {}
var _held: Array[Resource] = []
## --watch: WATCH on the landing menu rather than FIGHT, the way a viewer
## opens an AI-vs-AI match (both select cards read CPU).
var _watch := false
## --menu-hold: seconds the post-match menu stays on screen before the
## recording stops. Without it the recording ends on the rating card.
var _menu_hold := 0.0
## --out/timeline.txt: "frame section detail", one line as each part of the
## show starts (title, select, versus, match_scene, entrance <shot>, bell,
## finish, menu, end). Rewritten from frame 0 on a --resume, like
## the sound log. show_reel.sh cuts the QA stills from it.
var _timeline: FileAccess
## --frames <file>: draw and save only the frames listed (one index per line),
## each after SETTLE_FRAMES drawn but unsaved frames. Every other frame is
## simulated, not drawn. On the software renderer a drawn arena frame costs
## ~3 s whatever the resolution (shadows, skinning, the fog volume), while a
## simulated one costs ~0.01 s -- so a 13-minute show is ~20 hours in full and
## a couple of hours as QA stills and motion clips. Frames already on disk are
## skipped, which is how an interrupted sparse run resumes.
var _sparse := false
var _save_set := {}
var _render_set := {}
## CaptureHarness.ART_SETTLE_FRAMES, for the same reason: TAA and SSIL take
## frames to converge after the renderer has been idle.
const SETTLE_FRAMES := 24
## --perf: every 30 frames, the wall-clock cost per frame and where it went.
var _perf := false
var _perf_at := 0
## --positions: --out/positions.txt, one line a frame once the match scene is
## up -- "frame ax az bx bz rx rz cx cy cz mode": both men's and the referee's
## floor positions and the camera's -- so a still that looks like a body
## through a body, or something in front of the lens, can be checked against
## where things actually were rather than judged off one angle.
var _positions: FileAccess
var _want_positions := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out_dir = args[i + 1]
		elif args[i] == "--match-seconds" and i + 1 < args.size():
			_match_seconds = float(args[i + 1])
		elif args[i] == "--resume":
			_resume = true
		elif args[i] == "--audio-only":
			_audio_only = true
		elif args[i] == "--seed" and i + 1 < args.size():
			_seed = int(args[i + 1])
		elif args[i] == "--frames" and i + 1 < args.size():
			_load_frames(args[i + 1])
		elif args[i] == "--positions":
			_want_positions = true
		elif args[i] == "--perf":
			_perf = true
		elif args[i] == "--watch":
			_watch = true
		elif args[i] == "--menu-hold" and i + 1 < args.size():
			_menu_hold = float(args[i + 1])
	seed(_seed)
	for path: String in ["res://scenes/match.tscn", "res://scenes/roman_model.tscn",
			"res://scenes/cody_model.tscn"]:
		_held.append(load(path))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_sound_log = FileAccess.open(_out_dir + "/sound_log.txt", FileAccess.WRITE)
	_timeline = FileAccess.open(_out_dir + "/timeline.txt", FileAccess.WRITE)
	if _want_positions:
		_positions = FileAccess.open(_out_dir + "/positions.txt", FileAccess.WRITE)
	if _sparse:
		_plan_sparse()
	if _resume:
		for file in DirAccess.get_files_at(_out_dir):
			if file.begins_with("f_") and file.ends_with(".jpg"):
				_resume_at += 1
		if _resume_at > 0:
			print("TITLE_VIDEO resuming at frame ", _resume_at)
			_draw_3d(false)

	# Deferred, and awaited before current_scene is set: root is still setting
	# up ITS children while this _ready() runs and refuses a direct add_child()
	# (see title_launch.gd, which had exactly this bug). This node is a
	# separate child of root, so it survives the screen swapping itself out
	# for the match and can keep recording through it.
	var title: CanvasLayer = load(TITLE_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(title)
	await get_tree().process_frame
	get_tree().current_scene = title
	await get_tree().process_frame
	var screen: TitleScreen = title.get_node("Draw")

	_mark("title")
	await _record(HOLD_TITLE)          # the landing screen, menu on FIGHT
	if _watch:
		screen.menu_index = 1          # down to WATCH, as a key press would
		await _record(HOLD_BEFORE_PICK * 0.5)
	screen._accept()                   # FIGHT / WATCH -> the select
	_mark("select")
	await _record(HOLD_BEFORE_PICK)    # cursor on Roman
	screen._accept()                   # player 1 takes Roman
	await _record(HOLD_BETWEEN_PICKS)  # cursor parks on Cody
	screen._accept()                   # opponent is Cody -> the VS card
	_mark("versus")
	print("PICKED ", (screen.picks[0] as Roster.Entry).display_name(), " vs ",
			(screen.picks[1] as Roster.Entry).display_name())

	# The VS hold and the fade run on TitleScreen's own clock; record until the
	# screen frees itself, which is the moment the match is the current scene.
	var waited := 0.0
	while is_instance_valid(title) and waited < 10.0:
		await _record_frame()
		waited += 1.0 / _fps
	var match_scene := get_tree().current_scene
	if match_scene == null or match_scene == title:
		print("TITLE_VIDEO FAILED: no match scene after ", waited, "s")
		get_tree().quit(1)
		return

	# Both sides on the AI. configure_match() puts the player on WrestlerA, and
	# a player slot nobody is driving stands still -- an AI-vs-passive match is
	# "an infinite strike loop that never reaches a finish" (match_setup.gd).
	for slot: String in ["WrestlerA", "WrestlerB"]:
		var w: WrestlerController = match_scene.get_node(slot)
		w.is_ai = true
		print("%s: %s  model=%s" % [slot, w.display_name,
				w.character_model_scene.resource_path])
	var referee: MatchReferee = match_scene.get_node("MatchReferee")
	referee.match_won.connect(_on_match_won)
	_mark("match_scene")
	var director := match_scene.get_node_or_null("EntranceDirector") as EntranceDirector
	if director:
		director.beat_started.connect(func(shot: String) -> void: _mark("entrance", shot))
		director.bell.connect(func() -> void: _mark("bell"))
	else:
		_mark("bell", "no entrances")

	# Record to the finish, then through the post-match (PostMatch: the
	# winner, the replay, the celebration, the rating), capped, so the video
	# ends on the rating rather than the moment the three-count lands -- or,
	# with --menu-hold, on the menu that follows it.
	var elapsed := 0.0
	var after_finish := 0.0
	var on_menu := -1.0
	while elapsed < _match_seconds:
		await _record_frame()
		elapsed += 1.0 / _fps
		if _match_over:
			after_finish += 1.0 / _fps
			var post := match_scene.get_node_or_null("PostMatch") as PostMatch
			var post_done := post == null or post.is_done()
			if _menu_hold > 0.0:
				if on_menu < 0.0 and match_scene.get_node_or_null("PostMatchMenu"):
					on_menu = 0.0
					_mark("menu")
				elif on_menu >= 0.0:
					on_menu += 1.0 / _fps
				if on_menu >= _menu_hold or after_finish >= POST_MATCH_CAP:
					break
			elif (post_done and after_finish >= 2.5) or after_finish >= POST_MATCH_CAP:
				break
	_mark("end", "finished=%s" % _match_over)
	print("TITLE_VIDEO %d frames, finished=%s" % [_frame, _match_over])
	get_tree().quit()


## Reads --frames. Frames already on disk are dropped in _plan_sparse(), once
## every argument (--out among them) has been read.
func _load_frames(path: String) -> void:
	_sparse = true
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n", false):
		if line.strip_edges().is_valid_int():
			_save_set[int(line)] = true


func _plan_sparse() -> void:
	for f: int in _save_set.keys():
		if FileAccess.file_exists("%s/f_%05d.jpg" % [_out_dir, f]):
			_save_set.erase(f)
	for f: int in _save_set.keys():
		for k in range(maxi(0, f - SETTLE_FRAMES), f + 1):
			_render_set[k] = true
	print("TITLE_VIDEO sparse: %d frames to save, %d to draw" % [
			_save_set.size(), _render_set.size()])


## Frames nobody will see are simulated with the 3D world switched off, not
## with RenderingServer.render_loop_enabled off. With the render loop off the
## RenderingDevice never reaches the end of a frame, so the per-frame buffer
## and texture uploads (the crowd, the skeletons) pile up and every one stalls
## on a full flush: measured on a bare Roman v Cody match, 2.7 s an undrawn
## frame, the same as a drawn one. With only the 3D off the frame still ends
## and flushes, and costs 0.03 s. Presentation only -- nothing in the match
## reads whether a frame was drawn, which the sparse pass's timeline check
## (show_reel.sh) confirms.
func _draw_3d(on: bool) -> void:
	get_viewport().disable_3d = not on


func _log_positions() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.get_node_or_null("RefereeActor") == null:
		return
	var parts := [str(_frame)]
	for path: String in ["WrestlerA", "WrestlerB", "RefereeActor"]:
		var n := scene.get_node(path) as Node3D
		parts.append("%.3f %.3f" % [n.global_position.x, n.global_position.z])
	var cam := get_viewport().get_camera_3d()
	if cam:
		parts.append("%.3f %.3f %.3f" % [cam.global_position.x, cam.global_position.y,
				cam.global_position.z])
		if cam is MatchCamera:
			parts.append(MatchCamera.Mode.keys()[(cam as MatchCamera).mode])
	_positions.store_line(" ".join(parts))


## One timeline line: the frame the section starts on (the next JPEG saved).
func _mark(section: String, detail := "") -> void:
	if _timeline == null:
		return
	_timeline.store_line("%d %s %s" % [_frame, section, detail.replace(" ", "_")])
	_timeline.flush()


## One line per change: S(tart) frame id path loop pitch volume_db,
## V(olume) frame id volume_db, E(nd) frame id. Frame is the index of the JPEG
## this frame is saved as (_frame, before it is incremented).
func _log_sound() -> void:
	if _sound_log == null:
		return
	if _frame % 15 == 0 or _sound_players.is_empty():
		_sound_players = get_tree().root.find_children("*", "AudioStreamPlayer", true, false) \
				+ get_tree().root.find_children("*", "VideoStreamPlayer", true, false)
	var seen := {}
	for p in _sound_players:
		if not is_instance_valid(p):
			continue
		var id: int = p.get_instance_id()
		seen[id] = true
		var playing: bool = p.is_playing()
		var vol: float = p.volume_db
		var was: Dictionary = _sound_state.get(id, {})
		var plays := int(p.get_meta("plays", 0))
		if playing and vol > -60.0:
			if was.is_empty() or plays != int(was["plays"]):
				var stream: Resource = p.stream
				var path := String(stream.get_meta("src", stream.resource_path)) if stream else ""
				var looped := p is AudioStreamPlayer and stream is AudioStreamOggVorbis \
						and (stream as AudioStreamOggVorbis).loop
				var pitch: float = p.pitch_scale if p is AudioStreamPlayer else 1.0
				_sound_log.store_line("S %d %d %s %d %.4f %.2f" % [_frame, id, path,
						int(looped), pitch, vol])
				_sound_state[id] = {"plays": plays, "vol": vol}
			elif absf(vol - float(was["vol"])) > 0.05:
				_sound_log.store_line("V %d %d %.2f" % [_frame, id, vol])
				was["vol"] = vol
		elif not was.is_empty():
			_sound_log.store_line("E %d %d" % [_frame, id])
			_sound_state.erase(id)
	for id: int in _sound_state.keys():
		if not seen.has(id):
			_sound_log.store_line("E %d %d" % [_frame, id])
			_sound_state.erase(id)
	_sound_log.flush()


func _on_match_won(winner: WrestlerController, method: String) -> void:
	print("FINISH: %s by %s at frame %d" % [winner.display_name, method, _frame])
	# The PostMatch sequence (bell, winner, replay, celebration, rating) starts
	# on this same tick, so the finish mark is also where it begins.
	_mark("finish", "%s by %s" % [winner.display_name, method])
	_match_over = true


func _record(seconds: float) -> void:
	for _i in int(round(seconds * _fps)):
		await _record_frame()


func _record_frame() -> void:
	if _positions:
		_log_positions()
	if _perf and _frame % 30 == 0:
		var now := Time.get_ticks_msec()
		print("PERF frame %d  wall %.2f s/frame  process %.0f ms  physics %.0f ms  draws %d  objects %d" % [
				_frame, (now - _perf_at) / 30000.0,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		_perf_at = now
	_log_sound()
	if _first_process_frame < 0:
		_first_process_frame = Engine.get_process_frames()
		print("TITLE_VIDEO first frame is engine process frame ", _first_process_frame)
	if _audio_only:
		_draw_3d(false)
		await get_tree().process_frame
		_frame += 1
		return
	if _sparse:
		var draw := _render_set.has(_frame)
		_draw_3d(draw)
		if not draw:
			await get_tree().process_frame
			_frame += 1
			return
		await RenderingServer.frame_post_draw
		if _save_set.has(_frame):
			get_viewport().get_texture().get_image().save_jpg(
					"%s/f_%05d.jpg" % [_out_dir, _frame], 0.88)
		_frame += 1
		return
	if _frame < _resume_at:
		await get_tree().process_frame
		_frame += 1
		if _frame == _resume_at:
			_draw_3d(true)
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_jpg("%s/f_%05d.jpg" % [_out_dir, _frame], 0.88)
	_frame += 1
