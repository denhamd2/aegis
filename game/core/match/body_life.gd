class_name BodyLife
extends SkeletonModifier3D
## What a wrestler does between moves (gauntlet/refs/animation_gap.md, Phase 3
## "in-between life"): the parts of him no clip carries.
##
##   * He watches the other man. Head and neck turn to follow him -- 60% of
##     the turn in the head, 40% in the neck, within what a neck does (70
##     degrees either way, 30 up or down) -- so circling, he keeps his eyes on
##     his man instead of staring down the line of his hips. EyeAim, after
##     this, finishes the look with the eyes.
##   * He breathes: a slow rise and fall of the chest, quicker and deeper as
##     the match wears on him.
##   * He wears down: shoulders round and the head drops as damage mounts --
##     the man who has taken a beating looks it before the HUD says so. A man
##     fired up straightens: the comeback shows in his posture.
##
##   * He fidgets, standing: every few seconds one of a weight shift onto a
##     leg, a roll of the neck or a small bounce on the balls of his feet --
##     on a schedule seeded per man, so two never move in step. FootLock,
##     after this, keeps his feet where they are, so the shift reads through
##     the legs rather than sliding him.
##
## Only where no clip needs the head or spine for itself (standing, moving,
## selling a stagger); it eases in and out as he enters and leaves those
## states. Presentation only (ARCHITECTURE.md).

const MAX_YAW := deg_to_rad(70.0)
const MAX_PITCH := deg_to_rad(30.0)
## Past this the man is behind him: he does not wring his neck round, he
## eases back to looking ahead.
const GIVE_UP := deg_to_rad(130.0)
## How quickly the look follows, per tick (share of the gap closed).
const FOLLOW := 0.18
## How quickly the whole layer eases in or out, per tick.
const EASE := 0.12
## Breaths per minute, fresh and spent, and the chest's swing in degrees.
const BREATH_FRESH := 14.0
const BREATH_SPENT := 32.0
const BREATH_DEG_FRESH := 1.0
const BREATH_DEG_SPENT := 3.2
## Slump when spent, degrees: rounding through the spine, and the head's drop.
const SLUMP_SPINE_DEG := 8.0
const SLUMP_HEAD_DEG := 7.0
## Damage that reads as spent -- Sweat's scale, so he looks as tired as he
## is wet.
const DAMAGE_FULL := 160.0

var bones := {"pelvis": "pelvis", "spine_02": "spine_02", "spine_03": "spine_03",
		"neck_01": "neck_01", "Head": "Head"}
var wrestler: WrestlerController
## Seconds of breathing phase this man starts at, so two do not breathe in
## step.
var phase := 0.0

var _ids := {}
var _weight := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _breath_clock := 0.0
var _last_frame := -1

## --- Fidgets ----------------------------------------------------------------
const FIDGET_EVERY_MIN := 3.0   # seconds between fidgets
const FIDGET_EVERY_MAX := 7.0
const FIDGET_SECONDS := 2.2      # one fidget, in and out
const SHIFT_M := 0.045           # hips over one leg
const NECK_ROLL_DEG := 14.0
const BOUNCE_M := 0.025
var fidget_seed := 0
var _rng := RandomNumberGenerator.new()
var _fidget := ""
var _fidget_t := 0.0
var _fidget_side := 1.0
var _next_fidget := -1.0
var _idle_clock := 0.0


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for key: String in bones:
		_ids[key] = sk.find_bone(bones[key])


## 0 fresh .. 1 spent.
static func fatigue_of(damage: float) -> float:
	return clampf(damage / DAMAGE_FULL, 0.0, 1.0)


func _states_on() -> bool:
	match wrestler.fsm.current_state:
		WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN, \
				WrestlerFSM.State.STUNNED:
			return true
	return false


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or wrestler == null or not is_instance_valid(wrestler) or wrestler.fsm == null:
		return
	# Per-tick state, advanced once per physics tick however often the
	# skeleton redraws.
	var frame := Engine.get_physics_frames()
	var fatigue := fatigue_of(wrestler.combat.total_damage()) if wrestler.combat else 0.0
	var fired := wrestler.combat != null and wrestler.combat.is_fired_up()
	if frame != _last_frame:
		_last_frame = frame
		var on := _states_on() and not wrestler._model_held
		_weight = move_toward(_weight, 1.0 if on else 0.0, EASE)
		var bpm := lerpf(BREATH_FRESH, BREATH_SPENT, fatigue)
		_breath_clock += bpm / 60.0 / float(Engine.physics_ticks_per_second)
		_follow(sk)
		_tick_fidget()
	if _weight <= 0.0:
		return
	var to_skel := sk.global_basis.inverse()
	var up := (to_skel * Vector3.UP).normalized()
	var fwd := (to_skel * -wrestler.global_basis.z)
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var right := fwd.cross(up).normalized()   # nodding axis: + tips forward UP
	# Breathing: the chest rises (tips back) on the in-breath.
	var swing := deg_to_rad(lerpf(BREATH_DEG_FRESH, BREATH_DEG_SPENT, fatigue))
	var breath := sin(TAU * (_breath_clock + phase)) * swing
	# Slump, gone while he is fired up.
	var slump := 0.0 if fired else fatigue * fatigue
	var spine := deg_to_rad(SLUMP_SPINE_DEG) * slump
	var head_drop := deg_to_rad(SLUMP_HEAD_DEG) * slump
	var w := _weight
	_turn(sk, "spine_02", right, (-spine + breath) * 0.5 * w)
	_turn(sk, "spine_03", right, (-spine + breath) * 0.5 * w)
	# The head keeps level through the breath, and takes the look.
	_apply_fidget(sk, up, fwd, right)
	_turn(sk, "neck_01", up, _yaw * 0.4 * w)
	_turn(sk, "neck_01", right, (_pitch * 0.4 - breath * 0.6) * w)
	_turn(sk, "Head", up, _yaw * 0.6 * w)
	_turn(sk, "Head", right, (_pitch * 0.6 - head_drop - breath * 0.4) * w)


