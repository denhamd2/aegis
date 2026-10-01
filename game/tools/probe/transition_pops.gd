extends Node
## Pose pops at clip switches (gauntlet/refs/animation_gap.md, Phase 3
## "transitions"), over real AI-vs-AI matches.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/transition_pops.tscn \
##       [-- --seeds 1,2 --budget 5400 --wrestlers roman,cody --edges]
##
## Every tick it reads eleven bones AS DRAWN (inside the skeleton's own update,
## modifiers included) in skeleton space, so walking, turning and being
## carried by GrappleRig do not count -- only the pose does. Two numbers per tick:
##
##   move   the furthest any of them travelled this tick, m/tick
##   kick   the largest change in that travel from the last tick -- a change of
##          velocity. A fast punch moves a hand 10 cm a tick and has no kick; a
##          pose that jumps has a kick as big as the jump. This is the pop.
##
## A switch is any tick the wrestler's clip changes (a new FSM state, or a new
## clip in the same state, as a paired move starts). The worst kick in the
## WINDOW ticks after it is charged to that edge, "FROM>TO". --edges lists
## them all; the summary gives the share of switches that pop past POP.

const MATCH_SCENE := "res://scenes/match.tscn"
const WINDOW := 10
const POP := 0.05
const BONES := ["pelvis", "Head", "hand_l", "hand_r", "lowerarm_l", "lowerarm_r",
		"foot_l", "foot_r", "calf_l", "calf_r", "spine_03"]

var _seeds: Array[int] = []
var _budget := 5400
var _pair: Array = []
var _edges := false
var _debug := false
## --debug-min M: the kick past which --debug prints a bone.
var _debug_min := 0.5
## --world: bones in world orientation less the body's position, so the way
## he faces counts too -- what a viewer sees, turns included.
var _world := false


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
			"--edges": _edges = true
			"--debug": _debug = true
			"--debug-min": _debug_min = float(args[i + 1])
			"--world": _world = true
	if _seeds.is_empty():
		_seeds = [1, 2]
	_pair = Roster.pair_from_spec(spec)
	if _pair.is_empty():
		get_tree().quit(1)
		return
	var edges := {}
	var steady: Array = []
	var ticks := 0
	for s in _seeds:
		ticks += await _run(s, edges, steady)
	var switches := 0
	var popped := 0
	var worst := 0.0
	var worst_edge := ""
	var keys := edges.keys()
	keys.sort_custom(func(a, b): return edges[a]["worst"] > edges[b]["worst"])
	for k: String in keys:
		var e: Dictionary = edges[k]
		switches += int(e["n"])
		popped += int(e["pops"])
		if float(e["worst"]) > worst:
			worst = e["worst"]
			worst_edge = k
		if _edges:
			print("EDGE %-44s n %4d  pops %3d  worst kick %.3f  mean %.3f"
					% [k, e["n"], e["pops"], e["worst"], float(e["sum"]) / maxf(1.0, e["n"])])
	steady.sort()
	var p99: float = steady[int(steady.size() * 0.99)] if not steady.is_empty() else 0.0
	print("POPS %d ticks, %d switches: %d kick past %.2f m (%.1f%%), worst %.3f (%s); steady p99 kick %.3f"
			% [ticks, switches, popped, POP, 100.0 * popped / maxf(1.0, switches), worst, worst_edge, p99])
	get_tree().quit()


func _run(seed_value: int, edges: Dictionary, steady: Array) -> int:
	var scene: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	TitleScreen.configure_match(scene, _pair[0], _pair[1], seed_value)
	scene.match_seed = seed_value
	add_child(scene)
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var over := [false]
	referee.match_won.connect(func(_w, _m): over[0] = true)
	var ws: Array[WrestlerController] = [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	var drawn := [{}, {}]
	var hooks := []
	for i in 2:
		var w := ws[i]
		w.is_ai = true
		var sk := w.skeleton
		var ids := {}
		for b: String in BONES:
			var id := sk.find_bone(w._skeleton_bone_name(b))
			if id >= 0:
				ids[b] = id
		var slot: Dictionary = drawn[i]
		var cb := func() -> void:
			for b: String in ids:
				var o := sk.get_bone_global_pose(ids[b]).origin
				slot[b] = sk.global_transform.basis * o if _world else o
		sk.skeleton_updated.connect(cb)
		hooks.append([sk, cb])
	var prev := [{}, {}]
	var vel := [{}, {}]
	var last_key := ["", ""]
	var last_state := ["", ""]
	var since := [999, 999]
	var edge := ["", ""]
	var window_worst := [0.0, 0.0]
	var tick := 0
	while tick < _budget and not over[0]:
		await get_tree().physics_frame
		await get_tree().process_frame
		tick += 1
		for i in 2:
			var w := ws[i]
			var state: String = WrestlerFSM.State.keys()[w.fsm.current_state]
			var key := "%s|%s" % [state, _clip(w)]
			if key != last_key[i]:
				if last_key[i] != "":
					_close(edges, edge[i], window_worst[i], since[i])
					edge[i] = "%s>%s" % [last_state[i], state] if state != last_state[i] \
							else "%s (new clip)" % state
					since[i] = 0
					window_worst[i] = 0.0
				last_key[i] = key
				last_state[i] = state
			var kick := 0.0
			var cur: Dictionary = drawn[i]
			for b: String in cur:
				var p: Vector3 = cur[b]
				if prev[i].has(b):
					var v: Vector3 = p - prev[i][b]
					if vel[i].has(b):
						var kk := (v - (vel[i][b] as Vector3)).length()
						kick = maxf(kick, kk)
						if _debug and kk > _debug_min:
							print("DBG t%d w%d %s %s kick %.2f p %s prev %s since %d w %.2f" % [tick, i, state, b, kk, p, prev[i][b], since[i],
									1.0 if w.inertializer and w.inertializer.is_blending() else 0.0])
					vel[i][b] = v
				prev[i][b] = p
			if since[i] < WINDOW:
				window_worst[i] = maxf(window_worst[i], kick)
			else:
				if since[i] == WINDOW:
					_close(edges, edge[i], window_worst[i], since[i])
				steady.append(kick)
			since[i] += 1
	for h: Array in hooks:
		h[0].skeleton_updated.disconnect(h[1])
	scene.queue_free()
	await get_tree().process_frame
	return tick


func _close(edges: Dictionary, name: String, worst: float, since: int) -> void:
	if name == "" or since > WINDOW:
		return
	var e: Dictionary = edges.get(name, {"n": 0, "pops": 0, "worst": 0.0, "sum": 0.0})
	e["n"] += 1
	e["sum"] += worst
	e["worst"] = maxf(e["worst"], worst)
	if worst > POP:
		e["pops"] += 1
	edges[name] = e


static func _clip(w: WrestlerController) -> String:
	var playback := w._anim_playback
	if playback == null:
		return ""
	var node := (w.anim_tree.tree_root as AnimationNodeStateMachine).get_node(playback.get_current_node())
	return String((node as AnimationNodeAnimation).animation) if node is AnimationNodeAnimation else ""

