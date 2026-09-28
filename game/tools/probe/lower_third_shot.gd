extends Node
## Renders the entrance lower third through its build in and out, at fixed
## moments, over a dark frame -- the graphic's animation checked on pixels.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1280x720 --fixed-fps 60 tools/probe/lower_third_shot.tscn \
##       -- --out /tmp/l3
##
## Frames are named by milliseconds since show_card() (in_) or hide_card()
## (out_).

const SHOW_MS := [0, 67, 133, 200, 267, 333, 400, 467, 533, 600, 800, 1000, 1100, 1500]
const HIDE_MS := [0, 67, 133, 200, 267, 333, 400]

var _out := "/tmp/l3"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var card := EntranceLowerThird.new()
	add_child(card)
	await get_tree().process_frame
	card.show_card("Cody Rhodes", "The American Nightmare")
	await _grab(card, SHOW_MS, "in")
	card.hide_card()
	await _grab(card, HIDE_MS, "out")
	print("LOWER_THIRD_SHOT done")
	get_tree().quit()


func _grab(card: EntranceLowerThird, at_ms: Array, tag: String) -> void:
	var start := Time.get_ticks_msec()
	var frame := 0
	for ms: int in at_ms:
		# Fixed-fps: one frame is 1/60 s of the card's own clock.
		while frame * 1000 / 60 < ms:
			await get_tree().process_frame
			frame += 1
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				"%s/%s_%04d.png" % [_out, tag, ms])
	var _unused := start
