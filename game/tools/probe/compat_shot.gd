extends Node3D
## One wide broadcast frame on whichever renderer it is launched with.
##
## Exists because the compatibility renderer's look is now a thing this repo
## deliberately changes (ArenaLighting._apply_compat_depth_fog), and the
## forward_plus capture harness cannot see that path at all -- it is guarded
## off. VISUAL_BAR.md rules a gl_compatibility frame void for judging the
## measured bar, and that still holds: this probe is for looking at the browser
## build's appearance, never for producing a gauntlet number.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1280x720 tools/probe/compat_shot.tscn -- --out /tmp/x.png

const MATCH_SCENE := "res://scenes/play.tscn"

var _out := "/tmp/compat_shot.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	add_child(load(MATCH_SCENE).instantiate())
	await get_tree().process_frame

	# The broadcast park from match.tscn's MatchCamera comment, held still so
	# two runs of this probe frame the same hall.
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 41.0
	cam.global_position = Vector3(-8.5, 3.2, 2.4)
	cam.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)

	for _i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_out)
	print("COMPAT_SHOT saved ", _out, " method=",
		RenderingServer.get_current_rendering_method())
	get_tree().quit()
