extends Node
## Measures whether either wrestler ever leaves the mat when he should not.
##
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/floating_probe.tscn -- --seeds 1,2,3 --budget 20000
##
## Every tick it takes each wrestler's LOWEST bone in world space. That number
## is the answer to "is he touching the canvas": a man standing, lying, rolling
## or being thrown all have some part of them at or near y=0, and a man
## floating has none. The maximum of that per-tick minimum, across the match,
## is therefore the deepest the character ever got off the ground.
##
## Written for the retarget bug that put Roman's whole body at y=2.0 through
## every knockdown -- his lowest bone was 2.0 while Cody's was 0.02, and no
## instrument in the repo would have said so. ladder_probe and pin_probe read
## state and signals; the fault was entirely in where the bones were.
##
## The threshold is deliberately generous. A wrestler genuinely leaves the mat
## mid-throw, so a brief excursion is the game working; what this catches is a
## body that sits high for a sustained stretch, or higher than any throw goes.

const MATCH_SCENE := "res://scenes/match.tscn"
## Above this, for a sustained run, nothing about the pose is legitimate --
## the ropes top out at 3.1m and a thrown man's lowest point stays well under
## it. A real throw peaks around 1.0 and passes through in a few ticks.
const FLOAT_LIMIT := 1.20
## A run of this many consecutive ticks above the limit is a float, not a
## throw. 30 ticks is half a second at the 60Hz physics rate.
const SUSTAINED_TICKS := 30

var _seeds: Array[int] = []
var _budget: int = 20000
var _wrestlers: String = ""
var _pair: Array = []
var _rows: Array[Dictionary] = []


func _ready() -> void:
	_parse_args()
	if _pair.is_empty():
		get_tree().quit(1)
		return
	print("WRESTLERS %s vs %s" % [_pair[0].display_name(),
			_pair[1].display_name()])
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
		elif args[i] == "--budget" and i + 1 < args.size():
			_budget = int(args[i + 1])
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_wrestlers = args[i + 1]
	if _seeds.is_empty():
		_seeds = [1, 2, 3]
	_pair = Roster.pair_from_spec(_wrestlers)


func _run_match(seed_value: int) -> Dictionary:
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, _pair[0], _pair[1], seed_value)
	scene.match_seed = seed_value
	add_child(scene)
	var wrestlers := {
		"A": scene.get_node("WrestlerA") as WrestlerController,
		"B": scene.get_node("WrestlerB") as WrestlerController,
	}
	for w: WrestlerController in wrestlers.values():
		w.is_ai = true
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var over := [false]
	referee.match_won.connect(func(_w, _m): over[0] = true)

	var peak := {"A": 0.0, "B": 0.0}
	var peak_state := {"A": "", "B": ""}
	var run := {"A": 0, "B": 0}
	var longest_run := {"A": 0, "B": 0}
	var ticks := 0
	while ticks < _budget and not over[0]:
		await get_tree().physics_frame
		ticks += 1
		for slot: String in wrestlers:
			var w: WrestlerController = wrestlers[slot]
			var low := _lowest_bone_y(w)
			if low > peak[slot]:
				peak[slot] = low
				peak_state[slot] = WrestlerFSM.State.keys()[w.fsm.current_state]
			if low > FLOAT_LIMIT:
				run[slot] += 1
				longest_run[slot] = maxi(longest_run[slot], run[slot])
			else:
				run[slot] = 0
	scene.queue_free()
	await get_tree().process_frame
	return {
		"seed": seed_value, "ticks": ticks, "finished": over[0],
		"peak": peak, "peak_state": peak_state, "longest_run": longest_run,
	}


## The lowest point of any bone on any skeleton the wrestler is rigged on,
## in world space. Bones rather than the mesh AABB deliberately: get_aabb()
## on a skinned mesh returns the REST pose, not the animated one, and reading
## it is how an earlier pass concluded twice that two differently-posed
## wrestlers were the same height.
func _lowest_bone_y(w: WrestlerController) -> float:
	var lowest := INF
	var model := w.anim_player.get_parent() if w.anim_player else null
	var root: Node = model if model else w
	for node in root.find_children("", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		var basis := skeleton.global_transform
		for bone in skeleton.get_bone_count():
			var y: float = (basis * skeleton.get_bone_global_pose(bone)).origin.y
			lowest = minf(lowest, y)
	return 0.0 if lowest == INF else lowest


func _report() -> void:
	print("\n=== floating probe ===")
	print("limit %.2fm   sustained run %d ticks" % [FLOAT_LIMIT,
			SUSTAINED_TICKS])
	var bad := 0
	for row: Dictionary in _rows:
		print("seed %-4d %5d ticks  finished=%s" % [row["seed"], row["ticks"],
				row["finished"]])
		for slot: String in ["A", "B"]:
			var name: String = (_pair[0] if slot == "A" else _pair[1]).display_name()
			var sustained: int = row["longest_run"][slot]
			if sustained >= SUSTAINED_TICKS:
				bad += 1
			print("    %s %-14s highest lowest-bone %.3fm in %s   longest run above limit %d ticks%s"
					% [slot, name, row["peak"][slot], row["peak_state"][slot],
							sustained, "   <-- FLOATING" if sustained >= SUSTAINED_TICKS else ""])
	print("\n%d of %d wrestler-matches float" % [bad, _rows.size() * 2])
