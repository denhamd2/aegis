extends Node
## Instruments AI-vs-AI matches and reports whether the live match actually
## *reaches* the things the grapple chain is made of, and leaves them
## cleanly. Run headless:
##
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/reachability_probe.tscn -- --seeds 1,2,3 --budget 20000
##
## A wrapper scene rather than a `-s` script, for the same reason
## ladder_probe.gd is one: a -s SceneTree script does not register the
## project's class_name globals, so every script with a typed
## WrestlerController field fails to compile there (see README).
##
## This is the measurement behind Priority 2 of
## gauntlet/status/roman_reigns_next.md. Where ladder_probe.gd asks "which
## rungs of the momentum ladder fire", this asks the four reachability
## questions that gate them:
##
##   1. Does tie-up entry happen on neutral footing, or does one wrestler
##      win it by scene-tree order? Measured as the TieUpMinigame progress
##      pair at every resolution. The historical bug's signature was a
##      progress pair of exactly (9.0, 10.0) at every single resolution --
##      the loser permanently one tick behind (see
##      WrestlerController._wants_tie_up_this_tick's doc comment).
##   2. Does the AI reach tie-up range, or stall throwing strikes it cannot
##      land? Measured as the distance at every STRIKE entry, split on
##      WrestlerController.STRIKE_HIT_RANGE -- a strike thrown beyond that
##      is a guaranteed whiff that also freezes the approach, since
##      _start_move() zeroes velocity and the STRIKE branch never processes
##      movement.
##   3. Does grapple selection resolve through the controller path? Counted
##      from move_landed, which only WrestlerController._resolve_grapple_move()
##      emits.
##   4. Do both wrestlers leave a paired move cleanly? Measured as each
##      side's FSM state on the tick after every move_landed, plus the
##      longest unbroken run either spends in a state that should be
##      transient.
##
## Everything here is read-only observation: the probe connects to signals
## and samples state, and never drives an input or a transition.

const MATCH_SCENE := "res://scenes/match.tscn"

