extends Node
## Measures how far a downed man's legs pass INTO the other wrestler.
##
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/limb_clearance.tscn -- --seeds 1,2,3,4,5 --wrestlers roman,cody
##
## Written for the owner's match video: at 40 s and 60 s the man on his back,
## knees up, had his shins inside the standing man's thigh and chest. Nothing
## in the repo could see it. A downed man is still an upright 0.4 m capsule at
## his pelvis, so his legs (out to +0.5 m) collide with nothing, and
## contact_probe and move_qa's "merge" both measure at the capsule or at bone
## ORIGINS -- neither has a notion of a shin as a volume.
##
## So this models the bodies the way the eye reads them: each limb a capsule
## around its bone segment. Every tick one man is down (DOWN, PIN_DEFENDER,
## SUBMISSION_DEFENDER, GETUP) and the other is not, it takes the downed man's
## four leg segments against the other man's torso, neck/head, thighs and
## shins, and records the deepest overlap. Radii are the rendered limb
## thicknesses, a little under, so a graze does not count.
##
## PIN_ATTACKER is reported separately: a lateral press lies ON the man by
## design, and its contact is with his chest, not his legs -- so leg overlap
## there is still a defect, but it is a different one.

const MATCH_SCENE := "res://scenes/match.tscn"
## Deeper than this reads as one body through another on a frame.
const VISIBLE_M := 0.04

const DOWN_STATES := [
	WrestlerFSM.State.DOWN, WrestlerFSM.State.PIN_DEFENDER,
	WrestlerFSM.State.SUBMISSION_DEFENDER, WrestlerFSM.State.GETUP,
]
## Victim leg segments and their radius.
const LEGS := [["thigh_l", "calf_l"], ["calf_l", "foot_l"],
		["thigh_r", "calf_r"], ["calf_r", "foot_r"]]
const LEG_R := 0.065
## The other man's body, [from, to, radius].
const BODY := [
	["pelvis", "spine_03", 0.15], ["spine_03", "Head", 0.10],
	["thigh_l", "calf_l", 0.075], ["thigh_r", "calf_r", 0.075],
	["calf_l", "foot_l", 0.055], ["calf_r", "foot_r", 0.055],
]

var _seeds: Array[int] = []
var _budget := 20000
var _wrestlers := ""
var _pair: Array = []
var _verbose := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seeds" and i + 1 < args.size():
			for token in args[i + 1].split(","):
				_seeds.append(int(token))
		elif args[i] == "--budget" and i + 1 < args.size():
			_budget = int(args[i + 1])
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_wrestlers = args[i + 1]
		elif args[i] == "--verbose":
			_verbose = true
	if _seeds.is_empty():
		_seeds = [1, 2, 3]
	_pair = Roster.pair_from_spec(_wrestlers)
	if _pair.is_empty():
		get_tree().quit(1)
		return
	print("WRESTLERS %s vs %s" % [_pair[0].display_name(), _pair[1].display_name()])
	var worst_all := 0.0
	var visible_all := 0
	for seed_value in _seeds:
		var row: Dictionary = await _run(seed_value)
		worst_all = maxf(worst_all, row["worst"])
		visible_all += row["visible"]
		print("seed %-3d %5d ticks  down-ticks %5d  worst overlap %.3f m (%s, %s)  ticks > %.2f: %d  (in cover: worst %.3f)"
				% [seed_value, row["ticks"], row["down"], row["worst"],
				row["worst_state"], row["worst_part"], VISIBLE_M, row["visible"],
				row["cover_worst"]])
	print("LIMB_CLEARANCE worst %.3f m, visible ticks %d" % [worst_all, visible_all])
	get_tree().quit()


func _run(seed_value: int) -> Dictionary:
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, _pair[0], _pair[1], seed_value)
	scene.match_seed = seed_value
	add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.is_ai = true
	b.is_ai = true
	var over := [false]
	(scene.get_node("MatchReferee") as MatchReferee).match_won.connect(
			func(_w, _m): over[0] = true)
	var out := {"ticks": 0, "down": 0, "worst": 0.0, "worst_state": "-",
			"worst_part": "-", "visible": 0, "cover_worst": 0.0}
	while out["ticks"] < _budget and not over[0]:
		await get_tree().physics_frame
		out["ticks"] += 1
		for pair in [[a, b], [b, a]]:
			var victim: WrestlerController = pair[0]
			var other: WrestlerController = pair[1]
			if not DOWN_STATES.has(victim.fsm.current_state):
				continue
			if DOWN_STATES.has(other.fsm.current_state):
				continue
			out["down"] += 1
			var hit := _deepest(victim, other)
			var depth: float = hit[0]
			if other.fsm.current_state == WrestlerFSM.State.PIN_ATTACKER:
				out["cover_worst"] = maxf(out["cover_worst"], depth)
				continue
			if depth > VISIBLE_M:
				out["visible"] += 1
				if _verbose:
					print("  t%d %s(%s) at %s over %s(%s) at %s yaw %.0f: %.3f %s" % [
							out["ticks"], other.name,
							WrestlerFSM.State.keys()[other.fsm.current_state],
							other.global_position.snapped(Vector3.ONE * 0.01),
							victim.name,
							WrestlerFSM.State.keys()[victim.fsm.current_state],
							victim.global_position.snapped(Vector3.ONE * 0.01),
							victim.rotation_degrees.y, depth, hit[1]])
			if depth > out["worst"]:
				out["worst"] = depth
				out["worst_state"] = WrestlerFSM.State.keys()[other.fsm.current_state]
				out["worst_part"] = hit[1]
	scene.queue_free()
	await get_tree().process_frame
	return out


func _bone(w: WrestlerController, name: String) -> Vector3:
	var i := w.skeleton.find_bone(w._skeleton_bone_name(name))
	if i < 0:
		return Vector3.INF
	return (w.skeleton.global_transform * w.skeleton.get_bone_global_pose(i)).origin


## [depth, "victim_leg vs other_part"] of the deepest overlap this tick.
func _deepest(victim: WrestlerController, other: WrestlerController) -> Array:
	var best := [0.0, "-"]
	for leg: Array in LEGS:
		var p1 := _bone(victim, leg[0])
		var p2 := _bone(victim, leg[1])
		if p1 == Vector3.INF or p2 == Vector3.INF:
			continue
		for part: Array in BODY:
			var q1 := _bone(other, part[0])
			var q2 := _bone(other, part[1])
			if q1 == Vector3.INF or q2 == Vector3.INF:
				continue
			var c := Geometry3D.get_closest_points_between_segments(p1, p2, q1, q2)
			var depth: float = (LEG_R + float(part[2])) - c[0].distance_to(c[1])
			if depth > best[0]:
				best = [depth, "%s-%s vs %s-%s" % [leg[0], leg[1], part[0], part[1]]]
	return best
