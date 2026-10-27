extends Node3D
## A character model on its own, turned round under a stand-in for the match
## light: four body views and four head views, for look-dev against a
## reference sheet.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1280x720 tools/probe/model_turnaround.tscn -- \
##       --scene res://scenes/kenny_model.tscn --out /tmp/turn [--anim Idle --at 0.3]
##
## face_shot.tscn shoots a man in the real match, which is the final word on
## how he looks there -- and under a software rasteriser costs ten minutes a
## frame with the arena and the crowd in it. This has nothing but the man:
## seconds a frame, so a texture or groom can be iterated on. Its light is the
## match's in kind -- a warm key high in front, a cooler fill, a cold rim
## behind, the match's AgX tonemap at its exposure (scenes/match.tscn) -- not
## its measured levels: close a look on face_shot, not on this.
##
## Writes body_<view>.png and head_<view>.png for front, three_quarter, side
## and back.

var _scene := "res://scenes/kenny_model.tscn"
var _out := "/tmp/turn"
var _anim := "Idle"
var _at := 0.3

const VIEWS := {"front": 0.0, "three_quarter": 40.0, "side": 90.0, "back": 180.0}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--scene": _scene = args[i + 1]
			"--out": _out = args[i + 1]
			"--anim": _anim = args[i + 1]
			"--at": _at = float(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)
	_set_stage()
	var model := (load(_scene) as PackedScene).instantiate() as Node3D
	add_child(model)
	await get_tree().process_frame
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player and player.has_animation(_anim):
		player.play(_anim)
		player.seek(player.get_animation(_anim).length * _at, true)
		player.pause()
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := Vector3(0.0, 1.70, 0.0)
	if skeleton and skeleton.find_bone("Head") >= 0:
		head = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin \
				+ Vector3(0.0, 0.08, 0.0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	for frame in 4:
		await RenderingServer.frame_post_draw
	for kind: Array in [["body", Vector3(0.0, 1.05, 0.0), 3.6, 34.0],
			["head", head, 0.85, 30.0]]:
		for view: String in VIEWS:
			var yaw := deg_to_rad(VIEWS[view])
			# The model faces +Z: the front view looks back at him from +Z.
			var dir := Vector3(sin(yaw), 0.0, cos(yaw))
			var target: Vector3 = kind[1]
			cam.fov = kind[3]
			cam.look_at_from_position(target + dir * float(kind[2]) + Vector3.UP * 0.04, target)
			for frame in 3:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					"%s/%s_%s.png" % [_out, kind[0], view])
	print("MODEL_TURNAROUND done")
	get_tree().quit()


func _set_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.65)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_white = 2.0
	env.tonemap_exposure = 1.7
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	# Key: warm, high and in front, a little to his right (the hard camera's
	# side of the rig); fill: cooler and weaker from his left; rim: cold,
	# behind and above.
	for light: Array in [[Vector3(-50.0, -20.0, 0.0), Color(1.0, 0.92, 0.82), 1.1],
			[Vector3(-25.0, 140.0, 0.0), Color(0.80, 0.86, 1.0), 0.35],
			[Vector3(-35.0, 200.0, 0.0), Color(0.75, 0.85, 1.0), 0.6]]:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = light[0]
		sun.light_color = light[1]
		sun.light_energy = light[2]
		sun.shadow_enabled = light[2] > 1.0
		add_child(sun)
