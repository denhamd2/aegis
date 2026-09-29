extends Node
## Phase 4 over seeded AI matches (gauntlet/refs/animation_gap.md): strikes
## thrown, strikes read and countered, whether the counter landed, ground
## attacks by kind, chain-wrestling holds and reversals of them, corner traps
## and the blows taken there, rope breaks, the
## stamina each man ended on, and how the match ended.
##
##   godot4 --headless --path game --fixed-fps 6000 tools/probe/reversal_tally.tscn \
##       [-- --seeds 1,2,3,4 --budget 20000 --wrestlers roman,cody]

var _seeds: Array[int] = []
var _budget := 20000
var _pair: Array = []


func _ready() -> void:
	var spec := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--seeds":
				for t in args[i + 1].split(","):
					_seeds.append(int(t))
			"--budget": _budget = int(args[i + 1])
			"--wrestlers": spec = args[i + 1]
	if _seeds.is_empty():
		_seeds = [1, 2, 3, 4]
	_pair = Roster.pair_from_spec(spec)
	var totals := {"strikes": 0, "read": 0, "countered": 0}
	for s in _seeds:
		var r := await _run(s)
		for k in totals:
			totals[k] += r[k]
		print("REV seed %-3d %5d ticks  strikes %3d  free to read %3d  read %2d  counter landed %2d  stamina A %.2f B %.2f  %s"
				% [s, r["ticks"], r["strikes"], r["chances"], r["read"], r["countered"], r["stam_a"], r["stam_b"], r["end"]])
		print("    ground attacks: ", r["ground"])
		print("    chain holds: ", r["chain"], "  reversed: ", r["chain_rev"])
		print("    corner traps %d, hits in the corner %d, rope breaks %d (pins %d)"
				% [r["traps"], r["corner_hits"], r["rope_breaks"], r["rope_pins"]])
	print("REV_DONE strikes %d, read %d (%.0f%%), counters landed %d"
			% [totals["strikes"], totals["read"], 100.0 * totals["read"] / maxf(1.0, totals["strikes"]), totals["countered"]])
	get_tree().quit()


func _run(seed_value: int) -> Dictionary:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(scene, _pair[0], _pair[1], seed_value)
	scene.match_seed = seed_value
	add_child(scene)
	var ws: Array[WrestlerController] = [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	var r := {"ticks": 0, "strikes": 0, "read": 0, "countered": 0, "end": "no finish", "ground": {},
			"traps": 0, "corner_hits": 0, "chain": {}, "chain_rev": 0, "rope_breaks": 0, "rope_pins": 0}
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var over := [false]
	referee.match_won.connect(func(w, m): over[0] = true; r["end"] = "%s by %s" % [w.name, m])
	referee.rope_break.connect(func(_d, was_pin: bool):
		r["rope_breaks"] += 1
		if was_pin:
			r["rope_pins"] += 1)
	for w in ws:
		w.is_ai = true
		w.reversed.connect(func(_rev, _st, _m): r["read"] += 1)
		w.chain_reversed.connect(func(_a, _b): r["chain_rev"] += 1)
		w.move_landed.connect(func(_a, _d, m: MoveDef):
			if m == WrestlerController.REVERSAL_MOVE:
				r["countered"] += 1
			elif String(m.resource_path).get_file().begins_with("chain_"):
				var k := String(m.resource_path).get_file().get_basename().trim_prefix("chain_")
				r["chain"][k] = int(r["chain"].get(k, 0)) + 1
			elif String(m.resource_path).get_file().begins_with("ground_"):
				var k := String(m.resource_path).get_file().get_basename()
				r["ground"][k] = int(r["ground"].get(k, 0)) + 1)
	var was := [false, false]
	var trapped := [false, false]
	var corner_hits_seen := [0, 0]
	while r["ticks"] < _budget and not over[0]:
		await get_tree().physics_frame
		r["ticks"] += 1
		for i in 2:
			var striking := ws[i].fsm.current_state == WrestlerFSM.State.STRIKE \
					and ws[i]._active_move != WrestlerController.REVERSAL_MOVE
			if striking and not was[i]:
				r["strikes"] += 1
			was[i] = striking
			var t: bool = ws[i].is_corner_trapped()
			if t and not trapped[i]:
				r["traps"] += 1
				corner_hits_seen[i] = 0
			if t and ws[i]._corner_hits > corner_hits_seen[i]:
				r["corner_hits"] += ws[i]._corner_hits - corner_hits_seen[i]
				corner_hits_seen[i] = ws[i]._corner_hits
			trapped[i] = t
	r["chances"] = ws[0].ai._reversal_rolls + ws[1].ai._reversal_rolls
	r["stam_a"] = ws[0].combat.stamina
	r["stam_b"] = ws[1].combat.stamina
	scene.queue_free()
	await get_tree().process_frame
	return r
