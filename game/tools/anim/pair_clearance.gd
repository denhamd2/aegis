class_name PairClearance
extends RefCounted
## How far one wrestler's body goes into the other's during a paired move
## (gauntlet/refs/animation_gap.md, Phase 1). Nothing stops it at runtime --
## physics is suspended through a paired move and each body is one upright
## capsule anyway -- so this measures it, the way the eye reads it: capsules
## round the torso, neck and head, arms and legs.
##
## Two budgets:
##   BODY_LIMIT -- torso, head or leg of one man inside torso, head or leg of
##                 the other. Nothing in a move needs that; it reads as one
##                 body through another.
##   ARM_LIMIT  -- an arm inside the other man. A grip wraps an arm round a
##                 body, so a few centimetres is contact, not a defect.

const BODY_LIMIT := 0.05
const ARM_LIMIT := 0.08

## [from, to, radius, kind]
const SEGMENTS := [
	["pelvis", "spine_03", 0.13, "body"],
	["spine_03", "Head", 0.085, "body"],
	["thigh_l", "calf_l", 0.065, "body"],
	["thigh_r", "calf_r", 0.065, "body"],
	["calf_l", "foot_l", 0.045, "body"],
	["calf_r", "foot_r", 0.045, "body"],
	["upperarm_l", "lowerarm_l", 0.045, "arm"],
	["upperarm_r", "lowerarm_r", 0.045, "arm"],
	["lowerarm_l", "hand_l", 0.035, "arm"],
	["lowerarm_r", "hand_r", 0.035, "arm"],
]


## Every MoveDef that has an authored two-man performance.
static func paired_move_ids() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("res://resources/moves")
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var move := load("res://resources/moves/" + file) as MoveDef
		if move and PairedRecipes.RECIPES.has(move.animation_pair_id):
			out.append(file.get_basename())
	out.sort()
	return out


static func _points(w: WrestlerController) -> Dictionary:
	var sk := w.skeleton
	var out := {}
	for seg in SEGMENTS:
		for bone: String in [seg[0], seg[1]]:
			if out.has(bone):
				continue
			var i := sk.find_bone(w._skeleton_bone_name(bone))
			if i >= 0:
				out[bone] = sk.global_transform * sk.get_bone_global_pose(i).origin
	return out


## Closest distance between segments p1-q1 and p2-q2.
static func segment_distance(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var pts := Geometry3D.get_closest_points_between_segments(p1, q1, p2, q2)
	return pts[0].distance_to(pts[1])


## Deepest overlap between the two bodies right now:
## {"body": m, "arm": m, "where": "a_seg x b_seg"}.
static func depth(a: WrestlerController, b: WrestlerController) -> Dictionary:
	var pa := _points(a)
	var pb := _points(b)
	var body := 0.0
	var arm := 0.0
	var where := ""
	var worst := 0.0
	for sa in SEGMENTS:
		if not (pa.has(sa[0]) and pa.has(sa[1])):
			continue
		for sb in SEGMENTS:
			if not (pb.has(sb[0]) and pb.has(sb[1])):
				continue
			var d := float(sa[2]) + float(sb[2]) - segment_distance(
					pa[sa[0]], pa[sa[1]], pb[sb[0]], pb[sb[1]])
			if d <= 0.0:
				continue
			var is_arm: bool = sa[3] == "arm" or sb[3] == "arm"
			if is_arm:
				arm = maxf(arm, d)
			else:
				body = maxf(body, d)
			var over := d - (ARM_LIMIT if is_arm else BODY_LIMIT)
			if over > worst:
				worst = over
				where = "A %s-%s x B %s-%s" % [sa[0], sa[1], sb[0], sb[1]]
	return {"body": body, "arm": arm, "where": where, "over": worst}


## Runs `move_id` through the real GrappleRig in a fresh match scene under
## `host`, and returns its worst overlap: {"move", "body", "arm", "worst",
## "where", "at"}. "worst" is the largest excess over the matching limit.
static func measure(host: Node, move_id: String) -> Dictionary:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	host.add_child(scene)
	await host.get_tree().physics_frame
	var attacker: WrestlerController = scene.get_node("WrestlerA")
	var defender: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [attacker, defender]:
		w.is_ai = false
	var move: MoveDef = load("res://resources/moves/%s.tres" % move_id)
	defender.global_position = attacker.global_position \
			- attacker.global_transform.basis.z * 0.9
	attacker.look_at(defender.global_position, Vector3.UP)
	defender.look_at(attacker.global_position, Vector3.UP)
	await host.get_tree().physics_frame
	var rig: GrappleRig = scene.get_node("GrappleRig")
	rig.begin(attacker, defender, move)
	var total := maxi(int(move.total_frames()), 1)
	var r := {"move": move_id, "body": 0.0, "arm": 0.0, "worst": 0.0, "where": "", "at": 0.0}
	var tick := 0
	while rig.is_active() and tick < total * 3:
		await host.get_tree().physics_frame
		tick += 1
		var d := depth(attacker, defender)
		r["body"] = maxf(r["body"], d["body"])
		r["arm"] = maxf(r["arm"], d["arm"])
		if d["over"] > r["worst"]:
			r["worst"] = d["over"]
			r["where"] = d["where"]
			r["at"] = float(tick) / total
	scene.queue_free()
	await host.get_tree().process_frame
	return r
