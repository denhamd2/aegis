extends Node
## Frames of Roman's props being handed on: the belt, then the ula fala, from a
## fixed camera that sees the ring's +X side and the timekeeper's table.
##
##   xvfb-run -a godot --path game --rendering-driver vulkan \
##       --resolution 960x540 tools/probe/handoff_shots.tscn -- --out /tmp/handoff \
##       [--every 20] [--view 0|1|2] [--until 1800]
##
## Starts straight at the belt's unbuckle (skipping the walk) and steps the
## real scene; a frame every --every ticks, and one on every PropHandoff step.
## --view: 0 wide of the ring side, 1 the rope pass close, 2 the table close.

const MATCH_SCENE := "res://scenes/match.tscn"
const VIEWS := [
	[Vector3(5.5, 2.4, -4.2), Vector3(1.8, 0.6, 0.2), 52.0],
	[Vector3(4.6, 0.9, -1.9), Vector3(2.9, 0.4, 0.0), 40.0],
	[Vector3(2.6, 1.6, 4.4), Vector3(4.2, -0.2, 1.4), 45.0],
]

var _out := "/tmp/handoff"
var _every := 20
var _view := 0
var _until := 1800


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--out": _out = args[i + 1]
			"--every": _every = int(args[i + 1])
			"--view": _view = int(args[i + 1])
			"--until": _until = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)
	var pair := Roster.pair_from_spec("roman,cody")
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var roman: WrestlerController = scene.get_node("WrestlerA")
	var handoff: PropHandoff = scene.get_node("PropHandoff")
	# Straight to the belt coming off his waist.
	for i in director._beats.size():
		var bt: Dictionary = director._beats[i]
		if String(bt.get("clip", "")) == "strikes/title_unbuckle":
			roman.visible = true
			roman.global_position = Vector3(-0.4, 0.0, -0.6)
			director._props[roman] = EntranceProps.dress(roman, true)
			director._beat = i
			director._start_beat()
			break
	var cam := Camera3D.new()
	cam.current = true
	cam.far = 200.0
	scene.add_child(cam)
	var v: Array = VIEWS[_view]
	cam.global_position = v[0]
	cam.look_at(v[1])
	cam.fov = v[2]
	var last_step := -1
	var frame := 0
	while frame < _until:
		await RenderingServer.frame_post_draw
		var stepped: bool = handoff.step != last_step
		if stepped or frame % _every == 0:
			get_viewport().get_texture().get_image().save_png(
					"%s/h_%05d_s%d.png" % [_out, frame, handoff.step])
		if stepped:
			print("frame %d step %d beat %d" % [frame, handoff.step, director._beat])
		last_step = handoff.step
		frame += 1
	get_tree().quit()
