extends Node
## Renders a set piece (TopRopeSpot, PossumSpot, DiveSpot) from its start,
## without waiting for a match to reach it: Roman is put down mid-ring and the
## spot is started on him.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 960x540 tools/probe/spot_shot.tscn -- \
##       --spot moonsault|possum|dive --out /tmp/spot [--every 6] [--seed 3]

var _out := "/tmp/spot"
var _spot := "moonsault"
var _every := 6
var _seed := 3


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--out": _out = args[i + 1]
			"--spot": _spot = args[i + 1]
			"--every": _every = int(args[i + 1])
			"--seed": _seed = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), _seed)
	scene.entrances = false
	scene.match_seed = _seed
	add_child(scene)
	var roman: WrestlerController = scene.get_node("WrestlerA")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	for w in [roman, cody]:
		w.is_ai = false
	for i in 4:
		await get_tree().physics_frame
	var referee := scene.get_node("MatchReferee")
	var spot_name := ""
	match _spot:
		"moonsault":
			roman.global_position = Vector3(0.3, roman.global_position.y, 0.0)
			roman._go_down()
			referee._start_top_rope(cody, roman)
			spot_name = "TopRopeSpot"
		"possum":
			roman._go_down()
			roman.fsm.ticks_in_state = PossumSpot.MIN_DOWN_TICKS
			cody.global_position = roman.global_transform * PossumSpot.STAND_AT
			referee._start_possum(roman, cody)
			spot_name = "PossumSpot"
		"dive":
			roman.global_position = Vector3(2.0, roman.global_position.y, 0.4)
			roman._go_down()
			referee._start_dive(cody, roman)
			spot_name = "DiveSpot"
	var spot := scene.get_node_or_null(spot_name)
	var n := 0
	var tick := 0
	while spot != null and is_instance_valid(spot) and tick < 3000:
		await get_tree().physics_frame
		if tick % _every == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%04d.png" % [_out, _spot, n])
			n += 1
		tick += 1
	print("SPOT_SHOT %s frames=%d ticks=%d" % [_spot, n, tick])
	get_tree().quit()
