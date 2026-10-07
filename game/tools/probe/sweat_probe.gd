extends Node
## How wet a man actually gets over a match, second by second (Sweat,
## BodyLife). AI against AI, headless.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/sweat_probe.tscn \
##       -- --seeds 1,2,3 [--budget 40000] [--was 100,160]
##
## Why it exists. Sweat.target() is a curve over the match clock and the
## damage taken, and both of its scales were set when an AI match here ran
## "30 s to 2.5 min" (sweat.gd). The match flow was then taken to 2K26's, and
## a match now runs about 475 s -- so the curve was being read a fifth of the
## way along and both terms sat pinned for the rest of the match. Arithmetic
## says that; this says it over a match the game actually plays, and carries
## the damage side, which no constant can predict.
##
## --was OLD_SECONDS,OLD_DAMAGE replays the same match through the old scales
## for a before/after on one simulation rather than two.
##
## Reads the simulation and writes nothing to it (ARCHITECTURE.md).

const MATCH_SCENE := "res://scenes/match.tscn"

var _seeds: Array = [1, 2, 3]
var _budget := 40000
var _was := Vector2(100.0, 160.0)
var _rows: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			continue
		match args[i]:
			"--seeds": _seeds = Array(args[i + 1].split(",")).map(func(s): return int(s))
			"--budget": _budget = int(args[i + 1])
			"--was":
				var p := args[i + 1].split(",")
				_was = Vector2(float(p[0]), float(p[1]))
	print("sweat scales: now %.0f s / %.0f dmg, was %.0f s / %.0f dmg" % [
			Sweat.FULL_SECONDS, Sweat.DAMAGE_FULL, _was.x, _was.y])
	for s in _seeds:
		_rows.append(await _run(s))
	_summary()
	get_tree().quit()


## The curve with the scales given, so the old one can be read off the same
## match as the new one.
static func target_with(seconds: float, damage: float, full_seconds: float,
		damage_full: float) -> float:
	return clampf(Sweat.BASE
			+ Sweat.TIME_SHARE * clampf(seconds / full_seconds, 0.0, 1.0)
			+ Sweat.DAMAGE_SHARE * clampf(damage / damage_full, 0.0, 1.0), 0.0, 1.0)


func _run(seed_value: int) -> Dictionary:
	var scene: Node = load(MATCH_SCENE).instantiate()
	var pair := Roster.pair_from_spec("roman,cody")
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
	referee.match_won.connect(func(_winner: WrestlerController, _m: String) -> void: won[0] = "done")
	# [second, damage A, damage B], sampled once a second off the men's own
	# clocks -- Sweat counts only the ticks a wrestler is physics-processing.
	var samples: Array = []
	var tick := 0
	while tick < _budget and won[0] == "":
		await get_tree().physics_frame
		tick += 1
		if tick % 60 == 0:
			samples.append([tick / 60.0,
					a.combat.total_damage() if a.combat else 0.0,
					b.combat.total_damage() if b.combat else 0.0])
	scene.queue_free()
	await get_tree().process_frame
	return _measure(seed_value, samples)


func _measure(seed_value: int, samples: Array) -> Dictionary:
	var secs: float = samples.back()[0] if not samples.is_empty() else 0.0
	# Share of the match each curve spends at or above these, averaged over the
	# two men: 0.8 is the look the owner called "way too much".
	var pinned_now := 0.0
	var pinned_was := 0.0
	var sum_now := 0.0
	var sum_was := 0.0
	for s in samples:
		for who in 2:
			var dmg: float = s[who + 1]
			var now := Sweat.target(s[0], dmg)
			var was := target_with(s[0], dmg, _was.x, _was.y)
			sum_now += now
			sum_was += was
			if now >= 0.8:
				pinned_now += 1.0
			if was >= 0.8:
				pinned_was += 1.0
	var n := maxf(samples.size() * 2.0, 1.0)
	var last: Array = samples.back() if not samples.is_empty() else [0.0, 0.0, 0.0]
	var row := {
		"seed": seed_value, "secs": secs,
		"dmg_end": (last[1] + last[2]) * 0.5,
		"mean_now": sum_now / n, "mean_was": sum_was / n,
		"pinned_now": pinned_now / n, "pinned_was": pinned_was / n,
		"end_now": (Sweat.target(secs, last[1]) + Sweat.target(secs, last[2])) * 0.5,
		"end_was": (target_with(secs, last[1], _was.x, _was.y)
				+ target_with(secs, last[2], _was.x, _was.y)) * 0.5,
	}
	print("seed %d  %5.1f s  damage at the bell-to-bell end %5.1f  |  wetness mean now %.2f (was %.2f)  at the finish %.2f (was %.2f)  share of match over 0.8: now %2.0f%% (was %2.0f%%)" % [
			seed_value, row["secs"], row["dmg_end"], row["mean_now"], row["mean_was"],
			row["end_now"], row["end_was"], row["pinned_now"] * 100.0, row["pinned_was"] * 100.0])
	# The curve itself, every 60 s, for the man who took the most.
	var line := "  minute:"
	for s in samples:
		if int(s[0]) % 60 != 0:
			continue
		var dmg: float = maxf(s[1], s[2])
		line += "  %d:%.2f/%.2f" % [int(s[0]) / 60, Sweat.target(s[0], dmg),
				target_with(s[0], dmg, _was.x, _was.y)]
	print(line + "   (now/was)")
	return row


func _summary() -> void:
	if _rows.is_empty():
		return
	var keys := ["secs", "dmg_end", "mean_now", "mean_was", "pinned_now", "pinned_was",
			"end_now", "end_was"]
	var line := "SWEAT mean over %d seeds:" % _rows.size()
	for k in keys:
		var sum := 0.0
		for r in _rows:
			sum += float(r[k])
		line += "  %s %.2f" % [k, sum / _rows.size()]
	print(line)
