extends Node
## Feet sliding on the canvas over real AI matches (gauntlet/refs/
## animation_gap.md, Phase 3 "foot IK").
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/foot_skate.tscn \
##       [-- --seeds 1,2 --budget 5400 --wrestlers roman,cody]
##
## Each tick it reads both ankles AS DRAWN (inside the skeleton's own update,
## every modifier included) in world space. A foot is ON THE MAT when its
## ankle is within ON_MAT of its standing height (the rest pose's, above the
## body's origin, which stands on the canvas). A foot on the mat on two ticks running that moved
## sideways between them skated: the canvas slid under the boot. Charged to
## the state he was in, and summed per second of standing time.

const ON_MAT := 0.04
## Below this per tick is noise, not a slide the eye catches.
const NOISE := 0.004

var _seeds: Array[int] = []
var _budget := 5400
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
		_seeds = [1, 2]
	_pair = Roster.pair_from_spec(spec)
	var by_state := {}
	for s in _seeds:
		await _run(s, by_state)
	var total := 0.0
	var planted := 0
	var keys := by_state.keys()
	keys.sort_custom(func(a, b): return by_state[a]["slide"] > by_state[b]["slide"])
	for k: String in keys:
		var e: Dictionary = by_state[k]
		total += e["slide"]
		planted += e["ticks"]
		print("SKATE %-22s %7.2f m over %5d planted foot-ticks  (%.1f cm/s)  worst %.3f m/tick"
				% [k, e["slide"], e["ticks"], 100.0 * e["slide"] / maxf(1.0, e["ticks"] / 60.0), e["worst"]])
	print("SKATE_DONE %.2f m over %d planted foot-ticks: %.1f cm per planted second"
			% [total, planted, 100.0 * total / maxf(1.0, planted / 60.0)])
	get_tree().quit()


func _run(seed_value: int, by_state: Dictionary) -> void:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(scene, _pair[0], _pair[1], seed_value)
	scene.match_seed = seed_value
	add_child(scene)
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var over := [false]
	referee.match_won.connect(func(_w, _m): over[0] = true)
	var ws: Array[WrestlerController] = [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	var drawn := []
	var hooks := []
	for i in 2:
		var w := ws[i]
		w.is_ai = true
		var sk := w.skeleton
		var ids := [sk.find_bone(w._skeleton_bone_name("foot_l")), sk.find_bone(w._skeleton_bone_name("foot_r"))]
		var slot := [Vector3.ZERO, Vector3.ZERO]
		drawn.append(slot)
		var cb := func() -> void:
			for side in 2:
				slot[side] = sk.global_transform * sk.get_bone_global_pose(ids[side]).origin
		sk.skeleton_updated.connect(cb)
		hooks.append([sk, cb])
	await get_tree().physics_frame
	var standing := []
	for w in ws:
		var sk := w.skeleton
		standing.append((sk.global_transform * sk.get_bone_global_rest(
				sk.find_bone(w._skeleton_bone_name("foot_l"))).origin).y - w.global_position.y)
	var prev := [[null, null], [null, null]]
	var tick := 0
	while tick < _budget and not over[0]:
		await get_tree().physics_frame
		await get_tree().process_frame
		tick += 1
		for i in 2:
			var state: String = WrestlerFSM.State.keys()[ws[i].fsm.current_state]
			for side in 2:
				var p: Vector3 = drawn[i][side]
				var on := p.y - ws[i].global_position.y < float(standing[i]) + ON_MAT
				var q = prev[i][side]
				if on and q != null:
					var e: Dictionary = by_state.get(state, {"slide": 0.0, "ticks": 0, "worst": 0.0})
					var d := Vector2(p.x - q.x, p.z - q.z).length()
					e["ticks"] += 1
					if d > NOISE:
						e["slide"] += d
						e["worst"] = maxf(e["worst"], d)
					by_state[state] = e
				prev[i][side] = p if on else null
	for h: Array in hooks:
		h[0].skeleton_updated.disconnect(h[1])
	scene.queue_free()
	await get_tree().process_frame
