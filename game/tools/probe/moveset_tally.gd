extends Node
## Plays seeded AI-vs-AI matches with the roster pair and tallies every move
## each man starts, by name -- the check that a wrestler's own moveset
## (Roster.Entry.moveset) is actually thrown in a match, not just wired.
##
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/moveset_tally.tscn -- --seeds 1,2,3,4,5,6 --wrestlers roman,cody

const MATCH_SCENE := "res://scenes/match.tscn"

var _seeds: Array[int] = []
var _wrestlers := ""
var _max_ticks := 30000


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seeds" and i + 1 < args.size():
			for t in args[i + 1].split(","):
				_seeds.append(int(t))
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_wrestlers = args[i + 1]
		elif args[i] == "--ticks" and i + 1 < args.size():
			_max_ticks = int(args[i + 1])
	if _seeds.is_empty():
		_seeds = [1, 2, 3]
	var pair := Roster.pair_from_spec(_wrestlers)
	var tally := {}
	for seed_value in _seeds:
		var scene: Node = load(MATCH_SCENE).instantiate()
		TitleScreen.configure_match(scene, pair[0], pair[1], seed_value)
		(scene.get_node("WrestlerA") as WrestlerController).is_ai = true
		add_child(scene)
		var ref: Node = scene.get_node("MatchReferee")
		var done := [false]
		var how := [""]
		ref.match_won.connect(func(_w, m): done[0] = true; how[0] = m)
		var last := {}
		var ticks := 0
		var dived := false
		while not done[0] and ticks < _max_ticks:
			await get_tree().physics_frame
			ticks += 1
			if not dived and scene.has_node("DiveSpot"):
				dived = true
				tally["cody dive spot"] = tally.get("cody dive spot", 0) + 1
				var ending := DiveSpot.ending_of(scene.get_node("WrestlerB")).get_file().get_basename()
				tally["cody dive: " + ending] = tally.get("cody dive: " + ending, 0) + 1
			# The top-rope spots, and why the crossbody did or did not fire on
			# the tick the man started to rise (MatchReferee._check_for_crossbody).
			var spot_node := scene.get_node_or_null("TopRopeSpot") as TopRopeSpot
			if spot_node and not spot_node.has_meta("tallied"):
				spot_node.set_meta("tallied", true)
				var kind := "crossbody" if spot_node._crossbody else "moonsault"
				tally["cody " + kind] = tally.get("cody " + kind, 0) + 1
				print("  seed %d tick %d: cody %s" % [seed_value, ticks, kind])
			var cb_a: WrestlerController = scene.get_node("WrestlerB")
			var cb_d: WrestlerController = scene.get_node("WrestlerA")
			var rising := cb_d.fsm.current_state == WrestlerFSM.State.GETUP
			if rising and not last.get("rising", false) and cb_a.top_rope_standing_move \
					and not cb_a._top_rope_standing_used:
				var why := "ok"
				if not cb_a.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]):
					why = "cody busy: %s" % WrestlerFSM.State.keys()[cb_a.fsm.current_state]
				elif cb_a.outside_ring or cb_d.outside_ring:
					why = "outside"
				elif cb_a.last_landed_tier >= CombatSystem.Tier.FINISHER:
					why = "after finisher"
				elif not TopRopeSpot.can_crossbody(cb_d):
					why = "no corner in reach: %s" % cb_d.global_position.snappedf(0.1)
				var gate := "crossbody gate " + why.split(":")[0]
				tally[gate] = tally.get(gate, 0) + 1
				print("  seed %d tick %d: crossbody gate %s" % [seed_value, ticks, why])
			last["rising"] = rising
			_signature_gates(scene, pair, tally, last, seed_value, ticks)
			for n in ["WrestlerA", "WrestlerB"]:
				var w: WrestlerController = scene.get_node(n)
				var m: MoveDef = w._active_move
				if m == null and w._submission_hold_move:
					m = w._submission_hold_move
				if m != last.get(n) and m != null:
					var key := "%s %s" % [pair[0 if n == "WrestlerA" else 1].id, m.animation_pair_id]
					tally[key] = tally.get(key, 0) + 1
					print("  seed %d tick %d: %s" % [seed_value, ticks, key])
				last[n] = m
				# The staples: whipped, trapped in a corner, set for the Spear.
				var who: String = pair[0 if n == "WrestlerA" else 1].id
				for flag: Array in [["whipped", w.fsm.current_state == WrestlerFSM.State.IRISH_WHIP],
						["corner trapped", w.is_corner_trapped()], ["spear set-up", w._stalking]]:
					var was := "%s %s" % [n, flag[0]]
					if flag[1] and not last.get(was, false):
						tally["%s %s" % [who, flag[0]]] = tally.get("%s %s" % [who, flag[0]], 0) + 1
						print("  seed %d tick %d: %s %s" % [seed_value, ticks, who, flag[0]])
					last[was] = flag[1]
		print("seed %d: %d ticks, done=%s by %s" % [seed_value, ticks, done[0], how[0]])
		scene.queue_free()
		await get_tree().process_frame
	# Seconds, not ticks, for the signature gate's time counts.
	for k in tally.keys():
		if String(k).contains(" sig ready"):
			tally[k] = snappedf(float(tally[k]) / 60.0, 0.1)
	var keys := tally.keys()
	keys.sort()
	for k in keys:
		print("  %-44s %d" % [k, tally[k]])
	get_tree().quit()


## Why a man's signature does or does not come (Step 3 of the movesets plan:
## Cody landed about one in two matches, Roman eight to ten). Per man: the
## seconds his signature rung is affordable, split by what holds it back --
## the man not ripe (WrestlerAI._opponent_is_ripe), the retry wait after one
## lands, or nothing -- and each time he starts wanting the signature tie-up
## and each time one lands. The gap still to close and the weakest
## signature's reach are printed at the first ready tick of each wait.
func _signature_gates(scene: Node, pair: Array, tally: Dictionary, last: Dictionary,
		seed_value: int, ticks: int) -> void:
	for n in ["WrestlerA", "WrestlerB"]:
		var w: WrestlerController = scene.get_node(n)
		if w.ai == null or w.ai.target == null:
			continue
		var who: String = pair[0 if n == "WrestlerA" else 1].id
		var ready := w.combat.can_signature()
		var why := ""
		if ready:
			if not w.ai._opponent_is_ripe():
				why = "not ripe"
			elif w.ai._signature_retry > 0:
				why = "retry wait"
			else:
				why = "free"
			var k := "%s sig ready, %s" % [who, why]
			tally[k] = tally.get(k, 0) + 1
			if not last.get(n + " ready", false):
				var t := w.ai.target
				var gap := WrestlerController.KNOCKDOWN_DAMAGE \
						- (t.combat.wear - t._damage_at_last_knockdown)
				print("  seed %d tick %d: %s sig ready (%s): gap %.1f, weakest %.1f x%.2f" % [
						seed_value, ticks, who, why, gap, w.ai._weakest_signature_damage(),
						t.combat.damage_taken_scale])
		last[n + " ready"] = ready
		var wants := w.ai._wants_signature_tie_up()
		if wants and not last.get(n + " wants", false):
			tally["%s sig tie-up wanted" % who] = tally.get("%s sig tie-up wanted" % who, 0) + 1
		last[n + " wants"] = wants
		var retry: int = w.ai._signature_retry
		if retry > last.get(n + " retry", 0):
			tally["%s sig landed" % who] = tally.get("%s sig landed" % who, 0) + 1
			print("  seed %d tick %d: %s signature landed" % [seed_value, ticks, who])
		last[n + " retry"] = retry
