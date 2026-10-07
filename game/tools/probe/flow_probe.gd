extends Node
## The flow of a match, second by second, measured the way the 2K26 reference
## was (gauntlet/refs/match_engine_2k26.md): how long a man stays down, how far
## apart the moves land, how long one man stays in control, how much of the
## match is two men standing apart. AI against AI, headless.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/flow_probe.tscn \
##       -- --seeds 1,2,3 [--wrestlers roman,cody|mannequin] [--budget 40000] [--strip 120]
##
## `mannequin` fights match.tscn's box men: the same AI and referee, several
## times cheaper to simulate than the skinned roster.
##
## --strip N prints the first N seconds as a strip: one character per second
## per man (. standing, s striking/moving, g grappling, h hurt, D down,
## p pinned or held), so a match can be read against the 2K26 sheets.
##
## --fixed-fps 60, not 6000: one physics tick per frame, run as fast as the
## machine goes. At 6000 every tick waits out 100 idle frames.

const MATCH_SCENE := "res://scenes/match.tscn"
const S := WrestlerFSM.State

var _seeds: Array = [1, 2, 3]
var _wrestlers := "roman,cody"
var _budget := 40000
var _strip := 0
var _rows: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			continue
		match args[i]:
			"--seeds": _seeds = Array(args[i + 1].split(",")).map(func(s): return int(s))
			"--wrestlers": _wrestlers = args[i + 1]
			"--budget": _budget = int(args[i + 1])
			"--strip": _strip = int(args[i + 1])
	for s in _seeds:
		_rows.append(await _run(s))
	_summary()
	get_tree().quit()


static func kind(state: int) -> String:
	match state:
		S.IDLE, S.LOCOMOTION, S.RUN:
			return "."
		S.STRIKE, S.RUNNING_ATTACK, S.MOVE_EXEC, S.FINISHER, S.TAUNT, S.IRISH_WHIP:
			return "s"
		S.TIE_UP, S.GRAPPLE_HOLD, S.PIN_ATTACKER, S.SUBMISSION_ATTACKER:
			return "g"
		S.HIT_REACT, S.STUNNED:
			return "h"
		S.DOWN, S.GETUP:
			return "D"
		S.PIN_DEFENDER, S.SUBMISSION_DEFENDER:
			return "p"
	return "."


func _run(seed_value: int) -> Dictionary:
	var scene: Node = load(MATCH_SCENE).instantiate()
	if _wrestlers != "mannequin":
		var pair := Roster.pair_from_spec(_wrestlers)
		TitleScreen.configure_match(scene, pair[0], pair[1], seed_value)
	scene.match_seed = seed_value
	add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	for w: WrestlerController in [a, b]:
		w.is_ai = true
		if w.ai:
			w.ai.setup_jitter(seed_value, w.player_index)
	var won := [""]
	referee.match_won.connect(func(winner: WrestlerController, _m: String) -> void: won[0] = winner.name)
	var landed_at: Array = []   # [tick, attacker index]
	var lander := func(attacker: WrestlerController, _d, _m) -> void:
		landed_at.append([Engine.get_physics_frames(), 0 if attacker == a else 1])
	a.move_landed.connect(lander)
	b.move_landed.connect(lander)
	var start := Engine.get_physics_frames()
	var per_tick: Array = []    # [kind a, kind b]
	var tick := 0
	while tick < _budget and won[0] == "":
		await get_tree().physics_frame
		tick += 1
		per_tick.append([kind(a.fsm.current_state), kind(b.fsm.current_state)])
	scene.queue_free()
	await get_tree().process_frame
	for e in landed_at:
		e[0] -= start
	return _measure(seed_value, per_tick, landed_at)


func _measure(seed_value: int, per_tick: Array, landed_at: Array) -> Dictionary:
	var n := per_tick.size()
	var down_spells: Array = []
	var neutral := 0
	var double_down := 0
	var any_down := 0
	for who in 2:
		var run := 0
		for t in n:
			var k: String = per_tick[t][who]
			if k == "D" or k == "p":
				run += 1
			elif run > 0:
				down_spells.append(run / 60.0)
				run = 0
		if run > 0:
			down_spells.append(run / 60.0)
	for t in n:
		var ka: String = per_tick[t][0]
		var kb: String = per_tick[t][1]
		if ka == "." and kb == ".":
			neutral += 1
		var da := ka == "D" or ka == "p"
		var db := kb == "D" or kb == "p"
		if da and db:
			double_down += 1
		if da or db:
			any_down += 1
	# Control: runs of landed moves by the same man.
	var stretches: Array = []
	var gaps: Array = []
	var i := 0
	while i < landed_at.size():
		var j := i
		while j + 1 < landed_at.size() and landed_at[j + 1][1] == landed_at[i][1]:
			j += 1
		stretches.append([j - i + 1, (landed_at[j][0] - landed_at[i][0]) / 60.0])
		i = j + 1
	for k in range(1, landed_at.size()):
		gaps.append((landed_at[k][0] - landed_at[k - 1][0]) / 60.0)
	down_spells.sort()
	gaps.sort()
	var row := {
		"seed": seed_value, "secs": n / 60.0, "landed": landed_at.size(),
		"per_min": landed_at.size() / maxf(n / 3600.0, 0.001),
		"gap_med": _median(gaps), "down_med": _median(down_spells),
		"down_max": down_spells.back() if not down_spells.is_empty() else 0.0,
		"down_spells": down_spells.size(),
		"any_down": float(any_down) / maxf(n, 1), "neutral": float(neutral) / maxf(n, 1),
		"double_down": double_down / 60.0,
		"stretch_moves": _mean(stretches.map(func(s): return float(s[0]))),
		"stretch_max": stretches.map(func(s): return s[0]).max() if not stretches.is_empty() else 0,
		"stretch_secs": _mean(stretches.map(func(s): return float(s[1]))),
	}
	print("seed %d  %5.1f s  landed %3d (%.1f/min, gap med %.1f s)  down spells %d (med %.1f s, max %.1f s)  someone down %2.0f%%  both standing idle %2.0f%%  double-down %.1f s  control runs %.1f moves / %.1f s (max %d)" % [
			seed_value, row["secs"], row["landed"], row["per_min"], row["gap_med"],
			row["down_spells"], row["down_med"], row["down_max"], row["any_down"] * 100.0,
			row["neutral"] * 100.0, row["double_down"], row["stretch_moves"],
			row["stretch_secs"], row["stretch_max"]])
	if _strip > 0:
		for who in 2:
			var line := ""
			for sec in mini(_strip, n / 60):
				var k: String = per_tick[sec * 60 + 30][who]
				line += k
			print("  %s %s" % ["A" if who == 0 else "B", line])
	return row


static func _median(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	return float(xs[xs.size() / 2])


static func _mean(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := 0.0
	for x in xs:
		s += float(x)
	return s / xs.size()


func _summary() -> void:
	if _rows.is_empty():
		return
	var keys := ["secs", "per_min", "gap_med", "down_med", "down_max", "any_down", "neutral", "stretch_moves", "stretch_secs"]
	var line := "FLOW mean over %d seeds:" % _rows.size()
	for k in keys:
		line += "  %s %.2f" % [k, _mean(_rows.map(func(r): return float(r[k])))]
	print(line)
