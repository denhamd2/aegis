extends Node
## Walks the landing screen the way a player does -- FIGHT, pick, pick -- and
## proves the match it launches is really the two men that were picked.
##
## This is the half of the screen a unit test cannot cover: the suite checks
## configure_match()'s wiring against stub entries precisely so CI never loads
## a 52MB character, which leaves "does the real launch produce a real match"
## to a probe. It prints the model scene attached to each wrestler and saves a
## frame of the match it landed in.
##
## Usage:
##   xvfb-run -a godot4 --path game --resolution 1280x720 \
##       tools/probe/title_launch.tscn -- --out /tmp/launched.png

const TITLE_SCENE := "res://scenes/title.tscn"

var _out := "/tmp/title_launch.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]

	# The screen replaces the CURRENT scene when it launches, so it has to be
	# the current scene for the launch to be the real one. This probe node is
	# a separate child of root and therefore survives the swap -- which is
	# what lets it photograph the match afterwards.
	#
	# Deferred, and awaited before current_scene is set: root is still setting
	# up ITS children while this probe's _ready() runs, so a direct add_child()
	# is refused ("Parent node is busy setting up children"). The screen then
	# never enters the tree, its _ready() never builds the menu, and the three
	# _accept() calls below index an empty array.
	var title: CanvasLayer = load(TITLE_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(title)
	await get_tree().process_frame
	get_tree().current_scene = title
	await get_tree().process_frame

	var screen: TitleScreen = title.get_node("Draw")
	screen._accept()  # FIGHT
	screen._accept()  # player 1 takes the wrestler under the cursor
	screen._accept()  # opponent
	print("PICKED ", (screen.picks[0] as Roster.Entry).display_name(), " vs ",
			(screen.picks[1] as Roster.Entry).display_name())

	# VERSUS hold, then the fade, then the load.
	var waited := 0.0
	while is_instance_valid(title) and waited < 20.0:
		waited += get_process_delta_time()
		await get_tree().process_frame

	var match_scene := get_tree().current_scene
	if match_scene == null or match_scene == title:
		print("TITLE_LAUNCH FAILED: no match scene after ", waited, "s")
		get_tree().quit(1)
		return
	for slot: String in ["WrestlerA", "WrestlerB"]:
		var wrestler: WrestlerController = match_scene.get_node(slot)
		print("%s: %s  model=%s  ai=%s" % [slot, wrestler.display_name,
				wrestler.character_model_scene.resource_path, wrestler.is_ai])

	for _i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_out)
	print("TITLE_LAUNCH saved ", _out)
	get_tree().quit()
