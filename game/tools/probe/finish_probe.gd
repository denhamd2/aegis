extends Node
## Measures the state of both wrestlers at the moment a match is won, and for
## a while after it.
##
## The recorded match ends with the winner horizontal in MID-AIR at rope
## height, frozen there for the last 2.5 seconds. Nothing already in the
## harness can see that: the suite has no opinion about where a body is when
## the bell goes, contact_probe's teleport test is a per-tick delta that a
## frozen body never trips, and floating_probe flags a body whose LOWEST bone
## clears 1.20 m -- which a horizontal man at rope height, arms and legs
## splayed, passes comfortably.
##
## So this reports the two things a frame shows and no existing number does:
## is each wrestler UPRIGHT (basis.y near +Y) and is he ON THE MAT (origin.y
## near 0), at the declaration and for AFTER_TICKS past it. It also reports
## whether GrappleRig was mid-move when the bell went, which is the suspected
## cause -- the rig writes global_transform directly, including the throw's
## rotation and elevation, and nothing tells it the match is over.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --fixed-fps 6000 tools/probe/finish_probe.tscn -- --seeds 1,2,3

const MATCH_SCENE := "res://scenes/match.tscn"

## Ticks to keep watching after the winner is declared. 60 is a second, which
## is well past the freeze and covers the whole VICTORY blend.
const AFTER_TICKS := 60

## How far basis.y may tilt off vertical before a body counts as pitched over.
## cos(20 deg) = 0.94: a wrestler leaning into a stance is inside it, a man
## lying down is nowhere near.
const UPRIGHT_DOT := 0.94

## How high the body origin may sit before it counts as off the mat. The mat
## is y=0 and a standing body's origin is at its feet.
const ON_MAT_M := 0.12

## How upright the SPINE must be for the man to read as standing. A wrestler
## bent into a cover is around 0.5; a man lying flat is near 0. 0.35 sits
## below every authored standing and kneeling pose and well above lying.
const SPINE_UPRIGHT_DOT := 0.35

## States in which a flat spine is the CORRECT answer, so the check above
## must not fire. A pinned man is supposed to be on his back; flagging him
## buries the one finish that is genuinely wrong among three that are fine,
## which is what the first version of this probe did.
const LYING_STATES := [
	WrestlerFSM.State.DOWN,
	WrestlerFSM.State.PIN_DEFENDER,
	WrestlerFSM.State.SUBMISSION_DEFENDER,
]

## Highest the head may sit above the body origin. A standing man is ~1.7 m.
## Anything past 2.0 means the mesh has left its own body.
const HEAD_MAX_M := 2.0

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
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().physics_frame

	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	# match.tscn ships WrestlerA as the player slot; without this the probe
	# measures a one-sided beating. Every other probe does the same.
	for w: WrestlerController in [a, b]:
		w.is_ai = true
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var rig: Node = scene.get_node_or_null("GrappleRig")

	var row := {
		"seed": seed_value, "finished": false, "winner": "",
		"rig_active_at_bell": false,
		"worst_tilt": {}, "worst_height": {}, "final": {},
		"worst_spine": {}, "worst_head": {},
	}
	_rows.append(row)

	var won := [false, -1]
	referee.match_won.connect(func(w: WrestlerController, _m: String) -> void:
		won[0] = true
		row["winner"] = w.name
		row["rig_active_at_bell"] = bool(rig.get("_active")) if rig else false)

	var tick := 0
	var after := -1
	while tick < _budget:
		await get_tree().physics_frame
		tick += 1
		if won[0]:
			if after < 0:
				after = 0
			else:
				after += 1
			for w: WrestlerController in [a, b]:
				_sample(row, w)
			if after >= AFTER_TICKS:
				row["finished"] = true
				for w: WrestlerController in [a, b]:
					row["final"][w.name] = {
						"upright": _upright(w), "y": w.global_position.y,
						"state": w.fsm.current_state,
					}
				break
	scene.queue_free()
	await get_tree().process_frame


