extends Node
## Instruments AI-vs-AI matches and reports how they are *finished*: every
## cover, the count it reached, whether the defender kicked out and how
## close he came, every submission, and the method the match ended on.
## Run headless:
##
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/pin_probe.tscn -- --seeds 1,2,3 --budget 30000 --trace
##
## A wrapper scene rather than a `-s` script, for the same reason
## ladder_probe.tscn is: a -s SceneTree script does not register the
## project's class_name globals, so every script with a typed
## WrestlerController field fails to compile there (see README).
##
## MatchReferee exposes no signal for a pin ending, so episodes are
## reconstructed by polling is_pin_active()/pin_count() once per physics
## frame. That is enough: the referee latches the count (see pin_count()),
## so the digit on screen when a fall ends is still readable on the tick
## after it ends.

const MATCH_SCENE := "res://scenes/match.tscn"

var _seeds: Array[int] = []
var _budget: int = 30000
var _rows: Array[Dictionary] = []
var _verbose: bool = false

func _ready() -> void:
	_parse_args()
	for seed_value in _seeds:
		_rows.append(await _run_match(seed_value))
	_report()
	get_tree().quit()

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seeds" and i + 1 < args.size():
			for token in args[i + 1].split(","):
				_seeds.append(int(token))
		elif args[i] == "--trace":
			_verbose = true
		elif args[i] == "--budget" and i + 1 < args.size():
			_budget = int(args[i + 1])
	if _seeds.is_empty():
		_seeds = [1, 2, 3, 4, 5]

func _run_match(seed_value: int) -> Dictionary:
	var scene: Node = load(MATCH_SCENE).instantiate()
	scene.match_seed = seed_value
	add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	for w: WrestlerController in [a, b]:
		w.is_ai = true
		if w.ai:
			w.ai.setup_jitter(seed_value, w.player_index)

	var row := {
		"seed": seed_value,
		"ticks": 0,
		"winner": "",
		"method": "unfinished",
		"falls": [],
		"holds": [],
		"knockdowns": 0,
	}
	var won := func(winner: WrestlerController, method: String) -> void:
		row["winner"] = winner.name
		row["method"] = method
	referee.match_won.connect(won)
	var went_down := func(_w: WrestlerController) -> void:
		row["knockdowns"] += 1
	a.knocked_down.connect(went_down)
	b.knocked_down.connect(went_down)

	var tick := 0
	var fall: Dictionary = {}
	var hold: Dictionary = {}
	while tick < _budget and row["winner"] == "":
		await get_tree().physics_frame
		tick += 1
		if referee.is_pin_active():
			if fall.is_empty():
				fall = _open_fall(referee, tick)
			fall["ticks"] += 1
			fall["count"] = maxi(fall["count"], referee.pin_count())
			var minigame: PinMinigame = fall["defender_node"]._pin_minigame
			if minigame:
				fall["progress"] = minigame.progress
		elif not fall.is_empty():
			_close_fall(fall, referee, row)
			fall = {}
		if referee.is_submission_active():
			if hold.is_empty():
				var minigame: SubmissionMinigame = referee._submission_defender._submission_minigame
				hold = {
					"at_tick": tick,
					"ticks": 0,
					"peak": Vector2.ZERO,
					"attacker_rate": minigame.attacker_rate if minigame else 0.0,
					"defender_rate": minigame.defender_rate if minigame else 0.0,
				}
			hold["ticks"] += 1
			var progress := referee.submission_progress()
			hold["peak"] = Vector2(maxf(hold["peak"].x, progress.x), maxf(hold["peak"].y, progress.y))
		elif not hold.is_empty():
			hold["outcome"] = "tap" if row["winner"] != "" else "escape"
			row["holds"].append(hold)
			hold = {}
	# A fall or hold still running when the budget or the win lands closes
	# here, so a match that ends on a three-count still reports that fall.
	if not fall.is_empty():
		_close_fall(fall, referee, row)
	if not hold.is_empty():
		hold["outcome"] = "tap" if row["winner"] != "" else "unfinished"
		row["holds"].append(hold)
	row["ticks"] = tick
	scene.queue_free()
	await get_tree().process_frame
	return row