## States a wrestler should pass through, never settle in. A run longer than
## this many ticks in any of them means something is stranded -- these are
## the states with (or historically without) a bounded exit.
const TRANSIENT_STATES := ["TIE_UP", "GRAPPLE_HOLD", "MOVE_EXEC", "IRISH_WHIP"]
## How many ticks after a move_landed to sample both wrestlers' states.
##
## Deliberately 1, not a generous grace period. _resolve_grapple_move()
## resolves the whole handoff synchronously inside one _physics_process --
## attacker to IDLE, defender to DOWN or HIT_REACT -- so the very next tick
## is when it is either right or wrong. A longer window measures the wrong
## thing: tie-ups follow each other closely enough that by +40 ticks the
## *next* grapple is legitimately under way, and a probe that called that
## "stranded" reported 10 strandings that were all the next move starting.
const HANDOFF_SAMPLE_TICKS := 1
## States that mean a wrestler did *not* leave the paired move, checked on
## the tick after it lands.
##
## Stated as a deny-list rather than an allow-list, because the set of
## legitimate next states is wide and grows: the attacker resolves to IDLE
## but the AI can spend that same tick opening a strike, walking in for a
## cover, or being pulled into the next tie-up, and the defender can be in
## HIT_REACT, DOWN, or already a pin/submission participant. An allow-list
## reported all of those as strandings. What actually indicates a failed
## handoff is narrow: still holding the grapple, or still in MOVE_EXEC --
## which for a rig-driven move is never supposed to survive a single tick.
const STRANDED_AFTER_HANDOFF := ["GRAPPLE_HOLD", "MOVE_EXEC"]

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
	# each with its own deterministic mash jitter. Without this WrestlerA is
	# a passive human slot that never presses grapple, and every tie-up
	# resolves 0-10 -- which measures the scene wiring, not the loop.
	for w: WrestlerController in [a, b]:
		w.is_ai = true
		if w.ai:
			w.ai.setup_jitter(seed_value, w.player_index)

	var row := {
		"seed": seed_value,
		"ticks": 0,
		"winner": "",
		"method": "none",
		# 1. tie-up
		"tie_ups": 0,
		"tie_up_wins": {a.name: 0, b.name: 0},
		"tie_up_progress": [],
		"tie_up_backstops": 0,
		# 2. approach
		"strikes": 0,
		"strike_whiffs": 0,
		"strike_distances": [],
		"ticks_to_first_tie_up": -1,
		# 3. selection
		"landed": 0,
		# 4. handoff
		"handoff_states": [],
		"handoff_stranded": 0,
		"longest_transient": {},
		"trace": [],
	}
	for who: String in [a.name, b.name]:
		row["longest_transient"][who] = {}

	var landed_ticks: Array[int] = []
	var landed := func(attacker: WrestlerController, _defender: WrestlerController, move: MoveDef) -> void:
		row["landed"] += 1
		landed_ticks.append(row["ticks"])
		if _verbose:
			row["trace"].append("      t%-6d %-9s landed %s" % [
				row["ticks"], attacker.name,
				move.resource_path.get_file().get_basename() if move else "<null>"])
	a.move_landed.connect(landed)
	b.move_landed.connect(landed)
	var won := func(winner: WrestlerController, method: String) -> void:
		row["winner"] = winner.name
		row["method"] = method
	referee.match_won.connect(won)

	var tick := 0
	var last_state := {a.name: -1, b.name: -1}
	var run_length := {a.name: 0, b.name: 0}
	# Tie-up resolution is observed rather than signalled: the referee has no
	# "tie-up resolved" signal, so watch _tying_up fall and read the
	# minigame's final progress pair on that same tick.
	var was_tying_up := false
	var pending_handoffs: Array[int] = []

	while tick < _budget and row["winner"] == "":
		await get_tree().physics_frame
		tick += 1
		row["ticks"] = tick

		# --- 1. tie-up entry and resolution ---------------------------------
		if referee._tying_up and not was_tying_up:
			row["tie_ups"] += 1
			if row["ticks_to_first_tie_up"] < 0:
				row["ticks_to_first_tie_up"] = tick
		if was_tying_up and not referee._tying_up and referee._tie_up_minigame:
			var mg: TieUpMinigame = referee._tie_up_minigame
			row["tie_up_progress"].append([mg.a_progress, mg.b_progress])
			if mg.a_wins() == mg.b_wins():
				# Neither crossed the threshold, or both did on the same
				# tick: resolved by the TIE_UP_MAX_TICKS backstop or the
				# seeded coin flip, not by winning the mash outright.
				row["tie_up_backstops"] += 1
			if a._is_grapple_attacker:
				row["tie_up_wins"][a.name] += 1
			elif b._is_grapple_attacker:
				row["tie_up_wins"][b.name] += 1
		was_tying_up = referee._tying_up

		# --- 2. approach quality --------------------------------------------
		# Sampled on the tick a wrestler *enters* STRIKE, which is the tick
		# the hit test will later be run against.
		for pair in [[a, b], [b, a]]:
			var w: WrestlerController = pair[0]
			var other: WrestlerController = pair[1]
			if w.fsm.current_state == WrestlerFSM.State.STRIKE \
					and last_state[w.name] != WrestlerFSM.State.STRIKE:
				var d := w.global_position.distance_to(other.global_position)
				row["strikes"] += 1
				row["strike_distances"].append(d)
				if d > WrestlerController.STRIKE_HIT_RANGE:
					row["strike_whiffs"] += 1

		# --- 4. handoff and transient dwell ---------------------------------
		for w: WrestlerController in [a, b]:
			var state_name: String = WrestlerFSM.State.keys()[w.fsm.current_state]
			if w.fsm.current_state == last_state[w.name]:
				run_length[w.name] += 1
			else:
				run_length[w.name] = 1
			if state_name in TRANSIENT_STATES:
				var longest: Dictionary = row["longest_transient"][w.name]
				longest[state_name] = maxi(longest.get(state_name, 0), run_length[w.name])
			last_state[w.name] = w.fsm.current_state

		var still_pending: Array[int] = []
		for landed_tick: int in pending_handoffs:
			if tick - landed_tick < HANDOFF_SAMPLE_TICKS:
				still_pending.append(landed_tick)
				continue
			var states: Array[String] = []
			var stranded := false
			for w: WrestlerController in [a, b]:
				var name_of: String = WrestlerFSM.State.keys()[w.fsm.current_state]
				states.append(name_of)
				if STRANDED_AFTER_HANDOFF.has(name_of):
					stranded = true
			row["handoff_states"].append("+".join(states))
			if stranded:
				row["handoff_stranded"] += 1
		pending_handoffs = still_pending
		# Appended after the sweep so a move that landed *this* tick is
		# sampled on the next one, not this one.
		while not landed_ticks.is_empty():
			pending_handoffs.append(landed_ticks.pop_front())

	scene.queue_free()
	await get_tree().process_frame
	return row

