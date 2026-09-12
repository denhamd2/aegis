extends Node
## Measures the three things that make a match read as two mannequins rather
## than two wrestlers. All three were found on footage (a recorded Roman vs
## Cody match) and none of them had a number attached until this probe.
##
##   TELEPORT  how far a body jumps in ONE tick when a paired move starts.
##             GrappleRig._align_to_pair() snaps both roots into the pair
##             frame, so the two men vanish from where they were standing and
##             reappear at the midpoint. On footage this is a defender who
##             goes from upright to horizontal-in-mid-air between two frames.
##
##   OVERLAP   closest centre-to-centre approach in free movement, against the
##             separation the two capsules actually need. The collision
##             capsule is radius 0.4 (scenes/wrestler.tscn) but the MODELS are
##             much wider at the shoulder, so "not colliding" and "not visibly
##             inside each other" are different thresholds.
##
##   RECOIL    how far a struck wrestler moves during HIT_REACT.
##             _process_timed_state() never touches velocity, so the expected
##             answer is zero: a landed punch moves nobody.
##
## Usage:
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/contact_probe.tscn -- --seeds 1,2,3

const MATCH_SCENE := "res://scenes/match.tscn"

## Below this, a one-tick root move is a teleport rather than locomotion.
## RUN_SPEED is 7.0 m/s = 0.117 m per 60Hz tick, so anything past 0.25 m in a
## single tick cannot have been walked or run.
const TELEPORT_M := 0.25

## How close to capsule-touching still counts as "pressed together".
const PRESSED_MARGIN := 0.05

var _seeds: Array = [1, 2, 3]
var _budget := 20000
var _rows: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seeds" and i + 1 < args.size():
			_seeds = []
			for token: String in args[i + 1].split(","):
				_seeds.append(int(token))
		elif args[i] == "--budget" and i + 1 < args.size():
			_budget = int(args[i + 1])
	for seed_value: int in _seeds:
		await _run(seed_value)
	_report()
	get_tree().quit()