## Records the worst tilt and height this wrestler reaches after the bell.
func _sample(row: Dictionary, w: WrestlerController) -> void:
	var up := _upright(w)
	if not row["worst_tilt"].has(w.name) or up < row["worst_tilt"][w.name]:
		row["worst_tilt"][w.name] = up
	var y := w.global_position.y
	if not row["worst_height"].has(w.name) or y > row["worst_height"][w.name]:
		row["worst_height"][w.name] = y
	var spine := _spine_upright(w)
	if not row["worst_spine"].has(w.name) or spine < row["worst_spine"][w.name]:
		row["worst_spine"][w.name] = spine
	var head := _head_offset(w)
	if not row["worst_head"].has(w.name) or head > row["worst_head"][w.name]:
		row["worst_head"][w.name] = head


## Dot of the body's own up axis with world up. 1.0 is perfectly upright.
func _upright(w: WrestlerController) -> float:
	return w.global_transform.basis.y.normalized().dot(Vector3.UP)


## Where the HEAD actually is, in world space.
##
## The body being upright and on the mat says nothing about where the man is
## DRAWN: the skeleton is posed inside the body, and every authored clip
## carries a pelvis position track, so the mesh can sit metres from its own
## origin while the CharacterBody3D reports y=0 and perfectly vertical. That
## is the gap this probe existed to close and missed on its first pass --
## it measured the body, which was never the thing on screen.
##
## Head height off the body origin: ~1.7 m for a standing man, ~0.3 m for one
## lying down. A head at 1.7 m with the body at y=0 is a man standing on the
## mat; a head at 1.7 m with a HORIZONTAL spine is the defect.
func _head_offset(w: WrestlerController) -> float:
	var skel: Skeleton3D = w.find_child("Skeleton3D", true, false)
	if not skel:
		return -1.0
	var bone := skel.find_bone("Head")
	if bone < 0:
		return -1.0
	var head := skel.global_transform * skel.get_bone_global_pose(bone).origin
	return head.y - w.global_position.y


## How upright the SPINE is, as opposed to the body capsule: the dot of the
## pelvis-to-head vector with world up. A standing man is ~1.0, a man lying
## flat is ~0.
func _spine_upright(w: WrestlerController) -> float:
	var skel: Skeleton3D = w.find_child("Skeleton3D", true, false)
	if not skel:
		return 1.0
	var head_bone := skel.find_bone("Head")
	var hip_bone := skel.find_bone("pelvis")
	if head_bone < 0 or hip_bone < 0:
		return 1.0
	var head := skel.global_transform * skel.get_bone_global_pose(head_bone).origin
	var hip := skel.global_transform * skel.get_bone_global_pose(hip_bone).origin
	var spine := head - hip
	if spine.length() < 0.001:
		return 1.0
	return spine.normalized().dot(Vector3.UP)


func _report() -> void:
	print("")
	print("=== finish probe ===")
	print("upright when basis.y . UP >= %.2f    on the mat when origin.y <= %.2f m"
			% [UPRIGHT_DOT, ON_MAT_M])
	var bad := 0
	for row: Dictionary in _rows:
		print("seed %-3d  winner=%-10s  finished=%s  rig_active_at_bell=%s"
				% [row["seed"], row["winner"], row["finished"],
				row["rig_active_at_bell"]])
		for name: String in row["final"]:
			var f: Dictionary = row["final"][name]
			var tilt: float = row["worst_tilt"].get(name, 1.0)
			var high: float = row["worst_height"].get(name, 0.0)
			var spine: float = row["worst_spine"].get(name, 1.0)
			var head: float = row["worst_head"].get(name, 0.0)
			var flags := PackedStringArray()
			if tilt < UPRIGHT_DOT:
				flags.append("BODY-PITCHED")
			if high > ON_MAT_M:
				flags.append("BODY-OFF-MAT")
			# The two that catch what a frame shows -- but only where the
			# man is meant to be on his feet.
			var lying: bool = LYING_STATES.has(f["state"])
			if not lying and spine < SPINE_UPRIGHT_DOT:
				flags.append("SPINE-FLAT")
			if head > HEAD_MAX_M:
				flags.append("HEAD-HIGH")
			if not flags.is_empty():
				bad += 1
			print("    %-10s body up %.3f y %.3f | spine up %.3f head %.2f m | state=%d %s"
					% [name, tilt, high, spine, head, f["state"], " ".join(flags)])
	print("")
	print("%d of %d wrestler-finishes are pitched over or off the mat"
			% [bad, _rows.size() * 2])