func _report() -> void:
	print("\n=== reachability probe ===")
	print("STRIKE_HIT_RANGE %.2fm   TIE_UP_RANGE %.2fm   threshold %.0f presses" % [
		WrestlerController.STRIKE_HIT_RANGE, WrestlerController.TIE_UP_RANGE,
		TieUpMinigame.PROGRESS_THRESHOLD])

	var tie_ups := 0
	var backstops := 0
	var strikes := 0
	var whiffs := 0
	var landed := 0
	var stranded := 0
	var wins_by_slot := {}
	var degenerate := 0
	var progress_pairs := 0

	for row in _rows:
		var line := "\nseed %d  %5d ticks  %-9s by %-9s" % [
			row["seed"], row["ticks"], row["method"], row["winner"]]
		line += "\n    tie-ups %2d (backstop %d)   first at tick %d   grapple moves landed %2d" % [
			row["tie_ups"], row["tie_up_backstops"],
			row["ticks_to_first_tie_up"], row["landed"]]
		var wins := ""
		for who: String in row["tie_up_wins"]:
			wins += "%s %d  " % [who, row["tie_up_wins"][who]]
			wins_by_slot[who] = wins_by_slot.get(who, 0) + row["tie_up_wins"][who]
		line += "\n    tie-up wins: %s" % wins
		var pairs := ""
		var distinct := {}
		for pair: Array in row["tie_up_progress"]:
			pairs += "(%.0f,%.0f) " % [pair[0], pair[1]]
			distinct["%.0f,%.0f" % [pair[0], pair[1]]] = true
			progress_pairs += 1
			# The historical scene-order bug: loser exactly one tick behind,
			# every single time.
			if absf(pair[0] - pair[1]) == 1.0:
				degenerate += 1
		line += "\n    tie-up progress at resolution: %s" % (pairs if pairs != "" else "(none)")
		# A match where every tie-up resolves to the identical progress pair
		# is not a contest -- the per-match mash jitter decided all of them
		# at setup. Entry is still neutral (that is the fixed bug); this is
		# the *outcome* being constant, which is a different finding.
		if distinct.size() == 1 and row["tie_up_progress"].size() > 1:
			row["tie_up_constant"] = true
			line += "  <- identical every time"
		else:
			row["tie_up_constant"] = false
		var mean_d := 0.0
		for d: float in row["strike_distances"]:
			mean_d += d
		if not row["strike_distances"].is_empty():
			mean_d /= row["strike_distances"].size()
		line += "\n    strikes %2d   whiffs (beyond hit range) %2d   mean distance %.2fm" % [
			row["strikes"], row["strike_whiffs"], mean_d]
		var handoff_tally := {}
		for pair_name: String in row["handoff_states"]:
			handoff_tally[pair_name] = handoff_tally.get(pair_name, 0) + 1
		line += "\n    handoffs checked %d   stranded %d   states on the next tick: %s" % [
			row["handoff_states"].size(), row["handoff_stranded"], handoff_tally]
		for who: String in row["longest_transient"]:
			line += "\n    %-9s longest run in a transient state: %s" % [
				who, row["longest_transient"][who]]
		if _verbose:
			for entry: String in row["trace"]:
				line += "\n" + entry
		print(line)

		tie_ups += row["tie_ups"]
		backstops += row["tie_up_backstops"]
		strikes += row["strikes"]
		whiffs += row["strike_whiffs"]
		landed += row["landed"]
		stranded += row["handoff_stranded"]

	var n := _rows.size()
	print("\n--- summary over %d seeds ---" % n)
	print("1. tie-up entry   %d tie-ups, %d resolved by backstop/coin-flip" % [
		tie_ups, backstops])
	var slots := ""
	for who: String in wins_by_slot:
		slots += "%s %d   " % [who, wins_by_slot[who]]
	print("   wins by slot:  %s" % slots)
	print("   one-tick-apart resolutions: %d of %d %s" % [
		degenerate, progress_pairs,
		"<- the scene-order bug's signature" if degenerate == progress_pairs \
			and progress_pairs > 0 else "(not the scene-order signature)"])
	var constant_seeds := 0
	var swept := 0
	for row in _rows:
		if row.get("tie_up_constant", false):
			constant_seeds += 1
		var winners := 0
		for who: String in row["tie_up_wins"]:
			if row["tie_up_wins"][who] > 0:
				winners += 1
		if winners == 1 and row["tie_ups"] > 1:
			swept += 1
	print("   seeds where one wrestler won every tie-up: %d of %d" % [swept, n])
	print("   seeds where every tie-up resolved to the identical pair: %d of %d" % [
		constant_seeds, n])
	print("2. AI closing     %d strikes, %d beyond STRIKE_HIT_RANGE (%.0f%% whiff)" % [
		strikes, whiffs, 100.0 * whiffs / maxi(strikes, 1)])
	print("3. selection      %d grapple moves landed, all via move_landed" % landed)
	print("   (only WrestlerController._resolve_grapple_move() emits it)")
	print("4. handoff        %d stranded after a paired move" % stranded)
	print("\nper match, mean: tie-ups %.1f   grapple moves %.1f   strikes %.1f" % [
		float(tie_ups) / n, float(landed) / n, float(strikes) / n])
