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


## Contact, not overlap: how much of each capsule pair's overlap PairSeparation
## leaves alone. A body resting on another is a few millimetres "in" on
## capsules this size; a grip wraps an arm round him.
const BODY_CONTACT := 0.01
const ARM_CONTACT := 0.04


## The push, in world space, that would move `b` out of `a`: every
## overlapping capsule pair past its contact allowance contributes its excess
## along the line from a's closest point to b's. Summed, then capped at the
## single deepest excess (many pairs overlapping the same way would otherwise
## push many times too far). Zero when they only touch.
static func push(a: WrestlerController, b: WrestlerController) -> Vector3:
	var pa := _points(a)
	var pb := _points(b)
	var total := Vector3.ZERO
	var deepest := 0.0
	for sa in SEGMENTS:
		if not (pa.has(sa[0]) and pa.has(sa[1])):
			continue
		for sb in SEGMENTS:
			if not (pb.has(sb[0]) and pb.has(sb[1])):
				continue
			var pts := Geometry3D.get_closest_points_between_segments(
					pa[sa[0]], pa[sa[1]], pb[sb[0]], pb[sb[1]])
			var gap: float = (pts[1] as Vector3).distance_to(pts[0])
			var allow := ARM_CONTACT if (sa[3] == "arm" or sb[3] == "arm") else BODY_CONTACT
			var excess := float(sa[2]) + float(sb[2]) - gap - allow
			if excess <= 0.0:
				continue
			var n: Vector3 = (pts[1] as Vector3) - (pts[0] as Vector3)
			if n.length() < 1e-4:
				# Centre lines crossing: push b away from a's body centre.
				n = b.global_position - a.global_position
				n.y = 0.0
			total += n.normalized() * excess
			deepest = maxf(deepest, excess)
	if total.length() > deepest:
		total = total.normalized() * deepest
	return total


## Runs `move_id` through the real GrappleRig in a fresh match scene under
## `host`, and returns its worst overlap: {"move", "body", "arm", "worst",
## "where", "at"}. "worst" is the largest excess over the matching limit.
static func measure(host: Node, move_id: String, roster := PackedStringArray()) -> Dictionary:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	# The real wrestlers at their real sizes, when asked (["roman", "cody"]):
	# the clips were authored on the mannequin, and the separation has to
	# hold for the men who actually wrestle.
	if roster.size() == 2:
		TitleScreen.configure_match(scene, Roster.by_id(roster[0]), Roster.by_id(roster[1]), 1)
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
	# As a match starts one (WrestlerController._begin_running_paired): roles
	# set and both men in GRAPPLE_HOLD first. Without it the attacker never
	# counts as gripping, so the grip IK -- the arms -- never ran here.
	attacker._is_grapple_attacker = true
	defender._is_grapple_attacker = false
	attacker.opponent = defender
	defender.opponent = attacker
	attacker.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	defender.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	rig.begin(attacker, defender, move)
	var total := maxi(int(move.total_frames()), 1)
	var r := {"move": move_id, "body": 0.0, "arm": 0.0, "worst": 0.0, "where": "", "at": 0.0,
			"moved_attacker": 0.0, "moved_defender": 0.0, "grip": [], "grip_blend": 0.0}
	# Hands as drawn, IK included: a bone pose read from outside a
	# SkeletonModifier3D is the pose BEFORE the modifiers (EyeAim found the
	# same), so the grip IK's result is only readable inside the skeleton's
	# own update.
	var drawn_hands := [Vector3.ZERO, Vector3.ZERO]
	var drawn_shoulders := [Vector3.ZERO, Vector3.ZERO]
	var ask := attacker.skeleton
	# One physics tick per render frame while measuring. The drawn hands are
	# read off the skeleton's own update, which runs on the render loop; when a
	# render frame ran several physics ticks, the hands sampled on the later
	# ticks were stale by a machine-dependent amount, and the same move measured
	# 0.17 one run and 0.20 the next. With one tick a frame they are always the
	# hands drawn after the previous tick -- what the game itself shows.
	var steps := Engine.max_physics_steps_per_frame
	Engine.max_physics_steps_per_frame = 1
	var hand_ids := [ask.find_bone(attacker._skeleton_bone_name("hand_l")),
			ask.find_bone(attacker._skeleton_bone_name("hand_r"))]
	var shoulder_ids := [ask.find_bone(attacker._skeleton_bone_name("upperarm_l")),
			ask.find_bone(attacker._skeleton_bone_name("upperarm_r"))]
	var on_update := func() -> void:
		for side in 2:
			drawn_hands[side] = ask.global_transform * ask.get_bone_global_pose(hand_ids[side]).origin
			drawn_shoulders[side] = ask.global_transform * ask.get_bone_global_pose(shoulder_ids[side]).origin
	ask.skeleton_updated.connect(on_update)
	var tick := 0
	# Only this move: out of GRAPPLE_HOLD the hold can start a second one
	# straight away, which is not what is being measured.
	var done := [false]
	rig.grapple_finished.connect(func(_a, _d) -> void: done[0] = true, CONNECT_ONE_SHOT)
	while rig.is_active() and not done[0] and tick < total * 3:
		await host.get_tree().physics_frame
		tick += 1
		var d := depth(attacker, defender)
		r["moved_attacker"] = maxf(r["moved_attacker"], attacker.paired_separation.length())
		# The attacker's hands against where PairedContacts says they hold.
		r["grip_blend"] = maxf(r["grip_blend"], attacker._grip_blend)
		var fam := PairedContacts.family(move)
		if fam != "" and fam != "none" and attacker._grip_blend > 0.9:
			var sk := attacker.skeleton
			var chest := sk.global_transform * sk.get_bone_global_pose(
					sk.find_bone(attacker._skeleton_bone_name("spine_03"))).origin
			var t := PairedContacts.targets(fam, defender, chest)
			if t.size() == 2:
				for side in 2:
					# Only where he can reach it: while he is still running in
					# or the man is flying away, a hand stops short by design.
					var reach := (drawn_shoulders[side] as Vector3).distance_to(t[side])
					if reach <= attacker._arm_reach * 0.95:
						(r["grip"] as Array).append((drawn_hands[side] as Vector3).distance_to(t[side]))
					else:
						r["out_of_reach"] = int(r.get("out_of_reach", 0)) + 1
		r["moved_defender"] = maxf(r["moved_defender"], defender.paired_separation.length())
		r["body"] = maxf(r["body"], d["body"])
		r["arm"] = maxf(r["arm"], d["arm"])
		if d["over"] > r["worst"]:
			r["worst"] = d["over"]
			r["where"] = d["where"]
			r["at"] = float(tick) / total
	Engine.max_physics_steps_per_frame = steps
	scene.queue_free()
	await host.get_tree().process_frame
	return r
