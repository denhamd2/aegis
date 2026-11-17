extends RefCounted
## What makes a looping walk, jog or run read as a man moving rather than a
## machine, measured off the baked clip (forward kinematics over its own
## tracks, the way tools/anim/gait_audit.gd does it).
##
## Used by tests/test_walks_look_natural.gd (the gate) and
## tools/probe/walk_quality.gd (the printout). Thresholds live in the test;
## this file only measures.
##
## Every number is for ONE clip on the base rig. Rig space: +Z forward, Y up
## once the root bone's own rotation is applied (_global does that), so a
## foot's height is global y and its stride is global z.
##
## The measures, and why each:
##   skate       a foot on the mat must go backward at the engine's speed
##   seam        the pose and its motion must close across the loop
##   arms        swing, and swing against the legs (the left arm goes with the
##               right leg), unless the character holds them still on purpose
##   torso       the chest turns against the pelvis (counter-rotation)
##   pelvis      it drops twice a stride and sways once a stride
##   head        it rides over the stride rather than nodding with it
##   stride      step length against the one a body of this leg makes at this
##               speed (Alexander's dynamic similarity), and against the reach
##   robotic     every joint that should move does; the spine is not a pole;
##               the knee bends and straightens; the elbow is not locked

const FPS := 60.0
## Ankle height below which a foot counts as on the mat (gait_audit's).
const PLANT_HEIGHT := 0.13
## How far above the mat the lowest point of the sole may be and still count
## as planted, and how high the ball and toe bones' own origins stand when the
## foot is flat (their rest height; the heel point is on the mat).
const SOLE_PLANT := 0.02
const BALL_FLOOR := 0.0152
## The heel, in rest-pose rig space: behind the ankle, on the mat.
const HEEL_REST_BEHIND_ANKLE := 0.05
## Thigh + calf on the base rig, hip to ankle at full stretch.
const LEG_LENGTH := 0.829
## Hip height of the rest pose, for the dynamic-similarity stride.
const HIP_HEIGHT := 0.9167
const GRAVITY := 9.81
## A key joint turning less than this in a frame (60 fps) is holding still.
const STILL_DEG := 0.05

## Joints whose rotation must not sit frozen through a walk.
const LIMB_JOINTS := ["thigh_l", "thigh_r", "calf_l", "calf_r", "upperarm_l", "upperarm_r",
		"lowerarm_l", "lowerarm_r"]
