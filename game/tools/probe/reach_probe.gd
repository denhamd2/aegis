extends Node
## Priority-2 reachability probe for the Roman match loop. Run headless:
##
##   godot --headless --path game --fixed-fps 6000 \
##       tools/probe/reach_probe.tscn -- --seeds 1,2,3 --budget 20000
##
## A wrapper scene rather than a `-s` script: a -s SceneTree script does not
## register the project's class_name globals, so every script with a typed
## WrestlerController field fails to compile there (see README).
##
## Checks, one per Priority-2 board item in gauntlet/status/roman_reigns_next.md:
##   1. tie-up entry is atomic and gated: detected off the REFEREE's own
##      flags (_tying_up rising with _tie_up_ticks == 0), then asserting the
##      referee's actual inputs -- somebody pressed grapple (the wants flags
##      the referee read are still set at sample time), the distance the
##      referee measured is within TIE_UP_RANGE, and BOTH wrestlers landed in
##      TIE_UP together (no one-sided scene-order entry). Previous-tick
##      states are reported as context only: a wrestler's own physics runs
##      before the referee each tick, so STRIKE->IDLE mid-tick completions
##      read as "from STRIKE" after the fact while the referee legally saw
##      IDLE.
##   2. the AI closes to tie-up range and seeks the tie-up (first tie-up
##      arrives quickly, not after a marathon of nothing).
##   3. every grapple resolves through the normal controller path
##      (_process_grapple_hold -> GrappleRig.begin -> _on_grapple_finished ->
##      _resolve_grapple_move), observed via move_landed with a real tier.
##      (Static half: GrappleRig.begin()'s only gameplay callers are the
##      controller and the reversal counter -- grep to re-prove.)
##   4. after each grapple the attacker is somewhere legal by the next tick
##      (IDLE straight after _resolve_grapple_move, or PIN/SUBMISSION_
##      ATTACKER if the referee covered instantly -- both happen the same
##      tick the grapple resolves) and the defender likewise.
##
## NOTE on lambdas below: GDScript captures locals BY VALUE, so counters live
## in a Dictionary (shared reference); plain ints/bools assigned inside a
## callback would never be seen outside it.

const MATCH_SCENE := "res://scenes/roman_match.tscn"

const ATTACKER_OK := [WrestlerFSM.State.IDLE,
	WrestlerFSM.State.PIN_ATTACKER, WrestlerFSM.State.SUBMISSION_ATTACKER]
const DEFENDER_OK := [WrestlerFSM.State.HIT_REACT, WrestlerFSM.State.DOWN,
	WrestlerFSM.State.PIN_DEFENDER, WrestlerFSM.State.SUBMISSION_DEFENDER,
	WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]

var _seeds: Array[int] = []
var _budget: int = 20000

func _ready() -> void:
	_parse_args()
	var all_ok := true
	for seed_value in _seeds:
		all_ok = await _run_match(seed_value) and all_ok
	print("REACH PROBE: %s" % ("PASS" if all_ok else "FAIL"))
	get_tree().quit()

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seeds" and i + 1 < args.size():
			for token in args[i + 1].split(","):
				_seeds.append(int(token))
		elif args[i] == "--budget" and i + 1 < args.size():
			_budget = int(args[i + 1])
	if _seeds.is_empty():
		_seeds = [1, 2, 3]

