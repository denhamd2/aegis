extends Node
## Seeded AI comparison: roster identities/moves, with the shared base rig by
## default. Arena presentation is omitted; this is logic/contact evidence only.
## --real-models retains the roster meshes for a targeted corroborating run.

var seeds: Array[int] = [1, 2]
var matchups: Array[String] = ["roman,cody", "cody,roman", "roman,kenny",
		"kenny,roman", "cody,kenny", "kenny,cody"]
var budget := 48000
var output := "/tmp/aegis-ai-quality.json"
var real_models := false
var rows: Array[Dictionary] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	real_models = args.has("--real-models")
	for i in maxi(0, args.size() - 1):
		match args[i]:
			"--seeds":
				seeds.clear()
				for value in args[i + 1].split(","):
					seeds.append(int(value))
			"--matchups":
				matchups.clear()
				for value in args[i + 1].split(";"):
					matchups.append(value)
			"--ticks": budget = maxi(1, int(args[i + 1]))
			"--out": output = args[i + 1]
	for pair in matchups:
		for seed_value in seeds:
			rows.append(await _run(pair, seed_value))
			_save()
	get_tree().quit()


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"real_models": real_models,
			"arena_omitted": true, "tick_budget": budget, "rows": rows}, "\t"))


func _run(spec: String, seed_value: int) -> Dictionary:
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	var pair := Roster.pair_from_spec(spec)
	TitleScreen.configure_match(scene, pair[0], pair[1], seed_value, true)
	scene.match_seed = seed_value
	scene.entrances = false
	for part in ["Arena", "LightRig"]:
		var omitted := scene.get_node_or_null(part)
		if omitted:
			omitted.free()
	if not real_models:
		for slot in ["WrestlerA", "WrestlerB"]:
			scene.get_node(slot).character_model_scene = load("res://assets/characters/wrestler_base.glb")
	add_child(scene)
	for part in ["RefereeActor", "MatchAudio", "CrowdReaction", "MatchHUD", "MatchCamera"]:
		var cosmetic := scene.get_node_or_null(part)
		if cosmetic:
			cosmetic.process_mode = Node.PROCESS_MODE_DISABLED
	var men: Array[WrestlerController] = [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	var row := {"matchup": spec, "seed": seed_value, "ticks": 0, "winner": "",
			"method": "budget", "fighters": [{"id": pair[0].id, "sequence": [],
			"rope_runs": 0, "spear_setups": 0, "finisher_ready_ticks": 0},
			{"id": pair[1].id, "sequence": [], "rope_runs": 0,
			"spear_setups": 0, "finisher_ready_ticks": 0}]}
	for index in 2:
		var fighter: Dictionary = row["fighters"][index]
		men[index].move_attempted.connect(func(_a, _d, move: MoveDef) -> void:
			fighter["sequence"].append(String(move.animation_pair_id)))
	var referee: MatchReferee = scene.get_node("MatchReferee")
	referee.match_won.connect(func(winner: WrestlerController, method: String) -> void:
		row["winner"] = winner.display_name
		row["method"] = method)
	var was_rope := [false, false]
	var was_setup := [false, false]
	var started := Time.get_ticks_msec()
	for tick in budget:
		await get_tree().physics_frame
		row["ticks"] = tick + 1
		for index in 2:
			var man := men[index]
			var fighter: Dictionary = row["fighters"][index]
			if man.rope_running and not was_rope[index]:
				fighter["rope_runs"] += 1
			if man._stalking and not was_setup[index]:
				fighter["spear_setups"] += 1
			was_rope[index] = man.rope_running
			was_setup[index] = man._stalking
			if man.combat.can_finisher():
				fighter["finisher_ready_ticks"] += 1
		if row["winner"] != "":
			break
		if (tick + 1) % 3000 == 0:
			print("AI_QUALITY progress %s seed=%d ticks=%d" % [spec, seed_value, tick + 1])
	for index in 2:
		row["fighters"][index]["attempted"] = men[index]._attempted_moves.duplicate()
		row["fighters"][index]["landed"] = men[index]._landed_moves.duplicate()
	row["elapsed_ms"] = Time.get_ticks_msec() - started
	print("AI_QUALITY %s seed=%d ticks=%d winner=%s elapsed_ms=%d" % [
			spec, seed_value, row["ticks"], row["winner"], row["elapsed_ms"]])
	scene.queue_free()
	await get_tree().process_frame
	return row