## Reads the state a cover starts from — the two numbers that decide how
## escapable it is (the defender's damage and the attacker's momentum, via
## CombatSystem.kickout_window_fraction) plus the window they produced.
func _open_fall(referee: MatchReferee, tick: int) -> Dictionary:
	var defender: WrestlerController = referee._pin_defender
	var attacker: WrestlerController = referee._pin_attacker
	var minigame: PinMinigame = defender._pin_minigame
	return {
		"at_tick": tick,
		"ticks": 0,
		"count": 0,
		"progress": 0.0,
		"defender": defender.name,
		"defender_node": defender,
		"damage": defender.combat.total_damage(),
		"attacker_momentum": attacker.combat.momentum,
		"window": minigame.target_width if minigame else 0.0,
	}

func _close_fall(fall: Dictionary, referee: MatchReferee, row: Dictionary) -> void:
	fall["count"] = maxi(fall["count"], referee.pin_count())
	# The fill is read once more here rather than trusting the last
	# per-tick sample: a kickout ends the fall on the same tick the meter
	# crosses PROGRESS_THRESHOLD, so the polled value is always one press
	# short of the one that actually won it.
	var minigame: PinMinigame = fall["defender_node"]._pin_minigame
	if minigame:
		fall["progress"] = minigame.progress
	fall["outcome"] = "pinfall" if row["method"] == "pinfall" else "kickout"
	fall.erase("defender_node")
	row["falls"].append(fall)

func _report() -> void:
	print("\n=== pin / kickout probe ===")
	var falls := 0
	var kickouts := 0
	var counts := {0: 0, 1: 0, 2: 0, 3: 0}
	var methods := {}
	var seeds_with_a_fall := 0
	var near_falls := 0
	var window_sum := 0.0
	var progress_sum := 0.0
	for row in _rows:
		print("seed %d  %5d ticks  %-10s by %-9s  falls %d  holds %d  knockdowns %d" % [
			row["seed"], row["ticks"], row["method"], row["winner"],
			row["falls"].size(), row["holds"].size(), row["knockdowns"]])
		methods[row["method"]] = methods.get(row["method"], 0) + 1
		if not row["falls"].is_empty():
			seeds_with_a_fall += 1
		for f: Dictionary in row["falls"]:
			falls += 1
			counts[f["count"]] = counts.get(f["count"], 0) + 1
			window_sum += f["window"]
			progress_sum += f["progress"]
			if f["outcome"] == "kickout":
				kickouts += 1
				if f["count"] >= 2:
					near_falls += 1
			if _verbose:
				print("    fall  t%5d  on %-9s  dmg %5.1f  att.mom %5.1f  window %.2f  count %d  %3d ticks  fill %4.1f/%.0f  %s" % [
					f["at_tick"], f["defender"], f["damage"], f["attacker_momentum"],
					f["window"], f["count"], f["ticks"], f["progress"],
					PinMinigame.PROGRESS_THRESHOLD, f["outcome"]])
		for h: Dictionary in row["holds"]:
			if _verbose:
				print("    hold  t%5d  %3d ticks  rates %.2f/%.2f  peak %.2f/%.2f  %s" % [
					h["at_tick"], h["ticks"], h["attacker_rate"], h["defender_rate"],
					h["peak"].x, h["peak"].y, h["outcome"]])
	print("\nseeds: %d   %s" % [_rows.size(), methods])
	print("a cover happened at all in %d of %d seeds" % [seeds_with_a_fall, _rows.size()])
	print("falls: %d   kicked out of %d   count reached: %s" % [falls, kickouts, counts])
	print("near-falls (kicked out at 2 or later): %d of %d kickouts" % [near_falls, kickouts])
	if falls > 0:
		print("per fall, mean: kickout window %.2f   fill reached %.1f of %.0f" % [
			window_sum / falls, progress_sum / falls, PinMinigame.PROGRESS_THRESHOLD])
