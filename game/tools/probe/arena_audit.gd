extends Node3D
## Wide arena frames for comparing the built hall against gauntlet/refs/arena/
## and the AEW Dynamite wide supplied by the project owner.
##
## Renders on forward_plus (the shipped pipeline), because every existing
## capture in tools/capture/out/ is a close match shot and none of them can
## show the bowl, the ribbons or the stage in the same frame.
##
## Usage:
##   xvfb-run -a godot4 --path game --resolution 1600x900 \
##       tools/probe/arena_audit.tscn -- --out /tmp/audit

const MATCH_SCENE := "res://scenes/match.tscn"

## Camera parks, named for what each is meant to prove.
## The reference frame is shot from high in the corner of the lower bowl on
## the hard camera side, with the entrance end filling the left third.
const SHOTS := [
	{"name": "ref_high_corner", "pos": Vector3(24.0, 16.0, 20.0),
		"look": Vector3(0.0, 1.0, -6.0), "fov": 55.0},
	{"name": "ref_high_corner_wide", "pos": Vector3(30.0, 20.0, 26.0),
		"look": Vector3(0.0, 1.0, -8.0), "fov": 65.0},
	{"name": "hard_cam", "pos": Vector3(0.0, 9.0, 24.0),
		"look": Vector3(0.0, 1.0, -4.0), "fov": 50.0},
	{"name": "bowl_end", "pos": Vector3(0.0, 18.0, 34.0),
		"look": Vector3(0.0, 2.0, -12.0), "fov": 70.0},
	{"name": "stage_head_on", "pos": Vector3(0.0, 6.0, 8.0),
		"look": Vector3(0.0, 5.0, -34.0), "fov": 55.0},
]

var _out := "/tmp/arena_audit"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	add_child(load(MATCH_SCENE).instantiate())
	await get_tree().process_frame

	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	# The bowl is 111m long; the default 4000m far plane is fine but the near
	# plane matters for a camera sitting inside the seating deck.
	cam.near = 0.1
	cam.far = 500.0

	for shot in SHOTS:
		cam.fov = shot["fov"]
		cam.global_position = shot["pos"]
		cam.look_at(shot["look"], Vector3.UP)
		for _i in 24:
			await get_tree().process_frame
		var path := "%s/%s.png" % [_out, shot["name"]]
		get_viewport().get_texture().get_image().save_png(path)
		print("ARENA_AUDIT saved ", path)

	print("ARENA_AUDIT method=", RenderingServer.get_current_rendering_method())
	get_tree().quit()
