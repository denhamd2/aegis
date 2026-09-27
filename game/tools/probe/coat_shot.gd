extends Node
## Cody's entrance coat, looked at on purpose: the real entrance plays, and
## on every `--every` frames while he wears the coat the probe cuts to its
## own camera on him -- front, three-quarter, side, back in turn -- under
## the entrance's own lighting, then hands the shot back.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 960x960 --fixed-fps 30 tools/probe/coat_shot.tscn \
##       -- --out /tmp/coat --every 40
##
## Also frames Roman's worn title (the same four angles, closer, on his
## hips) while he has it on, for the belt's fit.

const MATCH_SCENE := "res://scenes/match.tscn"
## [name, direction from him in his frame (+Z behind), eye height, distance]
const ANGLES := [["front", Vector3(0, 0, -1)], ["three_quarter", Vector3(0.8, 0, -1)],
		["side", Vector3(1, 0, 0)], ["back", Vector3(0, 0, 1)]]

var _out := "/tmp/coat"
var _every := 40
var _frame := 0
var _shot := 0
## --bone NAME: frame that bone of the coat-wearer close up instead.
var _bone := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--every" and i + 1 < args.size():
			_every = int(args[i + 1])
		elif args[i] == "--bone" and i + 1 < args.size():
			_bone = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var pair := Roster.pair_from_spec("")
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var cam := Camera3D.new()
	cam.fov = 38.0
	scene.add_child(cam)
	var rang := [false]
	director.bell.connect(func(): rang[0] = true)
	while not rang[0]:
		await get_tree().process_frame
		_frame += 1
		if _frame % _every != 0:
			continue
		var target: WrestlerController = null
		var what := ""
		for w: WrestlerController in director._coats:
			var coat: EntranceCoat = director._coats[w]
			if is_instance_valid(coat) and coat._root and coat._root.visible:
				target = w
				what = "coat"
		for w: WrestlerController in director._props:
			var props: EntranceProps = director._props[w]
			if is_instance_valid(props) and props._title_state == "worn":
				target = w
				what = "belt"
		if target == null:
			continue
		var prev := get_viewport().get_camera_3d()
		var a: Array = ANGLES[_shot % ANGLES.size()]
		var turn := Basis(Vector3.UP, target.global_rotation.y)
		var dir: Vector3 = (turn * (a[1] as Vector3)).normalized()
		var aim := target.global_position + Vector3(0, 1.05 if what == "coat" else 1.1, 0)
		var dist := 3.4 if what == "coat" else 1.6
		if _bone != "" and what == "coat":
			var sk := target.skeleton
			var bi := sk.find_bone(target._skeleton_bone_name(_bone))
			aim = (sk.global_transform * sk.get_bone_global_pose(bi)).origin
			dist = 0.8
		cam.global_position = aim + dir * dist + Vector3(0, 0.15, 0)
		cam.look_at(aim)
		cam.make_current()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(
				"%s/%s_%05d_%s.jpg" % [_out, what, _frame, a[0]], 0.88)
		_shot += 1
		if prev:
			prev.make_current()
	print("COAT_SHOT %d shots" % _shot)
	get_tree().quit()
