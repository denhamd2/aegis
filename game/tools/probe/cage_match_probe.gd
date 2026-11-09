extends Node
## Steel Cage matches, AI against AI, headless (gauntlet/refs/steel_cage.md):
## how each ends (pin, submission, escape), when, and the cage's spots on the
## way -- escape attempts, men pulled off, whips into the steel. Each seed is
## run twice and the two runs must agree tick for tick at the end.
##
##   godot --headless --path game --fixed-fps 60 tools/probe/cage_match_probe.tscn \
##       -- --seeds 1,2,3 [--budget 40000]

const MATCH_SCENE := "res://scenes/match.tscn"

var _seeds: Array = [1, 2, 3]
var _budget := 40000


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--seeds": _seeds = Array(args[i + 1].split(",")).map(func(s): return int(s))
			"--budget": _budget = int(args[i + 1])
	var rows: Array = []
	for s: int in _seeds:
		var first: Dictionary = await _run(s)
		var second: Dictionary = await _run(s)
		first["deterministic"] = first["end"] == second["end"]
		rows.append(first)
		print("CAGE seed %d: %s" % [s, first])
	var methods := {}
	for r: Dictionary in rows:
		methods[r["method"]] = int(methods.get(r["method"], 0)) + 1
	print("CAGE_SUMMARY methods %s" % methods)
	get_tree().quit()


func _run(seed_value: int) -> Dictionary:
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), seed_value,
			true, MatchRules.Mode.STEEL_CAGE)
	scene.match_seed = seed_value
	add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var escape: CageEscape = scene.get_node("CageEscape")
	for w: WrestlerController in [a, b]:
		w.is_ai = true
		if w.ai:
			w.ai.setup_jitter(seed_value, w.player_index)
	var out := {"method": "none", "winner": "", "seconds": 0.0, "rams": 0, "falls_high": 0}
	var events: Array = []
	var start := Engine.get_physics_frames()
	var now := func() -> float: return snappedf((Engine.get_physics_frames() - start) / 60.0, 0.1)
	referee.match_won.connect(func(w: WrestlerController, m: String) -> void:
		out["method"] = m
		out["winner"] = w.entrance_style)
	escape.attempt_started.connect(func(w: WrestlerController, route: int) -> void:
		events.append("%s %s %s" % [now.call(), w.entrance_style,
				["climb", "door", "chase"][route]]))
	escape.pulled_off.connect(func(c: WrestlerController, by: WrestlerController) -> void:
		events.append("%s %s pulled off at %.1f m by %s" % [now.call(), c.entrance_style,
				c.global_position.y, by.entrance_style if by else "a blow"]))
	for w: WrestlerController in [a, b]:
		w.hit_the_cage.connect(func(_who: WrestlerController, s: float) -> void:
			if s >= 1.6:
				out["rams"] = int(out["rams"]) + 1)
	var tick := 0
	while tick < _budget and out["winner"] == "":
		await get_tree().physics_frame
		tick += 1
	for i in 5:
		await get_tree().physics_frame
	out["seconds"] = snappedf(tick / 60.0, 0.1)
	out["attempts"] = escape.attempts
	out["pull_offs"] = escape.pull_offs
	out["events"] = events
	out["end"] = "%s|%s|%s" % [tick, a.global_position.snappedf(0.001),
			b.global_position.snappedf(0.001)]
	scene.queue_free()
	await get_tree().process_frame
	return out