## Eases the look toward the other man's head, relative to the way the body
## faces.
func _follow(sk: Skeleton3D) -> void:
	var yaw := 0.0
	var pitch := 0.0
	var target := wrestler._opponent_eye_line()
	var head := int(_ids.get("Head", -1))
	if target != Vector3.INF and head >= 0:
		var from := sk.global_transform * sk.get_bone_global_pose(head).origin
		var to := target - from
		var fwd := -wrestler.global_basis.z
		fwd.y = 0.0
		var flat := Vector3(to.x, 0.0, to.z)
		if fwd.length() > 1e-3 and flat.length() > 1e-3:
			var a := fwd.normalized().signed_angle_to(flat.normalized(), Vector3.UP)
			if absf(a) < GIVE_UP:
				yaw = clampf(a, -MAX_YAW, MAX_YAW)
				pitch = clampf(atan2(to.y, flat.length()), -MAX_PITCH, MAX_PITCH)
	_yaw = lerpf(_yaw, yaw, FOLLOW)
	_pitch = lerpf(_pitch, pitch, FOLLOW)


func _turn(sk: Skeleton3D, key: String, axis: Vector3, angle: float) -> void:
	var b := int(_ids.get(key, -1))
	if b < 0 or absf(angle) < 1e-6:
		return
	var g := sk.get_bone_global_pose(b)
	g.basis = Basis(axis, angle) * g.basis
	sk.set_bone_global_pose(b, g)


## Standing still, a fidget now and then; anything else cuts it short.
func _tick_fidget() -> void:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	if _next_fidget < 0.0:
		_rng.seed = fidget_seed
		_next_fidget = _rng.randf_range(FIDGET_EVERY_MIN, FIDGET_EVERY_MAX)
	var idle := wrestler.fsm.current_state == WrestlerFSM.State.IDLE
	if _fidget != "":
		_fidget_t += dt / FIDGET_SECONDS
		if _fidget_t >= 1.0 or not idle:
			_fidget = ""
		return
	if not idle:
		return
	_idle_clock += dt
	if _idle_clock >= _next_fidget:
		_idle_clock = 0.0
		_next_fidget = _rng.randf_range(FIDGET_EVERY_MIN, FIDGET_EVERY_MAX)
		_fidget = ["shift", "neck", "bounce"][_rng.randi_range(0, 2)]
		_fidget_side = -1.0 if _rng.randf() < 0.5 else 1.0
		_fidget_t = 0.0


## 0 -> 1 -> 0 over a fidget, eased at both ends.
static func fidget_curve(t: float) -> float:
	return sin(PI * clampf(t, 0.0, 1.0)) ** 2


func _apply_fidget(sk: Skeleton3D, up: Vector3, fwd: Vector3, right: Vector3) -> void:
	if _fidget == "":
		return
	var k := fidget_curve(_fidget_t) * _weight
	match _fidget:
		"shift":
			# Hips over one leg; the chest leans a touch back the other way.
			_move(sk, "pelvis", right * SHIFT_M * _fidget_side * k)
			_turn(sk, "spine_02", fwd, deg_to_rad(3.0) * _fidget_side * k)
		"neck":
			# Head tipped to one side and rolled round.
			var s := sin(PI * _fidget_t)
			var c := cos(PI * _fidget_t)
			_turn(sk, "neck_01", fwd, deg_to_rad(NECK_ROLL_DEG) * _fidget_side * s * k)
			_turn(sk, "neck_01", right, -deg_to_rad(NECK_ROLL_DEG) * 0.5 * c * k)
		"bounce":
			# Two small bounces on the balls of his feet.
			var b := absf(sin(TAU * _fidget_t))
			_move(sk, "pelvis", -up * BOUNCE_M * b * _weight)


func _move(sk: Skeleton3D, key: String, by: Vector3) -> void:
	var b := int(_ids.get(key, -1))
	if b < 0:
		return
	var g := sk.get_bone_global_pose(b)
	g.origin += by
	sk.set_bone_global_pose(b, g)
