extends Node
## Instruments AI-vs-AI matches and reports which rungs of the momentum
## ladder actually fire. Run headless:
##
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/ladder_probe.tscn -- --seeds 1,2,3 --budget 20000
##
## A wrapper scene rather than a `-s` script: a -s SceneTree script does not
## register the project's class_name globals, so every script with a typed
## WrestlerController field fails to compile there (see README).

const MATCH_SCENE := "res://scenes/match.tscn"

var _seeds: Array[int] = []
var _budget: int = 20000
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
	# What match_setup.gd does for a recording run: both sides on the AI,
	# each with its own deterministic mash jitter.
	for w: WrestlerController in [a, b]:
		w.is_ai = true
		if w.ai:
			w.ai.setup_jitter(seed_value, w.player_index)

	var row := {
		"seed": seed_value,
		"ticks": 0,
		"winner": "",
		"method": "none",
		"peak_momentum": {a.name: 0.0, b.name: 0.0},
		"tiers": {},
		"landed": 0,
		"earned": {a.name: 0.0, b.name: 0.0},
		"trace": [],
		"entries": {},
		"ticks_in": {},
	}
	for who: String in [a.name, b.name]:
		row["entries"][who] = {}
		row["ticks_in"][who] = {}
	for who: String in [a.name, b.name]:
		row["tiers"][who] = {"strike": 0, "running": 0, "grapple": 0, "power": 0, "signature": 0, "finisher": 0}

	var landed := func(attacker: WrestlerController, defender: WrestlerController, move: MoveDef) -> void:
		row["landed"] += 1
		var tier := _tier_of(attacker, move)
		row["tiers"][attacker.name][tier] += 1
		row["earned"][attacker.name] += move.momentum_gain
		# apply_momentum() has already run by the time move_landed reaches
		# here for a grapple, so recover the pre-move meter arithmetically.
		var after: float = attacker.combat.momentum
		row["trace"].append("      %-9s %-9s %-26s %5.1f -> %5.1f   dmg %5.1f" % [
			attacker.name, tier, move.resource_path.get_file().get_basename(),
			after + move.momentum_cost - move.momentum_gain, after,
			defender.combat.total_damage()])
	a.move_landed.connect(landed)
	b.move_landed.connect(landed)
	var won := func(winner: WrestlerController, method: String) -> void:
		row["winner"] = winner.name
		row["method"] = method
	referee.match_won.connect(won)

	var tick := 0
	var last_state := {a.name: -1, b.name: -1}
	while tick < _budget and row["winner"] == "":
		await get_tree().physics_frame
		tick += 1
		for w: WrestlerController in [a, b]:
			row["peak_momentum"][w.name] = maxf(row["peak_momentum"][w.name], w.combat.momentum)
			var state_name: String = WrestlerFSM.State.keys()[w.fsm.current_state]
			var ticks_in: Dictionary = row["ticks_in"][w.name]
			ticks_in[state_name] = ticks_in.get(state_name, 0) + 1
			if w.fsm.current_state != last_state[w.name]:
				last_state[w.name] = w.fsm.current_state
				var entries: Dictionary = row["entries"][w.name]
				entries[state_name] = entries.get(state_name, 0) + 1
	row["ticks"] = tick
	scene.queue_free()
	await get_tree().process_frame
	return row

## A move's tier is which slot it was drawn from; MoveDef carries no tier
## field (see WrestlerController.is_finisher()).
func _tier_of(w: WrestlerController, move: MoveDef) -> String:
	if move == null:
		return "unknown"
	if move == w.finisher_move or w.finisher_move_pool.has(move):
		return "finisher"
	if move == w.signature_move or w.signature_move_pool.has(move):
		return "signature"
	if move == w.power_move or w.power_move_pool.has(move):
		return "power"
	if move == w.grapple_move or w.grapple_move_pool.has(move):
		return "grapple"
	if move == w.running_attack_move:
		return "running"
	if move == w.strike_move or w.strike_move_pool.has(move):
		return "strike"
	return "unknown"

func _report() -> void:
	print("\n=== momentum ladder probe ===")
	var both := 0
	var sig_seeds := 0
	var fin_seeds := 0
	for row in _rows:
		var line := "seed %d  %5d ticks  %-9s by %-9s  landed %2d" % [
			row["seed"], row["ticks"], row["method"], row["winner"], row["landed"]]
		var sig := 0
		var fin := 0
		for who: String in row["tiers"]:
			var t: Dictionary = row["tiers"][who]
			sig += t["signature"]
			fin += t["finisher"]
			line += "\n    %-9s peak %5.1f  strike %2d running %2d grapple %2d power %2d sig %2d fin %2d" % [
				who, row["peak_momentum"][who], t["strike"], t["running"],
				t["grapple"], t["power"], t["signature"], t["finisher"]]
		if sig > 0:
			sig_seeds += 1
		if fin > 0:
			fin_seeds += 1
		if sig > 0 and fin > 0:
			both += 1
		for who: String in row["earned"]:
			line += "\n    %-9s earned %5.1f  entries %s" % [
				who, row["earned"][who], row["entries"][who]]
		if _verbose:
			for entry: String in row["trace"]:
				line += "\n" + entry
		print(line)
	var grapples := 0
	var downs := 0
	var strikes := 0
	var ordered := 0
	for row in _rows:
		var seed_ordered := true
		for who: String in row["tiers"]:
			var t: Dictionary = row["tiers"][who]
			grapples += t["grapple"] + t["power"] + t["signature"] + t["finisher"]
			strikes += t["strike"]
			downs += row["entries"][who].get("DOWN", 0)
			# A finisher with no signature behind it is a skipped rung.
			if t["finisher"] > 0 and t["signature"] == 0:
				seed_ordered = false
			if t["signature"] > 0 and t["power"] == 0:
				seed_ordered = false
		if seed_ordered:
			ordered += 1
	print("\nseeds: %d   signature fired in %d   finisher fired in %d   both in %d" % [
		_rows.size(), sig_seeds, fin_seeds, both])
	print("chain never skipped a rung in %d of %d seeds" % [ordered, _rows.size()])
	print("per match, mean: grapple moves %.1f   strikes %.1f   knockdowns %.1f" % [
		float(grapples) / _rows.size(), float(strikes) / _rows.size(),
		float(downs) / _rows.size()])
