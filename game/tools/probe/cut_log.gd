extends Node
## Every camera cut through the entrances, with its time and shot, and the
## coat's state for the coat-flicker hunt. Headless, no drawing:
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/cut_log.tscn \
##       [-- --from-shot end_wide]
##
## A cut is the camera moving more than CUT_M in one frame. Each line is
## "t=seconds beat shot dist" so a run of short shots is easy to read.

const CUT_M := 0.6

var _from_shot := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--from-shot" and i + 1 < args.size():
			_from_shot = args[i + 1]
	var pair := Roster.pair_from_spec("")
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	if _from_shot != "":
		for i in director._beats.size():
			if String((director._beats[i] as Dictionary).get("shot", "")) == _from_shot:
				director._beat = i
				director._start_beat()
				break
	var rang := [false]
	director.bell.connect(func(): rang[0] = true)
	var cam := get_viewport().get_camera_3d()
	var last := Vector3.INF
	var frame := 0
	var t0 := 0.0
	var after := 0
	var last_beat := -1
	while after < 120:
		await get_tree().process_frame
		frame += 1
		cam = get_viewport().get_camera_3d()
		var p := cam.global_position if cam else Vector3.ZERO
		var b: Dictionary = director._beats[mini(director._beat, director._beats.size() - 1)] \
				if not rang[0] else {"shot": "match"}
		if director._beat != last_beat:
			last_beat = director._beat
			print("BEAT t=%.2f %d %s" % [frame / 60.0, last_beat, b.get("shot", "")])
		if last != Vector3.INF and p.distance_to(last) > CUT_M:
			var t := frame / 60.0
			print("CUT t=%.2f held=%.2f beat=%d shot=%s" % [t, t - t0, director._beat, b.get("shot", "")])
			t0 = t
		last = p
		if rang[0]:
			after += 1
	print("CUT_LOG done at %.2f" % (frame / 60.0))
	get_tree().quit()
