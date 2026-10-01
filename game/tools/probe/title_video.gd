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

const TITLE_SCENE := "res://scenes/title.tscn"

## Beats of the opening, in seconds. Long enough to read on screen: the menu
## and the cards are the two places a viewer needs a moment to see what he is
## being shown.
const HOLD_TITLE := 2.2
## The longest the recording follows the post-match before it stops anyway.
const POST_MATCH_CAP := 40.0
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
	seed(_seed)
	for path: String in ["res://scenes/match.tscn", "res://scenes/roman_model.tscn",
			"res://scenes/cody_model.tscn"]:
		_held.append(load(path))
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_sound_log = FileAccess.open(_out_dir + "/sound_log.txt", FileAccess.WRITE)
	if _resume:
		for file in DirAccess.get_files_at(_out_dir):
			if file.begins_with("f_") and file.ends_with(".jpg"):
				_resume_at += 1
		if _resume_at > 0:
			print("TITLE_VIDEO resuming at frame ", _resume_at)
			RenderingServer.render_loop_enabled = false

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

	await _record(HOLD_TITLE)          # the landing screen, menu on FIGHT
	screen._accept()                   # FIGHT -> the select
	await _record(HOLD_BEFORE_PICK)    # cursor on Roman
	screen._accept()                   # player 1 takes Roman
	await _record(HOLD_BETWEEN_PICKS)  # cursor parks on Cody
	screen._accept()                   # opponent is Cody -> the VS card
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

	# Record to the finish, then through the post-match (PostMatch: the
	# winner, the replay, the celebration, the rating), capped, so the video
	# ends on the rating rather than the moment the three-count lands.
	var elapsed := 0.0
	var after_finish := 0.0
	while elapsed < _match_seconds:
		await _record_frame()
		elapsed += 1.0 / _fps
		if _match_over:
			after_finish += 1.0 / _fps
			var post := match_scene.get_node_or_null("PostMatch") as PostMatch
			var post_done := post == null or post.is_done()
			if (post_done and after_finish >= 2.5) or after_finish >= POST_MATCH_CAP:
				break
	print("TITLE_VIDEO %d frames, finished=%s" % [_frame, _match_over])
	get_tree().quit()


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
	_match_over = true


func _record(seconds: float) -> void:
	for _i in int(round(seconds * _fps)):
		await _record_frame()


func _record_frame() -> void:
	_log_sound()
	if _first_process_frame < 0:
		_first_process_frame = Engine.get_process_frames()
		print("TITLE_VIDEO first frame is engine process frame ", _first_process_frame)
	if _audio_only:
		RenderingServer.render_loop_enabled = false
		await get_tree().process_frame
		_frame += 1
		return
	if _frame < _resume_at:
		await get_tree().process_frame
		_frame += 1
		if _frame == _resume_at:
			RenderingServer.render_loop_enabled = true
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_jpg("%s/f_%05d.jpg" % [_out_dir, _frame], 0.88)
	_frame += 1
