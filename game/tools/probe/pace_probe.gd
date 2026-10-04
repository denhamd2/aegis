extends Node
## How long a match lasts and what shape it has. AI against AI, headless.
##
##   godot4 --headless --path game --fixed-fps 6000 tools/probe/pace_probe.tscn \
##       -- --seeds 1,2,3 [--budget 40000] [--wrestlers roman,cody|mannequin]
##
## `mannequin` (the default) fights the box men match.tscn spawns: their sim is
## several times cheaper than the roster's skinned models, so the economy can
## be tuned in minutes. Confirm a number on the real pair (`--wrestlers
## roman,cody`) before believing it.
##
## One line per seed: seconds of match, knockdowns, near-falls, rope breaks,
## moves landed, who won and how, then the totals.

const MATCH_SCENE := "res://scenes/match.tscn"

var _seeds: Array[int] = [1, 2, 3]
var _budget := 40000
var _wrestlers := "mannequin"
var _trace := false
var _rows: Array[Dictionary] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--seeds":
				_seeds.clear()
				for token in args[i + 1].split(","):
					_seeds.append(int(token))
			"--budget": _budget = int(args[i + 1])
			"--wrestlers": _wrestlers = args[i + 1]
			"--trace": _trace = true
	for seed_value in _seeds:
		_rows.append(await _run(seed_value))
		_print_row(_rows[-1])
	_summary()
	get_tree().quit()


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
	var row := {"seed": seed_value, "ticks": 0, "winner": "", "method": "none",
			"landed": 0, "knockdowns": 0, "finishers": 0, "comebacks": 0,
			"whips": 0, "phase_marks": {}}
	for w: WrestlerController in [a, b]:
		w.fsm.state_changed.connect(func(_from: int, to: int) -> void:
			if to == WrestlerFSM.State.IRISH_WHIP:
				row["whips"] += 1)
	var clock := [0]
	var landed := func(attacker: WrestlerController, defender: WrestlerController, move: MoveDef) -> void:
		row["landed"] += 1
		var big: bool = move == attacker.finisher_move or attacker.finisher_move_pool.has(move) \
				or move == attacker.signature_move or attacker.signature_move_pool.has(move)
		if move == attacker.finisher_move or attacker.finisher_move_pool.has(move):
			row["finishers"] += 1
		if _trace and big:
			print("  t=%6.1f %s lands %s on %s (wear %.0f, mom %.0f, phase %s)" % [
					clock[0] / 60.0, attacker.name, move.resource_path.get_file().get_basename(),
					defender.name, defender.combat.wear, attacker.combat.momentum,
					String(MatchFlow.phase_at(clock[0] / 60.0)["name"])])
	a.move_landed.connect(landed)
	b.move_landed.connect(landed)
	a.fired_up.connect(func(_w) -> void: row["comebacks"] += 1)
	b.fired_up.connect(func(_w) -> void: row["comebacks"] += 1)
	var knocked := func(w) -> void:
		row["knockdowns"] += 1
		if _trace:
			print("  t=%6.1f %s knocked down (wear %.0f)" % [clock[0] / 60.0, w.name, w.combat.wear])
	a.knocked_down.connect(knocked)
	b.knocked_down.connect(knocked)
	referee.match_won.connect(func(winner: WrestlerController, method: String) -> void:
		row["winner"] = winner.name
		row["method"] = method)
	var tick := 0
	while tick < _budget and row["winner"] == "":
		await get_tree().physics_frame
		tick += 1
		clock[0] = tick
		if tick % 3000 == 0:
			print("  seed %d tick %d (%.0f s of match) wear %.0f/%.0f %s" % [seed_value, tick,
					tick / 60.0, a.combat.wear, b.combat.wear,
					String(MatchFlow.phase_at(tick / 60.0)["name"])])
	row["ticks"] = tick
	row["near_falls"] = referee.near_falls
	row["rope_breaks"] = referee.rope_breaks
	row["drags"] = referee.drags
	scene.queue_free()
	await get_tree().process_frame
	return row


func _print_row(row: Dictionary) -> void:
	print("seed %d  %6.1f s  down %2d  near-falls %d  rope-breaks %d  landed %3d  finishers %d  comebacks %d  drag-ticks %d  whips %d  %s by %s" % [
			row["seed"], float(row["ticks"]) / 60.0, row["knockdowns"], row["near_falls"],
			row["rope_breaks"], row["landed"], row["finishers"], row["comebacks"],
			row.get("drags", 0), row["whips"], row["method"], row["winner"]])


func _summary() -> void:
	var secs := 0.0
	var nf := 0
	for row in _rows:
		secs += float(row["ticks"]) / 60.0
		nf += int(row["near_falls"])
	print("PACE mean %.1f s over %d seeds, %.1f near-falls a match" % [
			secs / maxf(_rows.size(), 1.0), _rows.size(), float(nf) / maxf(_rows.size(), 1.0)])