func _run_match(seed_value: int) -> bool:
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

	var stats := {"ok": true, "tick": 0, "first_tie_up": -1, "tie_ups": 0,
		"ghost": 0, "range": 0, "split": 0, "grapples": 0,
		"bad_handoffs": 0, "won": false, "wins": {}}
	var pending_handoff := {}
	var was_tying := false
	var last_state := {a.name: a.fsm.current_state, b.name: b.fsm.current_state}
	referee.match_won.connect(
		func(_w: WrestlerController, _m: String) -> void: stats["won"] = true)
	var landed := func(attacker: WrestlerController, _def: WrestlerController,
			move: MoveDef) -> void:
		if attacker.tier_of(move) < 0:
			return # strike/running attack, not the grapple path
		stats["grapples"] += 1
		pending_handoff[attacker.name] = true
	a.move_landed.connect(landed)
	b.move_landed.connect(landed)

	while stats["tick"] < _budget and not stats["won"]:
		await get_tree().physics_frame
		stats["tick"] += 1
		# Entry this tick: the referee's own flags rising.
		if referee._tying_up and not was_tying:
			stats["tie_ups"] += 1
			if stats["first_tie_up"] < 0:
				stats["first_tie_up"] = stats["tick"]
			if not (a._wants_tie_up_this_tick or b._wants_tie_up_this_tick):
				stats["ghost"] += 1
				print("  seed %d t%d GHOST entry: nobody pressed grapple" % [
					seed_value, stats["tick"]])
			var dist: float = a.global_position.distance_to(b.global_position)
			if dist > WrestlerController.TIE_UP_RANGE:
				stats["range"] += 1
				print("  seed %d t%d RANGE entry: distance %.2f" % [
					seed_value, stats["tick"], dist])
			for w: WrestlerController in [a, b]:
				if w.fsm.current_state != WrestlerFSM.State.TIE_UP:
					stats["split"] += 1
					print("  seed %d t%d SPLIT entry: %s in %s" % [seed_value,
						stats["tick"], w.name,
						WrestlerFSM.State.keys()[w.fsm.current_state]])
			print("  seed %d t%d tie-up #%d (prev %s/%s, dist %.2f)" % [seed_value,
				stats["tick"], stats["tie_ups"],
				WrestlerFSM.State.keys()[last_state[a.name]],
				WrestlerFSM.State.keys()[last_state[b.name]], dist])
		# Resolution: referee leaves _tying_up; the winner flag says who.
		if was_tying and not referee._tying_up:
			var winner := a if a._is_grapple_attacker else b
			stats["wins"][winner.name] = stats["wins"].get(winner.name, 0) + 1
		was_tying = referee._tying_up
		# Handoff, one tick after a grapple landed.
		for attacker_name in pending_handoff.keys():
			var w: WrestlerController = a if attacker_name == a.name else b
			var other: WrestlerController = b if w == a else a
			if not w.fsm.is_in(ATTACKER_OK):
				stats["bad_handoffs"] += 1
				print("  seed %d t%d BAD handoff: attacker %s in %s" % [
					seed_value, stats["tick"], attacker_name,
					WrestlerFSM.State.keys()[w.fsm.current_state]])
			elif not other.fsm.is_in(DEFENDER_OK):
				stats["bad_handoffs"] += 1
				print("  seed %d t%d BAD handoff: defender %s in %s" % [
					seed_value, stats["tick"], other.name,
					WrestlerFSM.State.keys()[other.fsm.current_state]])
		pending_handoff.clear()
		for w: WrestlerController in [a, b]:
			last_state[w.name] = w.fsm.current_state

	print("seed %d: ticks %d  first tie-up t%s  tie-ups %d  ghost %d  range %d  split %d  grapples %d  bad handoffs %d  wins %s  won %s" % [
		seed_value, stats["tick"],
		str(stats["first_tie_up"]) if stats["first_tie_up"] >= 0 else "--",
		stats["tie_ups"], stats["ghost"], stats["range"], stats["split"],
		stats["grapples"], stats["bad_handoffs"], str(stats["wins"]),
		str(stats["won"])])
	var ok := true
	if stats["first_tie_up"] < 0 or stats["first_tie_up"] > 3000:
		print("  seed %d FAIL: AI never closed to a tie-up (or took >3000 ticks)" % seed_value)
		ok = false
	for key in ["ghost", "range", "split", "bad_handoffs"]:
		if stats[key] > 0:
			ok = false
	if stats["tie_ups"] > 0 and stats["grapples"] == 0:
		print("  seed %d FAIL: tie-ups never resolved through the grapple path" % seed_value)
		ok = false
	scene.queue_free()
	await get_tree().process_frame
	return ok
