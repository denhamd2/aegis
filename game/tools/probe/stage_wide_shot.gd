extends Node3D
## A wide frame of the entrance set from behind the ring, for judging the stage
## against the owner's AEW still. Held still so two runs frame the same set.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1600x900 tools/probe/stage_wide_shot.tscn -- --out /tmp/stage.png

const MATCH_SCENE := "res://scenes/play.tscn"
var _out := "/tmp/stage_wide.png"
var _pos := Vector3(0.0, 3.6, 5.5)
var _look := Vector3(0.0, 4.6, -38.0)
var _fov := 62.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--pos" and i + 1 < args.size():
			_pos = _vec(args[i + 1])
		elif args[i] == "--look" and i + 1 < args.size():
			_look = _vec(args[i + 1])
		elif args[i] == "--fov" and i + 1 < args.size():
			_fov = float(args[i + 1])
	add_child(load(MATCH_SCENE).instantiate())
	await get_tree().process_frame
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = _fov
	cam.global_position = _pos
	cam.look_at(_look, Vector3.UP)
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out)
	get_tree().quit()


func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
