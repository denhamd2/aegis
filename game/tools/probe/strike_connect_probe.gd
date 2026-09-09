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
	get_tree().quit()


func _run(seed_value: int) -> void:
	var scene: Node = load(MATCH_SCENE).instantiate()
	scene.match_seed = seed_value
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	var wrestlers: Array[WrestlerController] = [
		scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	for w in wrestlers:
		w.is_ai = true

	var over := false
	scene.get_node("MatchReferee").match_won.connect(
			func(_w: WrestlerController, _m: String): over = true)

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
			elif was_striking[w]:
				# The strike just ended: score it on what was true DURING it.
				thrown += 1
				if live[w]:
					landed += 1
				elif min_gap[w] > WrestlerController.STRIKE_HIT_RANGE:
					out_of_range += 1
					miss_distances.append(min_gap[w])
				elif not reached_active[w]:
					interrupted += 1
				elif unhittable_ever[w]:
					unhittable += 1
				else:
					out_of_range += 1
					miss_distances.append(min_gap[w])
			was_striking[w] = striking
		if over:
			break

	_rows.append({
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
	var all: Array[float] = []
	for row in _rows:
		t += row["thrown"]
		l += row["landed"]
		o += row["out_of_range"]
		u += row["unhittable"]
		it += row["interrupted"]
		all.append_array(row["misses"])
		print("seed %-3d thrown %-4d landed %-4d (%.0f%%)  out-of-range %-3d  unhittable %-3d  interrupted %-3d"
			% [row["seed"], row["thrown"], row["landed"],
				100.0 * row["landed"] / maxf(1.0, row["thrown"]),
				row["out_of_range"], row["unhittable"], row["interrupted"]])
	print("TOTAL   thrown %-4d landed %-4d (%.1f%%)  out-of-range %-3d  unhittable %-3d  interrupted %-3d"
		% [t, l, 100.0 * l / maxf(1.0, t), o, u, it])
	if all.is_empty():
		return
	all.sort()
	var sum := 0.0
	for d in all:
		sum += d
	print("out-of-range misses: min %.2f m  median %.2f m  max %.2f m  mean %.2f m"
		% [all[0], all[all.size() / 2], all[all.size() - 1], sum / all.size()])
