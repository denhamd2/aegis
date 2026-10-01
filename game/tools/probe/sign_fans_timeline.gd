extends Node
## When the ringside sign fans (SignFans) are up, over a whole AI match with
## its entrances: every change of stage, against the entrance's shot and the
## match clock. Headless.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/sign_fans_timeline.tscn \
##       [-- --seed 2 --budget 30000]

func _ready() -> void:
	var seed_value := 2
	var budget := 30000
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--seed": seed_value = int(args[i + 1])
			"--budget": budget = int(args[i + 1])
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], seed_value)
	scene.match_seed = seed_value
	scene.entrances = true
	add_child(scene)
	var shot := [""]
	var bell := [-1]
	var over := [false]
	var tick := [0]
	await get_tree().process_frame
	var director := scene.get_node_or_null("EntranceDirector") as EntranceDirector
	if director:
		director.beat_started.connect(func(s: String) -> void: shot[0] = s)
		director.bell.connect(func() -> void: bell[0] = tick[0])
	var referee: MatchReferee = scene.get_node("MatchReferee")
	referee.match_won.connect(func(_w, _m) -> void: over[0] = true)
	var fans := get_tree().get_first_node_in_group("sign_fans") as SignFans
	var last := [-1, -1]
	while tick[0] < budget and not over[0]:
		await get_tree().physics_frame
		tick[0] += 1
		for n in fans.fans.size():
			var st: int = fans.fans[n].stage
			if st != last[n]:
				last[n] = st
				print("FAN %d t%-6d %-9s shot=%-14s %s" % [n, tick[0], SignFan.Stage.keys()[st], shot[0],
						"(before the bell)" if bell[0] < 0 else "match +%.1fs" % ((tick[0] - bell[0]) / 60.0)])
	print("FANS_DONE tick %d, bell at %d, raises in the match %d, %s" % [tick[0], bell[0], fans.match_raises,
			"match over" if over[0] else "budget"])
	get_tree().quit()
