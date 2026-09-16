extends Node
## How many thrown strikes actually connect, and how far away the misses were.
##
## "The punches do not connect and the man being hit just stands there" is a
## claim about a rate, and nothing here measured that rate. The reaction
## machinery is not the suspect -- a landed strike calls _play_hit_reaction()
## and puts the defender in HIT_REACT -- so a defender standing still means the
## strike never landed at all, and the question is how often and why.
##
## Two ways a strike fails, and they need different fixes, so they are counted
## separately:
##   out of range -- thrown in range (the AI gates on STRIKE_HIT_RANGE) but
##                   contact is tested at the move's active frame, ~8 ticks
##                   later, by which time either man may have moved;
##   unhittable   -- the opponent was DOWN/GETUP/pinning/etc, where
##                   UNHITTABLE_STATES suppresses the hit by design.
##
## Run headless:
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/strike_connect_probe.tscn -- --seeds 1,2,3 --budget 20000

const MATCH_SCENE := "res://scenes/match.tscn"

var _seeds: Array[int] = [1, 2, 3]
var _budget := 20000
var _rows: Array[Dictionary] = []
## Seeds that produced no usable measurement. A run with any of these is not a
## result, and the probe exits non-zero rather than printing an average over
## whatever did work.
var _void := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seeds" and i + 1 < args.size():
			_seeds.clear()
			for token: String in args[i + 1].split(","):
				_seeds.append(int(token))
		elif args[i] == "--budget" and i + 1 < args.size():
			_budget = int(args[i + 1])
	for seed_value in _seeds:
		await _run(seed_value)
	_report()
	get_tree().quit(1 if _void > 0 else 0)