const SPINE_JOINTS := ["spine_01", "spine_02", "spine_03"]
const KEY_JOINTS := ["pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r",
		"spine_01", "spine_02", "spine_03", "neck_01", "Head", "clavicle_l", "clavicle_r",
		"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]


## The walks the game plays: clip in strikes/ -> the engine speed (m/s) it is
## played at, the gait cycles it holds, who walks it and where. The speeds
## are EntranceDirector's and WrestlerController's constants.
const WALKS := {
	"walk_slow_look": {"speed": 0.5, "cycles": 3, "men": ["roman"], "where": "entrance"},
	"walk_crowd": {"speed": 1.2, "cycles": 4, "men": ["cody"], "where": "entrance"},
	"kenny_walk": {"speed": 1.1, "cycles": 4, "men": ["kenny"], "where": "entrance"},
	"entrance_walk": {"speed": 1.6, "cycles": 1, "men": ["roman", "cody", "kenny"],
			"where": "entrance, face-off walk-in"},
	"walk_stalk": {"speed": 3.5, "cycles": 1, "men": ["roman", "cody", "kenny"], "where": "gameplay"},
	"run_jog": {"speed": 4.2, "cycles": 1, "men": ["roman", "cody", "kenny"], "where": "gameplay, outside the ring"},
	"run_drive": {"speed": 7.0, "cycles": 1, "men": ["roman", "cody", "kenny"], "where": "gameplay, running"},
}


## What each walk must hold, and where every number came from. A gate is
## [measure, lo, hi]; lo or hi null means one-sided. They are set from the
## walks that read well in the contact sheets (gauntlet/refs/walks/) --
## Roman's, Cody's and Kenny's entrance walks on _heavy_gait -- and from the
## gait literature where a whole class of clip got it wrong the same way (the
## arm phase, below). A walk is a gait under RUN_FROM m/s; at and over it the
## body runs (Froude ~0.7: no man walks 3.5 m/s) and is held to a runner.
const RUN_FROM := 2.5
const GATES := {
	# The canvas holds under the boot: the part of the sole on the mat goes
	# back at the engine's speed. The good walks deliver 0.99-1.03.
	"skate": ["skate_ratio_min", 0.90, null],
	"skate_hi": ["skate_ratio_max", null, 1.10],
	# The loop closes in pose (gait_audit's 5 mm) and in motion: no harder a
	# kink at the seam than half again the loop's worst anywhere else.
	"seam_pose": ["seam_pop_m", null, 0.005],
	"seam_motion": ["seam_kink_vs_loop", null, 1.5],
	# The arms swing against the legs: the left hand forward with the right
	# foot. -1 is a perfect opposition; +1 is a pace.
	"arm_opposition": ["hands_vs_feet", null, -0.5],
	# The pelvis turns with the stride -- the hip of the leading leg goes
	# forward (Inman's pelvic rotation) -- and the shoulders turn against it.
	"hip_rotation": ["hips_vs_feet", 0.3, null],
	"shoulder_counter": ["shoulders_vs_feet", null, -0.3],
	# Something twists between them at the stride: the good walks 6.9-12.
	"torso_twist": ["torso_twist_stride_pp", 2.0, null],
	# The head rides the stride; it does not nod or swing with it. The good
	# walks' worst is 5.8 deg (Kenny, who is loose by design).
	"head_steady": ["head_wobble_deg", null, 6.5],
	# Reach: the leg never stretches past its own length.
	"leg_reach": ["leg_reach_max", null, 1.0],
	# Nothing a walk does is frozen: every leg and arm joint turns at least
	# 2 deg, the knee bends and straightens through 25 (the good walks 28-38),
	# the elbow is not locked, the spine is not a pole (good walks 21-49 deg
	# over its three joints; under 8 the torso is carried like a plank), and
	# no frame-to-frame hold.
	"frozen_limbs": ["frozen_limbs", null, 0],
	"knee_bends": ["knee_flex_range_deg", 25.0, null],
	"elbow_unlocked": ["elbow_flex_range_deg", 5.0, null],
	"spine_alive": ["spine_range_sum_deg", 8.0, null],
	"no_holds": ["longest_hold_frames", null, 3],
}
## For a walk.
const WALK_GATES := {
	# The weight drops at each footfall (the good walks 3.0-4.3 cm) and moves
	# over the planted foot (3.6-5.0 cm), the hip on the swing side dropping
	# (1.6-3.5 deg). A walk at 1.5 cm and no sway glides on a rail.
	"pelvis_dip": ["pelvis_dip_m", 0.020, null],
	"pelvis_sway": ["pelvis_sway_m", 0.015, null],
	"pelvis_roll": ["pelvis_roll_pp", 1.0, null],
	# Arms swing: a hand travels at least 10 cm fore and aft of its shoulder
	# (Roman's deliberately small swing is 18, Cody's 30, Kenny's 40).
	"arm_swing": ["arm_swing_m_min", 0.10, null],
	# A walk's stride against the one a body of this leg makes at this speed
	# (Alexander 1976): the good walks 0.83-1.11.
	"stride": ["stride_vs_natural", 0.75, 1.30],
	# Always a foot on the mat, and both for a share of the cycle; a "walk"
	# with no double support is a run with its knees locked.
	"double_support": ["double_support", 0.08, 0.65],
	"no_flight": ["flight", null, 0.02],
}
## For a run.
const RUN_GATES := {
	"pelvis_dip": ["pelvis_dip_m", 0.030, null],
	"pelvis_sway": ["pelvis_sway_m", 0.005, null],
	# A runner's hands travel 20 cm and more; a jog with its hands parked is
	# a walk sped up.
	"arm_swing": ["arm_swing_m_min", 0.20, null],
	# Turnover against a runner's at this speed (150 + 6.5 per m/s steps a
	# minute): a run goes faster by striding longer, not by pedalling.
	"cadence": ["cadence_vs_run", 0.80, 1.15],
}
## Per man, on his own entrance walk (gauntlet/refs/entrances.md).
const MAN_GATES := {
	# Roman: "arms hanging a hand's width off his sides", head still.
	"roman": {"arm_swing_small": ["arm_swing_m_max", null, 0.25],
			"head_still": ["head_wobble_deg", null, 5.5]},
	# Cody: "brisk, bouncy, shoulders rolling, arms swinging".
	"cody": {"arm_swing_free": ["arm_swing_m_min", 0.20, null]},
	# Kenny: loose, the arms wider and later.
	"kenny": {"arm_swing_free": ["arm_swing_m_min", 0.20, null]},
}


## {gate: [passes, value, lo, hi]} for one clip's measures `r`.
static func judge(clip: String, r: Dictionary) -> Dictionary:
	var w: Dictionary = WALKS[clip]
	var gates := GATES.duplicate()
	gates.merge(RUN_GATES if float(w["speed"]) >= RUN_FROM else WALK_GATES)
	var men: Array = w["men"]
	if men.size() == 1:
		gates.merge(MAN_GATES.get(men[0], {}))
	var out := {}
	for name: String in gates:
		var g: Array = gates[name]
		var v := float(r[g[0]])
		var ok := (g[1] == null or v >= float(g[1])) and (g[2] == null or v <= float(g[2]))
		out[name] = [ok, v, g[1], g[2]]
	return out


## Measures one clip. `speed` is the engine's m/s while it plays; `cycles` how
## many gait cycles (a right step and a left step) the clip holds.
static func analyze(skeleton: Skeleton3D, anim: Animation, speed: float, cycles := 1) -> Dictionary:
	var ctx := _Ctx.new(skeleton, anim)
	var n := int(round(anim.length * FPS))
	var poses: Array = []
	for i in n + 1:
		poses.append(ctx.pose(minf(float(i) / FPS, anim.length)))
	var out := {"clip_seconds": anim.length, "samples": n, "cycles": cycles, "speed": speed}
	var cycle_seconds := anim.length / float(cycles)
	out["cycle_seconds"] = cycle_seconds
	out["keys_per_second"] = float(anim.track_get_key_count(ctx.rot[ctx.index("thigh_l")])) / anim.length
	_skate(ctx, poses, n, speed, out)
	_seam(ctx, poses, n, out)
	_arms(ctx, poses, n, cycles, out)
	_torso(ctx, poses, n, cycles, out)
	_lines(ctx, poses, n, cycles, out)
	_pelvis(ctx, poses, n, cycles, out)
	_head(ctx, poses, n, cycles, out)
	_stride(ctx, poses, n, speed, cycle_seconds, out)
	_robotic(ctx, poses, n, out)
	return out


# --- skate ------------------------------------------------------------------

static func _skate(ctx: _Ctx, poses: Array, n: int, speed: float, out: Dictionary) -> void:
	# Two readings.
	#
	# ANKLE: while it is below PLANT_HEIGHT, as gait_audit has always read it.
	# It condemns a foot that rolls on purpose: the ankle moves on while the
	# toe holds.
	#
	# SOLE: the foot's lowest point of heel, ball and toe, tracked from tick to
	# tick while it is within SOLE_PLANT of the mat. That point must go backward
	# at the engine's speed or the canvas slides under it, whichever part of the
	# sole it is -- the heel at heel strike, the whole foot flat, the ball and
	# toe as the heel lifts. A tick on which the lowest point changes is not
	# counted (the point has moved by a foot length, not slid).
	for mode in ["ankle", "sole"]:
		var ratios: Array[float] = []
		var sq := 0.0
		var sq_side := 0.0
		var ticks := 0
		var planted_total := 0.0
		for side in ["l", "r"]:
			var planted := 0.0
			var travelled := 0.0
			var prev := Vector3.ZERO
			var prev_k := -1
			for i in n + 1:
				var k := -1
				var p := Vector3.ZERO
				if mode == "ankle":
					p = poses[i][ctx.index("foot_" + side)].origin
					k = 0 if p.y < PLANT_HEIGHT else -1
				else:
					var low := _sole_point(ctx, poses[i], side, prev_k)
					k = low[0]
					p = low[1]
				# A planted foot goes backward under the man; one that is low but
				# moving forward is at the end of its swing (a walk lifts it only
				# 6 cm), not planted.
				if k >= 0 and k == prev_k and prev.z - p.z > 0.0:
					var v := (prev.z - p.z) * FPS
					travelled += prev.z - p.z
					planted += 1.0 / FPS
					sq += (v - speed) * (v - speed)
					sq_side += ((p.x - prev.x) * FPS) * ((p.x - prev.x) * FPS)
					ticks += 1
				prev = p
				prev_k = k
			if planted > 0.0:
				ratios.append(travelled / planted / maxf(speed, 0.001))
				planted_total += planted
		var key := "skate_" if mode == "sole" else "skate_ankle_"
		out[key + "ratio_min"] = ratios.min() if not ratios.is_empty() else 0.0
		out[key + "ratio_max"] = ratios.max() if not ratios.is_empty() else 0.0
		out[key + "rms"] = sqrt(sq / maxf(ticks, 1))
		out[key + "side_rms"] = sqrt(sq_side / maxf(ticks, 1))
		out[key + "planted_seconds"] = planted_total


## [index of the sole point on the mat (0 heel, 1 ball, 2 toe; -1 none), where
## it is]. `prev` is last tick's point, kept while it is still within a
## whisker of the lowest, so a flat foot does not flicker between its three.
static func _sole_point(ctx: _Ctx, pose: Array, side: String, prev: int) -> Array:
	var foot: Transform3D = pose[ctx.index("foot_" + side)]
	var pts: Array[Vector3] = [
		foot * ctx.heel_local(side),
		pose[ctx.index("ball_" + side)].origin,
		pose[ctx.index("ball_leaf_" + side)].origin]
	var floors := [0.0, BALL_FLOOR, BALL_FLOOR]
	var best := -1
	var best_h := INF
	for k in 3:
		var h: float = pts[k].y - floors[k]
		if h < best_h:
			best_h = h
			best = k
	if best_h > SOLE_PLANT:
		return [-1, Vector3.ZERO]
	if prev >= 0 and pts[prev].y - floors[prev] < best_h + 0.006:
		best = prev
	return [best, pts[best]]


# --- loop seam --------------------------------------------------------------

static func _seam(ctx: _Ctx, poses: Array, n: int, out: Dictionary) -> void:
	# Position pop: the pose at the end of the clip against the start.
	var worst := 0.0
	for b in ctx.bone_count:
		worst = maxf(worst, (poses[n][b].origin - poses[0][b].origin).length())
	out["seam_pop_m"] = worst
	# Motion kink: the turn rate of each key joint across the seam against its
	# neighbours' (a seam that closes the pose but reverses the motion is felt
	# as a hitch every cycle). The same second difference is taken at every
	# other frame of the loop too, because a run's knee legitimately changes
	# speed by several degrees a frame at heel strike: a seam is a hitch when
	# it kinks harder than anything the loop does elsewhere.
	var kink := 0.0
	var kink_bone := ""
	var ratio := 0.0
	for name in KEY_JOINTS:
		var b := ctx.index(name)
		var q: Array = []
		for i in n:
			q.append(poses[i][b].basis.get_rotation_quaternion())
		var at_seam := _kink(q, n - 1)
		var elsewhere := 0.0
		for i in range(1, n - 2):
			elsewhere = maxf(elsewhere, _kink(q, i))
		if at_seam > kink:
			kink = at_seam
			kink_bone = name
		if at_seam > 0.5:
			ratio = maxf(ratio, at_seam / maxf(elsewhere, 0.25))
	out["seam_kink_deg"] = kink
	out["seam_kink_bone"] = kink_bone
	out["seam_kink_vs_loop"] = ratio


## The turn across q[i] -> q[i+1] against the mean of the turns either side,
## in degrees per frame (indices wrap: the loop's last sample precedes 0).
static func _kink(q: Array, i: int) -> float:
	var n := q.size()
	var a: Quaternion = q[(i - 1 + n) % n]
	var b: Quaternion = q[i % n]
	var c: Quaternion = q[(i + 1) % n]
	var d: Quaternion = q[(i + 2) % n]
	var before := rad_to_deg(a.angle_to(b))
	var across := rad_to_deg(b.angle_to(c))
	var after := rad_to_deg(c.angle_to(d))
	return absf(across - (before + after) * 0.5)


# --- arms -------------------------------------------------------------------

## The arm's swing angle in the sagittal plane: shoulder to wrist, + forward.
static func _arm_angle(ctx: _Ctx, pose: Array, side: String) -> float:
	var s: Vector3 = pose[ctx.index("upperarm_" + side)].origin
	var h: Vector3 = pose[ctx.index("hand_" + side)].origin
	return rad_to_deg(atan2(h.z - s.z, -(h.y - s.y)))

static func _leg_angle(ctx: _Ctx, pose: Array, side: String) -> float:
	var s: Vector3 = pose[ctx.index("thigh_" + side)].origin
	var f: Vector3 = pose[ctx.index("foot_" + side)].origin
	return rad_to_deg(atan2(f.z - s.z, -(f.y - s.y)))

static func _arms(ctx: _Ctx, poses: Array, n: int, cycles: int, out: Dictionary) -> void:
	var al: Array[float] = []
	var ar: Array[float] = []
	var ll: Array[float] = []
	var lr: Array[float] = []
	var hz_l: Array[float] = []
	var hz_r: Array[float] = []
	for i in n:
		al.append(_arm_angle(ctx, poses[i], "l"))
		ar.append(_arm_angle(ctx, poses[i], "r"))
		ll.append(_leg_angle(ctx, poses[i], "l"))
		lr.append(_leg_angle(ctx, poses[i], "r"))
		# The hand against its own shoulder, in the chest's frame: the arm's
		# swing, not the body's turn carrying a still arm round with it.
		var chest := ctx.rest_relative(poses[i], "spine_03").inverse()
		hz_l.append((chest * (poses[i][ctx.index("hand_l")].origin - poses[i][ctx.index("upperarm_l")].origin)).z)
		hz_r.append((chest * (poses[i][ctx.index("hand_r")].origin - poses[i][ctx.index("upperarm_r")].origin)).z)
	out["arm_swing_deg_l"] = _pp(al)
	out["arm_swing_deg_r"] = _pp(ar)
	out["arm_swing_m_l"] = _pp(hz_l)
	out["arm_swing_m_r"] = _pp(hz_r)
	out["arm_swing_m_min"] = minf(out["arm_swing_m_l"], out["arm_swing_m_r"])
	out["arm_swing_m_max"] = maxf(out["arm_swing_m_l"], out["arm_swing_m_r"])
	out["leg_swing_deg"] = maxf(_pp(ll), _pp(lr))
	# A left arm goes forward with the right leg: positive correlation across
	# sides, allowing a lag of up to an eighth of the cycle (the arms trail the
	# shoulders). Negative on the same side.
	var window := maxi(1, int(round(float(n) / float(cycles) / 8.0)))
	var opp_l := _best_corr(al, lr, window)
	var opp_r := _best_corr(ar, ll, window)
	out["arm_opposition_l"] = opp_l[0]
	out["arm_opposition_r"] = opp_r[0]
	out["arm_opposition_lag_frames"] = maxf(absf(opp_l[1]), absf(opp_r[1]))
	out["arm_opposition_zero_lag"] = minf(_corr(al, lr, 0), _corr(ar, ll, 0))
	# The same at the stride's own frequency, as the cosine of the phase gap
	# between an arm and the OPPOSITE leg: +1 is the natural cross-body swing
	# (the left arm forward as the right leg is), -1 is a pace (arm and leg of
	# one side forward together, which is how a march and a camel walk).
	var pl := _harmonic_complex(al, cycles, 1)
	var pr := _harmonic_complex(ar, cycles, 1)
	var gl := _harmonic_complex(ll, cycles, 1)
	var gr := _harmonic_complex(lr, cycles, 1)
	var cos_l := pl.normalized().dot(gr.normalized()) if pl.length() > 1e-6 and gr.length() > 1e-6 else 0.0
	var cos_r := pr.normalized().dot(gl.normalized()) if pr.length() > 1e-6 and gl.length() > 1e-6 else 0.0
	out["arm_leg_phase_cos"] = minf(cos_l, cos_r)
	out["arm_leg_phase_deg"] = maxf(rad_to_deg(acos(clampf(cos_l, -1.0, 1.0))),
			rad_to_deg(acos(clampf(cos_r, -1.0, 1.0))))
	# The two arms swing against each other, not with.
	out["arm_vs_arm"] = _corr(al, ar, 0)


# --- torso ------------------------------------------------------------------

static func _torso(ctx: _Ctx, poses: Array, n: int, cycles: int, out: Dictionary) -> void:
	var py: Array[float] = []
	var cy: Array[float] = []
	var cp: Array[float] = []
	var cr: Array[float] = []
	var twist: Array[float] = []
	for i in n:
		var p := ctx.rest_relative(poses[i], "pelvis")
		var c := ctx.rest_relative(poses[i], "spine_03")
		py.append(_yaw(p))
		cy.append(_yaw(c))
		cp.append(_pitch(c))
		cr.append(_roll(c))
		twist.append(_yaw(c) - _yaw(p))
	out["pelvis_yaw_pp"] = _pp(py)
	out["chest_yaw_pp"] = _pp(cy)
	out["chest_pitch_pp"] = _pp(cp)
	out["chest_roll_pp"] = _pp(cr)
	out["torso_twist_pp"] = _pp(twist)
	# At the stride's own frequency (a slow look to one side is not the walk):
	# the chest's turn against the pelvis's, as the cosine of their phase gap
	# (-1 is a perfect counter-rotation, +1 turning together), and the chest's
	# amplitude as a share of the pelvis's.
	var hp := _harmonic_complex(py, cycles, 1)
	var hc := _harmonic_complex(cy, cycles, 1)
	var ht := _harmonic_complex(twist, cycles, 1)
	out["pelvis_yaw_stride_pp"] = 2.0 * hp.length()
	out["chest_yaw_stride_pp"] = 2.0 * hc.length()
	out["torso_twist_stride_pp"] = 2.0 * ht.length()
	out["chest_vs_pelvis_phase"] = hp.normalized().dot(hc.normalized()) if hp.length() > 1e-6 and hc.length() > 1e-6 else 0.0
	out["chest_vs_pelvis_ratio"] = hc.length() / maxf(hp.length(), 1e-6)


# --- the body's lines against the legs ---------------------------------------

## How far the right one of a pair of bones is in front of the left (rig z).
static func _lead(ctx: _Ctx, pose: Array, stem: String) -> float:
	return pose[ctx.index(stem + "r")].origin.z - pose[ctx.index(stem + "l")].origin.z

static func _lines(ctx: _Ctx, poses: Array, n: int, cycles: int, out: Dictionary) -> void:
	# Convention-free: no yaw sign, no axis, only "is the right one in front
	# of the left". Read at the stride's own frequency against the feet's
	# lead (right foot in front of the left), as the cosine of the phase gap:
	#   hips       +1  the right hip goes forward with the right leg
	#   shoulders  -1  the LEFT shoulder comes forward as the right leg does
	#   hands      -1  the left hand swings forward with the right foot;
	#                  +1 is a pace -- arm and leg of one side together, a
	#                  march, a camel, a wind-up toy.
	var feet: Array[float] = []
	var hips: Array[float] = []
	var shoulders: Array[float] = []
	var hands: Array[float] = []
	for i in n:
		feet.append(_lead(ctx, poses[i], "foot_"))
		hips.append(_lead(ctx, poses[i], "thigh_"))
		shoulders.append(_lead(ctx, poses[i], "upperarm_"))
		hands.append(_lead(ctx, poses[i], "hand_"))
	var hf := _harmonic_complex(feet, cycles, 1)
	for pair in [["hips", hips], ["shoulders", shoulders], ["hands", hands]]:
		var h := _harmonic_complex(pair[1], cycles, 1)
		out[pair[0] + "_vs_feet"] = h.normalized().dot(hf.normalized()) \
				if h.length() > 1e-6 and hf.length() > 1e-6 else 0.0
		out[pair[0] + "_lead_pp_m"] = 4.0 * h.length()
	out["feet_lead_pp_m"] = 4.0 * hf.length()


# --- pelvis -----------------------------------------------------------------

static func _pelvis(ctx: _Ctx, poses: Array, n: int, cycles: int, out: Dictionary) -> void:
	var y: Array[float] = []
	var x: Array[float] = []
	for i in n:
		var o: Vector3 = poses[i][ctx.index("pelvis")].origin
		y.append(o.y)
		x.append(o.x)
	out["pelvis_dip_m"] = _pp(y)
	out["pelvis_sway_m"] = _pp(x)
	# Which harmonic of the gait cycle carries the bob (2 for a stride: a dip
	# at each footfall) and the sway (1: over one foot, then the other).
	var ay := _harmonics(y, cycles, 4)
	var ax := _harmonics(x, cycles, 4)
	out["pelvis_dip_harmonic"] = _argmax(ay) + 1
	out["pelvis_sway_harmonic"] = _argmax(ax) + 1
	out["pelvis_dip_h2_share"] = ay[1] / maxf(ay[0] + ay[1] + ay[2] + ay[3], 1e-9)
	var roll: Array[float] = []
	for i in n:
		roll.append(_roll(ctx.rest_relative(poses[i], "pelvis")))
	out["pelvis_roll_pp"] = _pp(roll)


# --- head -------------------------------------------------------------------

static func _head(ctx: _Ctx, poses: Array, n: int, cycles: int, out: Dictionary) -> void:
	var yaw: Array[float] = []
	var pitch: Array[float] = []
	var roll: Array[float] = []
	var hy: Array[float] = []
	var hx: Array[float] = []
	var pel_y: Array[float] = []
	for i in n:
		var h := ctx.rest_relative(poses[i], "Head")
		yaw.append(_yaw(h))
		pitch.append(_pitch(h))
		roll.append(_roll(h))
		var o: Vector3 = poses[i][ctx.index("Head")].origin
		hy.append(o.y)
		hx.append(o.x)
		pel_y.append(poses[i][ctx.index("pelvis")].origin.y)
	# Strip the slow part (a look to a side of the aisle) with a boxcar of one
	# gait cycle: what is left is what the stride does to the head.
	var win := maxi(3, n / cycles)
	out["head_pitch_residual_pp"] = _pp(_residual(pitch, win))
	out["head_roll_residual_pp"] = _pp(_residual(roll, win))
	# A look is a turn of the whole head, so its yaw is read at the stride's own
	# frequency, as the torso's is.
	out["head_yaw_stride_pp"] = 2.0 * _harmonic_complex(yaw, cycles, 1).length() \
			+ 2.0 * _harmonic_complex(yaw, cycles, 2).length()
	out["head_yaw_pp"] = _pp(yaw)
	out["head_wobble_deg"] = maxf(maxf(out["head_pitch_residual_pp"], out["head_roll_residual_pp"]),
			out["head_yaw_stride_pp"])
	out["head_bob_m"] = _pp(_residual(hy, win))
	out["head_sway_m"] = _pp(_residual(hx, win))
	out["head_bob_vs_pelvis"] = _pp(_residual(hy, win)) / maxf(_pp(_residual(pel_y, win)), 1e-6)


# --- stride -----------------------------------------------------------------

static func _stride(ctx: _Ctx, poses: Array, n: int, speed: float, cycle_seconds: float,
		out: Dictionary) -> void:
	var stride_len := speed * cycle_seconds
	var step_len := stride_len * 0.5
	out["step_length_m"] = step_len
	out["cadence_spm"] = 120.0 / cycle_seconds
	out["step_per_leg"] = step_len / LEG_LENGTH
	var froude := speed * speed / (GRAVITY * HIP_HEIGHT)
	out["froude"] = froude
	# Alexander (1976): stride / hip height = 2.3 * Fr^0.3 for any biped.
	var natural := 2.3 * HIP_HEIGHT * pow(maxf(froude, 1e-6), 0.3)
	out["natural_stride_m"] = natural
	out["stride_vs_natural"] = stride_len / natural
	# A run's cadence barely changes with speed -- a jogger and a fast runner
	# both turn over about 160-190 steps a minute and go faster by striding
	# longer (Cavanagh & Kram 1989; Heiderscheit 2011). The line through that
	# band: 150 steps/min plus 6.5 per m/s. A walk is read against Alexander's
	# stride instead.
	out["run_cadence_natural_spm"] = 150.0 + 6.5 * speed
	out["cadence_vs_run"] = (120.0 / cycle_seconds) / (150.0 + 6.5 * speed)
	# The reach the legs use: hip to ankle against its full stretch.
	var reach := 0.0
	for foot in ["foot_l", "foot_r"]:
		var side: String = foot.substr(foot.length() - 1)
		for i in n:
			var hip: Vector3 = poses[i][ctx.index("thigh_" + side)].origin
			var f: Vector3 = poses[i][ctx.index(foot)].origin
			reach = maxf(reach, (f - hip).length())
	out["leg_reach_max"] = reach / LEG_LENGTH
	# Duty factor: the share of the cycle a foot is down (its ankle or the ball
	# of it on the mat), and the share with both down or neither.
	var down := 0
	var both := 0
	var neither := 0
	for i in n:
		var on := {}
		for side in ["l", "r"]:
			var ank: Vector3 = poses[i][ctx.index("foot_" + side)].origin
			var ball: Vector3 = poses[i][ctx.index("ball_" + side)].origin
			on[side] = ank.y < PLANT_HEIGHT or ball.y < BALL_FLOOR + SOLE_PLANT
		down += int(on["l"]) + int(on["r"])
		both += int(on["l"] and on["r"])
		neither += int(not on["l"] and not on["r"])
	out["duty_factor"] = float(down) / float(2 * n)
	out["double_support"] = float(both) / float(n)
	out["flight"] = float(neither) / float(n)


# --- robotic ----------------------------------------------------------------

static func _robotic(ctx: _Ctx, poses: Array, n: int, out: Dictionary) -> void:
	var ranges := {}
	for name in LIMB_JOINTS + SPINE_JOINTS + ["pelvis", "neck_01", "Head", "clavicle_l", "clavicle_r"]:
		ranges[name] = _rotation_range(ctx, poses, n, name)
	out["joint_range_deg"] = ranges
	var frozen_limbs := 0
	var min_limb := INF
	for name in LIMB_JOINTS:
		min_limb = minf(min_limb, ranges[name])
		if ranges[name] < 2.0:
			frozen_limbs += 1
	out["frozen_limbs"] = frozen_limbs
	out["min_limb_range_deg"] = min_limb
	var spine := 0.0
	var min_spine := INF
	for name in SPINE_JOINTS:
		spine += ranges[name]
		min_spine = minf(min_spine, ranges[name])
	out["spine_range_sum_deg"] = spine
	out["min_spine_range_deg"] = min_spine
	# Knees: flexion through the stride.
	var kmin := INF
	var kmax := 0.0
	var elbow_min := INF
	var elbow_max := 0.0
	var foot_pitch: Array[float] = []
	for i in n:
		for side in ["l", "r"]:
			var hip: Vector3 = poses[i][ctx.index("thigh_" + side)].origin
			var knee: Vector3 = poses[i][ctx.index("calf_" + side)].origin
			var ank: Vector3 = poses[i][ctx.index("foot_" + side)].origin
			var flex := rad_to_deg((knee - hip).angle_to(ank - knee))
			kmin = minf(kmin, flex)
			kmax = maxf(kmax, flex)
			var sh: Vector3 = poses[i][ctx.index("upperarm_" + side)].origin
			var el: Vector3 = poses[i][ctx.index("lowerarm_" + side)].origin
			var wr: Vector3 = poses[i][ctx.index("hand_" + side)].origin
			var ef := rad_to_deg((el - sh).angle_to(wr - el))
			elbow_min = minf(elbow_min, ef)
			elbow_max = maxf(elbow_max, ef)
		foot_pitch.append(_pitch(ctx.rest_relative(poses[i], "foot_r")))
	out["knee_flex_min_deg"] = kmin
	out["knee_flex_max_deg"] = kmax
	out["knee_flex_range_deg"] = kmax - kmin
	out["elbow_flex_min_deg"] = elbow_min
	out["elbow_flex_max_deg"] = elbow_max
	out["elbow_flex_range_deg"] = elbow_max - elbow_min
	out["foot_pitch_pp"] = _pp(foot_pitch)
	# Holds: the longest run of consecutive frames in which no key joint
	# turns more than STILL_DEG. A walk never stops; a pose-to-pose cycle
	# with dead holds at its keys reads as a machine.
	var longest := 0
	var run := 0
	for i in n:
		var moving := false
		for name in KEY_JOINTS:
			var b := ctx.index(name)
			var p0: int = ctx.parent[b]
			var l0: Transform3D = poses[i][p0].affine_inverse() * poses[i][b] if p0 >= 0 else poses[i][b]
			var l1: Transform3D = poses[(i + 1) % n][p0].affine_inverse() * poses[(i + 1) % n][b] if p0 >= 0 else poses[(i + 1) % n][b]
			if rad_to_deg(l0.basis.get_rotation_quaternion().angle_to(l1.basis.get_rotation_quaternion())) > STILL_DEG:
				moving = true
				break
		run = 0 if moving else run + 1
		longest = maxi(longest, run)
	out["longest_hold_frames"] = longest


## The largest turn of a joint's local rotation through the loop.
static func _rotation_range(ctx: _Ctx, poses: Array, n: int, name: String) -> float:
	var b := ctx.index(name)
	var parent: int = ctx.parent[b]
	var q: Array[Quaternion] = []
	for i in range(0, n, 2):
		var local: Transform3D = poses[i][parent].affine_inverse() * poses[i][b] if parent >= 0 else poses[i][b]
		q.append(local.basis.get_rotation_quaternion())
	var best := 0.0
	for i in q.size():
		for j in range(i + 1, q.size()):
			best = maxf(best, q[i].angle_to(q[j]))
	return rad_to_deg(best)


# --- small maths ------------------------------------------------------------

static func _pp(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var lo := INF
	var hi := -INF
	for v: float in a:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo

static func _mean(a: Array) -> float:
	var s := 0.0
	for v: float in a:
		s += v
	return s / maxf(a.size(), 1)

static func _corr(a: Array, b: Array, lag: int) -> float:
	var n := a.size()
	var ma := _mean(a)
	var mb := _mean(b)
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i in n:
		var da: float = a[i] - ma
		var db: float = b[(i + lag + n) % n] - mb
		sab += da * db
		saa += da * da
		sbb += db * db
	if saa < 1e-12 or sbb < 1e-12:
		return 0.0
	return sab / sqrt(saa * sbb)

## [best correlation, its lag] over lags within +-window.
static func _best_corr(a: Array, b: Array, window: int) -> Array:
	var best := -2.0
	var best_lag := 0
	for lag in range(-window, window + 1):
		var c := _corr(a, b, lag)
		if c > best:
			best = c
			best_lag = lag
	return [best, best_lag]

## Amplitudes of the first `count` harmonics of the clip's gait cycle.
static func _harmonics(a: Array, cycles: int, count: int) -> Array[float]:
	var n := a.size()
	var out: Array[float] = []
	var m := _mean(a)
	for k in range(1, count + 1):
		var re := 0.0
		var im := 0.0
		for i in n:
			var ang := TAU * float(k * cycles) * float(i) / float(n)
			re += (a[i] - m) * cos(ang)
			im += (a[i] - m) * sin(ang)
		out.append(2.0 * sqrt(re * re + im * im) / float(n))
	return out

## The k-th harmonic of the gait cycle as a vector (cos part, sin part), the
## amplitude being half its length.
static func _harmonic_complex(a: Array, cycles: int, k: int) -> Vector2:
	var n := a.size()
	var m := _mean(a)
	var re := 0.0
	var im := 0.0
	for i in n:
		var ang := TAU * float(k * cycles) * float(i) / float(n)
		re += (a[i] - m) * cos(ang)
		im += (a[i] - m) * sin(ang)
	return Vector2(re, im) / float(n)

static func _argmax(a: Array) -> int:
	var bi := 0
	for i in a.size():
		if a[i] > a[bi]:
			bi = i
	return bi

## a minus its circular boxcar mean over `win` samples.
static func _residual(a: Array, win: int) -> Array[float]:
	var n := a.size()
	var out: Array[float] = []
	var half := win / 2
	for i in n:
		var s := 0.0
		for k in range(-half, half + 1):
			s += a[(i + k + n * 4) % n]
		out.append(a[i] - s / float(2 * half + 1))
	return out

static func _yaw(b: Basis) -> float:
	var f := b * Vector3(0.0, 0.0, 1.0)
	return rad_to_deg(atan2(f.x, f.z))

static func _pitch(b: Basis) -> float:
	var f := b * Vector3(0.0, 0.0, 1.0)
	return rad_to_deg(asin(clampf(f.y, -1.0, 1.0)))

static func _roll(b: Basis) -> float:
	var u := b * Vector3.UP
	return rad_to_deg(atan2(u.x, u.y))


## The skeleton and the clip's tracks, so a pose can be asked of any time.
class _Ctx:
	var skeleton: Skeleton3D
	var anim: Animation
	var bone_count: int
	var parent: Array[int] = []
	var rot: Array[int] = []
	var pos: Array[int] = []
	var rest: Array[Transform3D] = []
	var rest_global: Array[Transform3D] = []
	var _names := {}

	func _init(sk: Skeleton3D, a: Animation) -> void:
		skeleton = sk
		anim = a
		bone_count = sk.get_bone_count()
		for b in bone_count:
			_names[sk.get_bone_name(b)] = b
			parent.append(sk.get_bone_parent(b))
			rot.append(-1)
			pos.append(-1)
			rest.append(sk.get_bone_rest(b))
		for t in a.get_track_count():
			var name := String(a.track_get_path(t).get_concatenated_subnames())
			if not _names.has(name):
				continue
			if a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				rot[_names[name]] = t
			elif a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				pos[_names[name]] = t
		for b in bone_count:
			rest_global.append(rest[b] if parent[b] < 0 else rest_global[parent[b]] * rest[b])

	func index(name: String) -> int:
		return _names[name]

	## The heel's point in the foot bone's own frame: HEEL_REST_BEHIND_ANKLE
	## behind the standing ankle and on the mat.
	func heel_local(side: String) -> Vector3:
		var b: int = index("foot_" + side)
		var heel_rest := Vector3(rest_global[b].origin.x, 0.0, rest_global[b].origin.z - HEEL_REST_BEHIND_ANKLE)
		return rest_global[b].affine_inverse() * heel_rest

	## Every bone's transform in rig space at time `t`.
	func pose(t: float) -> Array:
		var out: Array = []
		out.resize(bone_count)
		for b in bone_count:
			var basis := rest[b].basis
			var origin := rest[b].origin
			if rot[b] >= 0:
				basis = Basis(anim.rotation_track_interpolate(rot[b], t))
			if pos[b] >= 0:
				origin = anim.position_track_interpolate(pos[b], t)
			var local := Transform3D(basis, origin)
			out[b] = local if parent[b] < 0 else out[parent[b]] * local
		return out

	## A bone's rotation in rig space relative to its rest, as a Basis.
	func rest_relative(pose_now: Array, name: String) -> Basis:
		var b := index(name)
		return pose_now[b].basis * rest_global[b].basis.inverse()