func _run(seed_value: int) -> void:
	var scene: Node = load(MATCH_SCENE).instantiate()
	scene.match_seed = seed_value
	# Deferred: root is still setting up its own children while this runs and
	# refuses a direct add_child (the same trap title_launch.gd documents).
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().physics_frame

	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	# match.tscn ships WrestlerA as the PLAYER slot (is_ai = false), and a
	# player slot nobody is driving just stands there being hit. Without this
	# the probe measures a one-sided beating: the first run of it finished in
	# 764 ticks against ladder_probe's ~1700, with a man who never advanced
	# and therefore never crowded anybody. Every other probe here does the
	# same override -- see ladder_probe.gd and floating_probe.gd.
	for w: WrestlerController in [a, b]:
		w.is_ai = true
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var row := {
		"seed": seed_value, "ticks": 0, "finished": false,
		"teleports": 0, "worst_teleport": 0.0, "teleport_by": {},
		"closest": 99.0, "overlap_ticks": 0, "free_ticks": 0,
		"reacts": 0, "moved_reacts": 0, "worst_recoil": 0.0,
	}
	# Registered before the match runs, not after: the row is filled in place,
	# so a seed that errors out mid-run still reports what it managed to
	# measure instead of vanishing from the report entirely.
	_rows.append(row)
	var over := [false]
	referee.match_won.connect(func(_w, _m): over[0] = true)

	# The threshold that matters is the MESH width, not the capsule. The
	# capsule is radius 0.4 (0.80 m centre-to-centre when touching), but the
	# models are far wider than that at the shoulder, so two men can be fully
	# legal to the physics engine and still visibly inside each other -- which
	# is what the footage shows. Measured off the real meshes rather than
	# assumed, and printed, so the number can be argued with.
	# PRESSED, not "colliding". The capsules cannot overlap -- the physics
	# engine sees to that -- so the interesting question is not whether the
	# rule is broken but whether the two men spend the match jammed against
	# the floor of it. Capsule-touching is 0.80 m centre-to-centre; anything
	# within PRESSED_MARGIN of that is two torsos in contact, with the arms
	# (which the capsule does not model at all) fully inside each other.
	#
	# An earlier version of this measured the models' AABB instead and got
	# 2.117 m, which is ARM SPAN on a wrestler posed with his arms out, not
	# shoulder width -- it flagged 1455 of 1458 ticks and told us nothing.
	var min_sep := _capsule_radius(a) + _capsule_radius(b) + PRESSED_MARGIN
	row["min_sep"] = min_sep

	var last := {a: a.global_position, b: b.global_position}
	var last_state := {a: a.fsm.current_state, b: b.fsm.current_state}
	var react_start := {}
	var tick := 0
	while tick < _budget and not over[0]:
		await get_tree().physics_frame
		tick += 1
		for w: WrestlerController in [a, b]:
			var step: float = (w.global_position - last[w]).length()
			if step > TELEPORT_M:
				row["teleports"] += 1
				row["worst_teleport"] = maxf(row["worst_teleport"], step)
				# WHICH transition jumped. Without this the count says a
				# teleport happened and nothing about where to fix it -- the
				# first pass at the lead-in cut the count but left the worst
				# jump untouched at 1.810 m, because the worst one was never
				# the grapple snap at all.
				var where: String = "%s->%s" % [
					WrestlerFSM.State.keys()[last_state[w]],
					WrestlerFSM.State.keys()[w.fsm.current_state]]
				var by_state: Dictionary = row["teleport_by"]
				var seen: Array = by_state.get(where, [0, 0.0])
				by_state[where] = [seen[0] + 1, maxf(seen[1], step)]
			last[w] = w.global_position
			last_state[w] = w.fsm.current_state
			# Recoil: measure across the whole HIT_REACT, entry to exit.
			var in_react: bool = w.fsm.current_state == WrestlerFSM.State.HIT_REACT
			if in_react and not react_start.has(w):
				react_start[w] = w.global_position
			elif not in_react and react_start.has(w):
				var moved: float = (w.global_position - react_start[w]).length()
				row["reacts"] += 1
				if moved > 0.01:
					row["moved_reacts"] += 1
				row["worst_recoil"] = maxf(row["worst_recoil"], moved)
				react_start.erase(w)
		# Overlap only counts where both men own their own bodies. During a
		# paired move GrappleRig drives both roots to an authored separation,
		# which is a different problem with a different fix.
		if a.is_physics_processing() and b.is_physics_processing():
			row["free_ticks"] += 1
			var gap := Vector2(a.global_position.x - b.global_position.x,
					a.global_position.z - b.global_position.z).length()
			row["closest"] = minf(row["closest"], gap)
			if gap < min_sep:
				row["overlap_ticks"] += 1
	row["ticks"] = tick
	row["finished"] = over[0]
	scene.queue_free()
	await get_tree().process_frame


static func _capsule_radius(body: Node3D) -> float:
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			return (child.shape as CapsuleShape3D).radius
	return 0.4


func _report() -> void:
	print("\n=== contact probe ===")
	print("teleport threshold %.2f m in one tick   capsule-touching 0.80 m" % TELEPORT_M)
	for row: Dictionary in _rows:
		print("seed %-3d %5d ticks finished=%s" % [
				row["seed"], row["ticks"], row["finished"]])
		print("    TELEPORT  %3d one-tick jumps over %.2fm   worst %.3f m" % [
				row["teleports"], TELEPORT_M, row["worst_teleport"]])
		var by_state: Dictionary = row["teleport_by"]
		for where: String in by_state:
			var seen: Array = by_state[where]
			print("                %-34s %3d  worst %.3f m" % [
					where, seen[0], seen[1]])
		print("    PRESSED   closest %.3f m   %d of %d free ticks inside %.3f m" % [
				row["closest"], row["overlap_ticks"], row["free_ticks"],
				row.get("min_sep", 0.0)])
		print("    RECOIL    %d of %d hit reactions moved the man   worst %.3f m" % [
				row["moved_reacts"], row["reacts"], row["worst_recoil"]])
