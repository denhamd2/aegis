extends Node
## Instruments the cadence of a match: how long every state actually lasts
## in ticks, how strikes are spaced inside an exchange, and how much of a
## match is spent moving, striking, or on the mat. Run headless:
##
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/feel_probe.tscn -- --seeds 1,2,3 --budget 30000 --trace
##
## A wrapper scene rather than a `-s` script, for the same reason the other
## two probes are (see ladder_probe.gd).
##
## Durations are counted from observed state occupancy rather than read off
## the constants, so a state that ends early (an input-driven getup, a hit
## that interrupts a recovery) is reported as what it actually was.

const MATCH_SCENE := "res://scenes/match.tscn"
## A gap longer than this ends an exchange: the two are no longer trading.
const EXCHANGE_GAP_TICKS := 120

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
		"method": "unfinished",
		"durations": {},
		"strike_ticks": [],
		"exchanges": [],
		"speeds": [],
		"distance": [],
	}
	var won := func(_winner: WrestlerController, method: String) -> void:
		row["method"] = method
	referee.match_won.connect(won)
	# Landed strikes only -- the tick a hit is applied, which is what an
	# exchange's rhythm is actually made of.
	var landed := func(attacker: WrestlerController, _defender: WrestlerController, move: MoveDef) -> void:
		if move == attacker.strike_move or attacker.strike_move_pool.has(move) \
				or move == attacker.running_attack_move:
			row["strike_ticks"].append(row["ticks"])
	a.move_landed.connect(landed)
	b.move_landed.connect(landed)

	var tick := 0
	var entered := {a.name: {"state": -1, "at": 0}, b.name: {"state": -1, "at": 0}}
	while tick < _budget and row["method"] == "unfinished":
		await get_tree().physics_frame
		tick += 1
		row["ticks"] = tick
		row["distance"].append(a.global_position.distance_to(b.global_position))
		for w: WrestlerController in [a, b]:
			var horizontal := Vector2(w.velocity.x, w.velocity.z).length()
			if horizontal > 0.01:
				row["speeds"].append(horizontal)
			var current: int = w.fsm.current_state
			var mark: Dictionary = entered[w.name]
			if current != mark["state"]:
				if mark["state"] >= 0:
					_record_duration(row, mark["state"], tick - mark["at"])
				mark["state"] = current
				mark["at"] = tick
	row["exchanges"] = _split_exchanges(row["strike_ticks"])
	scene.queue_free()
	await get_tree().process_frame
	return row

func _record_duration(row: Dictionary, state: int, ticks: int) -> void:
	var key: String = WrestlerFSM.State.keys()[state]
	var durations: Dictionary = row["durations"]
	if not durations.has(key):
		durations[key] = []
	durations[key].append(ticks)

## An exchange is a run of landed strikes with no gap longer than
## EXCHANGE_GAP_TICKS. Returns each one's length in strikes.
func _split_exchanges(strike_ticks: Array) -> Array:
	var exchanges := []
	var run := 0
	var previous := -EXCHANGE_GAP_TICKS - 1
	for t: int in strike_ticks:
		if t - previous > EXCHANGE_GAP_TICKS:
			if run > 0:
				exchanges.append(run)
			run = 0
		run += 1
		previous = t
	if run > 0:
		exchanges.append(run)
	return exchanges

func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += float(v)
	return total / values.size()

func _report() -> void:
	print("\n=== locomotion / strike feel probe ===")
	var all_durations := {}
	var all_gaps := []
	var all_exchanges := []
	var all_speeds := []
	var all_distance := []
	for row in _rows:
		var gaps := []
		var previous := -1
		for t: int in row["strike_ticks"]:
			if previous >= 0 and t - previous <= EXCHANGE_GAP_TICKS:
				gaps.append(t - previous)
			previous = t
		all_gaps.append_array(gaps)
		all_exchanges.append_array(row["exchanges"])
		all_speeds.append_array(row["speeds"])
		all_distance.append_array(row["distance"])
		print("seed %2d  %5d ticks  %-10s  strikes %2d in %d exchanges (mean %.1f)  strike gap mean %.0f ticks" % [
			row["seed"], row["ticks"], row["method"], row["strike_ticks"].size(),
			row["exchanges"].size(), _mean(row["exchanges"]), _mean(gaps)])
		for key: String in row["durations"]:
			if not all_durations.has(key):
				all_durations[key] = []
			all_durations[key].append_array(row["durations"][key])
		if _verbose:
			print("    exchanges %s" % [row["exchanges"]])

	print("\nstate durations over %d seeds (ticks; 60 = 1.00s)" % _rows.size())
	var keys := all_durations.keys()
	keys.sort()
	for key: String in keys:
		var values: Array = all_durations[key]
		print("  %-20s n %3d   mean %6.1f   min %4d   max %4d   (mean %.2fs)" % [
			key, values.size(), _mean(values), values.min(), values.max(),
			_mean(values) / 60.0])
	print("\nstrike cadence: %d landed strikes, gap within an exchange mean %.1f ticks (%.2fs)" % [
		all_gaps.size() + all_exchanges.size(), _mean(all_gaps), _mean(all_gaps) / 60.0])
	print("exchanges: %d, mean %.1f strikes each, longest %d" % [
		all_exchanges.size(), _mean(all_exchanges),
		all_exchanges.max() if not all_exchanges.is_empty() else 0])
	print("while moving: mean speed %.2f m/s, top %.2f (MOVE_SPEED %.1f, RUN_SPEED %.1f)" % [
		_mean(all_speeds), all_speeds.max() if not all_speeds.is_empty() else 0.0,
		WrestlerController.MOVE_SPEED, WrestlerController.RUN_SPEED])
	print("separation: mean %.2f m, max %.2f (strike range %.2f, tie-up range %.2f)" % [
		_mean(all_distance), all_distance.max() if not all_distance.is_empty() else 0.0,
		WrestlerController.STRIKE_HIT_RANGE, WrestlerController.TIE_UP_RANGE])
