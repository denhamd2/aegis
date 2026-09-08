extends Node
## Renders the landing screen at each of its phases so the art can be looked
## at without launching the game.
##
## Usage:
##   xvfb-run -a godot4 --path game --resolution 1600x900 \
##       tools/probe/title_shots.tscn -- --out /tmp/title.png

const TITLE_SCENE := "res://scenes/title.tscn"

var _out := "/tmp/title.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	var title: CanvasLayer = load(TITLE_SCENE).instantiate()
	add_child(title)
	var screen: TitleScreen = title.get_node("Draw")

	await _shot(screen, "title")

	screen.menu_index = 1
	screen.phase = TitleScreen.Phase.CONTROLS
	await _shot(screen, "controls")

	screen.phase = TitleScreen.Phase.SELECT
	screen.menu_index = 0
	screen.cursor = 0
	await _shot(screen, "select_p1")

	screen.picks = [Roster.entries()[0]]
	screen.cursor = 1
	await _shot(screen, "select_p2")

	screen.picks = [Roster.entries()[0], Roster.entries()[1]]
	screen.phase = TitleScreen.Phase.VERSUS
	screen._versus_time = 0.6
	await _shot(screen, "versus")

	print("TITLE_SHOTS saved next to ", _out)
	get_tree().quit()


func _shot(screen: TitleScreen, tag: String) -> void:
	# The screen animates, so hold a beat: the beams, the mote drift and the
	# logo's highlight sweep all read differently on frame 1 than in motion.
	screen._time = 3.4
	for _i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(
			"%s_%s.%s" % [_out.get_basename(), tag, _out.get_extension()])
