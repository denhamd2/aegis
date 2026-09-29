extends Node
## Every sound MatchAudio plays over a whole AI match, against the match clock,
## beside the knockdowns and pins it should line up with. Headless.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/audio_log.tscn \
##       [-- --seed 2 --entrances]

func _ready() -> void:
	var seed_value := 2
	var entrances := false
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--seed": seed_value = int(args[i + 1])
			"--entrances": entrances = true
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], seed_value)
	scene.match_seed = seed_value
	scene.entrances = entrances
	add_child(scene)
	var tick := [0]
	var over := [-1]
	var counts := {}
	await get_tree().process_frame
	var audio: MatchAudio = scene.audio
	audio.sfx.played.connect(func(s: String, db: float) -> void:
		var family := s.trim_suffix("_" + s.get_slice("_", s.get_slice_count("_") - 1)) \
				if s.get_slice("_", s.get_slice_count("_") - 1).is_valid_int() else s
		counts[family] = counts.get(family, 0) + 1
		print("SND t%-6d %6.1fs  %-14s %5.1f dB" % [tick[0], tick[0] / 60.0, s, db]))
	for w: WrestlerController in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
		w.knocked_down.connect(func(v: WrestlerController) -> void:
			print("EVT t%-6d %6.1fs  knocked_down %s" % [tick[0], tick[0] / 60.0, v.name]))
		w.move_landed.connect(func(a: WrestlerController, _d, m: MoveDef) -> void:
			print("EVT t%-6d %6.1fs  landed %s by %s" % [tick[0], tick[0] / 60.0,
					m.resource_path.get_file(), a.name]))
	var referee: MatchReferee = scene.get_node("MatchReferee")
	referee.match_won.connect(func(_w, m) -> void:
		over[0] = tick[0]
		print("EVT t%-6d match won by %s" % [tick[0], m]))
	while tick[0] < 40000 and (over[0] < 0 or tick[0] < over[0] + 240):
		await get_tree().process_frame
		tick[0] += 1
	print("AUDIO_DONE ", counts)
	get_tree().quit()
