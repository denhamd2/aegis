extends Node
## Records the whole opening -- landing screen, wrestler select, VS card, and
## the match it launches -- as a numbered frame sequence for encoding to video.
##
## Usage:
##   xvfb-run -a godot4 --path game --resolution 1280x720 --fixed-fps 30 \
##       tools/probe/title_video.tscn -- --out /tmp/frames --match-seconds 40
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


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out_dir = args[i + 1]
		elif args[i] == "--match-seconds" and i + 1 < args.size():
			_match_seconds = float(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out_dir)

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

	# Record to the finish, then a couple of seconds on the fall so the video
	# does not cut the moment the three-count lands.
	var elapsed := 0.0
	var after_finish := 0.0
	while elapsed < _match_seconds:
		await _record_frame()
		elapsed += 1.0 / _fps
		if _match_over:
			after_finish += 1.0 / _fps
			if after_finish >= 2.5:
				break
	print("TITLE_VIDEO %d frames, finished=%s" % [_frame, _match_over])
	get_tree().quit()


func _on_match_won(winner: WrestlerController, method: String) -> void:
	print("FINISH: %s by %s at frame %d" % [winner.display_name, method, _frame])
	_match_over = true


func _record(seconds: float) -> void:
	for _i in int(round(seconds * _fps)):
		await _record_frame()


func _record_frame() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_jpg("%s/f_%05d.jpg" % [_out_dir, _frame], 0.88)
	_frame += 1