func _run(seed_value: int) -> void:
	var scene: Node = load(MATCH_SCENE).instantiate()
	scene.match_seed = seed_value
	# DEFERRED, and then waited on. `_ready()` is still on the stack the first
	# time round -- this whole function is an await continuation of it -- and
	# the scene root will not accept a child while it is setting its own up. A
	# direct add_child() therefore failed on the FIRST seed of every run and
	# only that one, printing "Parent node is busy setting up children" into a
	# log nobody reads and then measuring a match that was never in the tree.
	#
	# It reported as `seed 1 thrown 0 landed 0 (0%)`, which reads like a
	# catastrophic connect rate and is in fact no match at all. Seeds 1 and 5
	# both "failed" that way across two separate runs; both were simply first
	# in their list.
	get_tree().root.add_child.call_deferred(scene)
	while not scene.is_inside_tree():
		await get_tree().process_frame
	await get_tree().process_frame
	var wrestlers: Array[WrestlerController] = [
		scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	for w in wrestlers:
		w.is_ai = true

	# A one-element Array, not a bool, and that is the whole point. GDScript
	# lambdas capture locals BY VALUE, so `func(): over = true` assigns to the
	# lambda's own copy and the outer `over` stays false forever. This probe
	# carried that bug from the day it was written: `if over: break` never
	# fired, every match ran the full 20 000-tick budget whatever happened in
	# it, and the probe could not tell a finish from a stall. An Array is a
	# reference, so writing through it is visible out here.
	var over := [false]
	scene.get_node("MatchReferee").match_won.connect(
			func(_w: WrestlerController, _m: String): over[0] = true)

	var thrown := 0
	var landed := 0
	var out_of_range := 0
	var unhittable := 0
	var miss_distances: Array[float] = []
	var was_striking := {}
	var live := {}
	# Sampled DURING the strike, not at its end. The first version of this
	# probe read the distance and the opponent's state on the tick the strike
	# finished, and that is a different fact: a man who was DOWN while the
	# punch passed through him is on his feet again a few ticks later, so
	# every such miss was being filed as "out of range" at a distance that was
	# well inside reach. It made the numbers look like a spacing problem.
	var min_gap := {}
	var unhittable_ever := {}
	var reached_active := {}
	var interrupted := 0
	# Contact-tick geometry, for splitting misses by cause. See where these
	# are written for why the closest approach could not do this job.
	var contact_gap := {}
	var contact_reach := {}
	var contact_angle := {}
	var miss_gaps: Array[float] = []
	var miss_angles: Array[float] = []
	var missed_short := 0
	var missed_wide := 0
	for w in wrestlers:
		was_striking[w] = false
		live[w] = false
		min_gap[w] = 1e9
		unhittable_ever[w] = false
		reached_active[w] = false
		w.move_landed.connect(func(a: WrestlerController, _d, _m): live[a] = true)

	for tick in _budget:
		await get_tree().physics_frame
		if not is_instance_valid(scene):
			break
		for w in wrestlers:
			if w.fsm == null or w.opponent == null:
				continue
			var striking: bool = w.fsm.current_state == WrestlerFSM.State.STRIKE
			if striking and not was_striking[w]:
				live[w] = false          # a new strike, nothing landed yet
				min_gap[w] = 1e9
				unhittable_ever[w] = false
				reached_active[w] = false
			if striking:
				var other_now: WrestlerController = w.opponent
				min_gap[w] = minf(min_gap[w],
						w.global_position.distance_to(other_now.global_position))
				if WrestlerController.UNHITTABLE_STATES.has(other_now.fsm.current_state):
					unhittable_ever[w] = true
				# Did the punch ever reach the frames where contact is tested?
				# A strike interrupted by taking a hit never gets there, and
				# that is a fight rather than a defect -- but it is counted
				# separately so the two are not confused.
				if w._active_move != null:
					var off: int = w._active_move.total_frames() - w._move_ticks_remaining
					if off >= w._active_move.startup_frames:
						reached_active[w] = true
					# Geometry on the CONTACT tick itself, which is the only
					# tick that can explain a miss. min_gap above is the
					# CLOSEST the two got at any point during the strike, so a
					# miss filed at 0.80 m never meant the fist was 0.80 m from
					# a man it failed to hit -- reading it that way sent one
					# investigation down the wrong path entirely.
					#
					# Two numbers, because a directional contact test can miss
					# two different ways: too far, or off to the side. The gap
					# is against this move's own measured reach, and the angle
					# is how far off the attacker's facing the opponent sat.
					if off == w._active_move.startup_frames:
						var to_them: Vector3 = w.opponent.global_position - w.global_position
						to_them.y = 0.0
						contact_gap[w] = to_them.length()
						contact_reach[w] = WrestlerController.strike_reach(w._active_move)
						contact_angle[w] = rad_to_deg(
								(-w.global_transform.basis.z).angle_to(to_them.normalized()))
			elif was_striking[w]:
				# The strike just ended: score it on what was true DURING it.
				thrown += 1
				if live[w]:
					landed += 1
				elif not reached_active[w]:
					interrupted += 1
				elif unhittable_ever[w]:
					unhittable += 1
				else:
					# Split the misses by what actually caused them, from the
					# contact tick rather than from the closest approach.
					out_of_range += 1
					miss_distances.append(min_gap[w])
					var gap: float = contact_gap.get(w, -1.0)
					var reach: float = contact_reach.get(w, 0.0)
					var angle: float = contact_angle.get(w, 0.0)
					if gap >= 0.0:
						miss_gaps.append(gap - reach)
						miss_angles.append(angle)
						if gap > reach:
							missed_short += 1
						else:
							missed_wide += 1
			was_striking[w] = striking
		if over[0]:
			break

	if thrown == 0:
		_void += 1
	_rows.append({
		"finished": over[0],
		"short": missed_short, "wide": missed_wide,
		"gaps": miss_gaps, "angles": miss_angles,
		"seed": seed_value, "thrown": thrown, "landed": landed,
		"out_of_range": out_of_range, "unhittable": unhittable,
		"interrupted": interrupted,
		"misses": miss_distances,
	})
	scene.queue_free()
	await get_tree().process_frame


func _report() -> void:
	print("\n=== strike connect probe ===")
	print("hit range %.2f m" % WrestlerController.STRIKE_HIT_RANGE)
	var t := 0
	var l := 0
	var o := 0
	var u := 0
	var it := 0
	var unfinished := 0
	var all: Array[float] = []
	for row in _rows:
		if not row["finished"]:
			unfinished += 1
		t += row["thrown"]
		l += row["landed"]
		o += row["out_of_range"]
		u += row["unhittable"]
		it += row["interrupted"]
		all.append_array(row["misses"])
		if row["thrown"] == 0:
			# NOT "0%". A seed that threw nothing measured nothing, and the two
			# print identically under a percentage. This probe reported
			# `thrown 0 landed 0 (0%)` for a match that never entered the tree
			# and it was read as a catastrophic connect rate for two rounds.
			print("seed %-3d NO DATA -- no strike was thrown at all. The match "
				% row["seed"]
				+ "did not run, or ended before either man could throw.")
			continue
		print("seed %-3d thrown %-4d landed %-4d (%.0f%%)  out-of-range %-3d  unhittable %-3d  interrupted %-3d  %s"
			% [row["seed"], row["thrown"], row["landed"],
				100.0 * row["landed"] / maxf(1.0, row["thrown"]),
				row["out_of_range"], row["unhittable"], row["interrupted"],
				"" if row["finished"] else "<-- NEVER FINISHED"])
	print("TOTAL   thrown %-4d landed %-4d (%.1f%%)  out-of-range %-3d  unhittable %-3d  interrupted %-3d"
		% [t, l, 100.0 * l / maxf(1.0, t), o, u, it])
	if _void > 0:
		print("!! %d of %d seeds produced NO DATA. The total above is an average "
			% [_void, _rows.size()]
			+ "over the rest of them, not over the seeds you asked for.")
	if unfinished > 0:
		print("!! %d of %d matches never reached a finish inside the budget."
			% [unfinished, _rows.size()])
	if all.is_empty():
		return
	all.sort()
	var sum := 0.0
	for d in all:
		sum += d
	print("closest approach during a missed strike: min %.2f m  median %.2f m  max %.2f m"
		% [all[0], all[all.size() / 2], all[all.size() - 1]])
	print("  (that is the CLOSEST the two got, not the gap when contact was tested)")

	# The number that actually explains a miss.
	var short_total := 0
	var wide_total := 0
	var gaps: Array[float] = []
	var angles: Array[float] = []
	for row in _rows:
		short_total += row["short"]
		wide_total += row["wide"]
		gaps.append_array(row["gaps"])
		angles.append_array(row["angles"])
	if gaps.is_empty():
		return
	gaps.sort()
	angles.sort()
	print("misses by cause, measured ON the contact tick:")
	print("  out of reach  %-4d   off to the side %-4d" % [short_total, wide_total])
	print("  gap beyond this move\'s own reach: median %+.2f m  worst %+.2f m"
		% [gaps[gaps.size() / 2], gaps[gaps.size() - 1]])
	print("  angle off the attacker\'s facing: median %.0f deg  worst %.0f deg"
		% [angles[angles.size() / 2], angles[angles.size() - 1]])
