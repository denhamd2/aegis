class_name HitFlinch
extends SkeletonModifier3D
## The body giving under a blow, from the side it came from
## (gauntlet/refs/animation_gap.md, Phase 3 "hit reactions").
##
## The match had two reaction clips, a head snap and a torso fold, both
## straight back whatever threw the punch, and only a man free to play one
## ever reacted: a man hit while throwing his own strike -- trading blows,
## the commonest exchange there is -- finished the swing without a flicker.
## This lays a flinch OVER whatever is playing, so it needs neither:
##
##   * direction: the upper body is tipped away from the attacker, about the
##     axis square to the line of the blow, with a turn away if it lands from
##     the side;
##   * height: a head shot snaps the neck and head, a body shot folds the
##     spine, a leg kick buckles the knee on the side it hit and drops the
##     hips;
##   * size: the move's damage scales it, up to MAX_STRENGTH.
##
## Each flinch reaches its peak in ATTACK_TICKS and springs back, slightly
## past rest and settled, over about a third of a second. Two blows in a row
## add. Presentation only (ARCHITECTURE.md): bones on the model, nothing read
## back into the match.

## Ticks from the blow to the flinch's peak: fast, or it reads as a lean.
const ATTACK_TICKS := 2.0
## How fast it dies after the peak (e-folding, ticks), and how it swings back.
const SETTLE_TICKS := 6.0
const RING := 0.35   # radians of phase per tick: one soft rebound
## Peak angles at full strength, in degrees.
const HEAD_DEG := 28.0
const BODY_DEG := 24.0
const LEGS_DEG := 30.0
## Damage that makes a full-strength flinch, and the most one blow may be.
const FULL_DAMAGE := 10.0
const MAX_STRENGTH := 1.3

## Game bone names, resolved by the controller.
var bones := {
	"pelvis": "pelvis", "spine_01": "spine_01", "spine_02": "spine_02",
	"spine_03": "spine_03", "neck_01": "neck_01", "Head": "Head",
	"thigh_l": "thigh_l", "calf_l": "calf_l", "thigh_r": "thigh_r", "calf_r": "calf_r",
}
## Who is flinching: the body whose frame a blow's direction is read in.
var body: Node3D

## Active flinches: {start, axis (world), twist, zone, strength, side}.
var _hits: Array[Dictionary] = []
var _ids := {}


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for key: String in bones:
		_ids[key] = sk.find_bone(bones[key])


## A blow from `from` (world position of the man throwing it) at `zone`
## ("head", "body" or "legs"), `strength` 0..MAX_STRENGTH.
func hit(from: Vector3, zone: String, strength: float) -> void:
	if body == null or strength <= 0.0:
		return
	var away := body.global_position - from
	away.y = 0.0
	if away.length() < 1e-3:
		away = body.global_basis.z
	away = away.normalized()
	# Tip the top away from the blow: rotate about the horizontal axis square
	# to it. The share of the blow across his chest turns him, too.
	var axis := Vector3.UP.cross(away).normalized()
	var facing := -body.global_basis.z
	facing.y = 0.0
	var across := facing.normalized().cross(away).y if facing.length() > 1e-3 else 0.0
	# Which leg a kick lands on: the one nearer the kicker.
	var right := body.global_basis.x
	var side := "l" if right.dot(-away) < 0.0 else "r"
	_hits.append({"start": Engine.get_physics_frames(), "axis": axis, "twist": across,
			"zone": zone, "strength": minf(strength, MAX_STRENGTH), "side": side})
	if _hits.size() > 4:
		_hits.pop_front()


## Zone and strength for `move`, from where its damage lands.
static func zone_of(move: MoveDef) -> String:
	if move == null:
		return "body"
	if move.damage_legs > maxf(move.damage_head, move.damage_torso):
		return "legs"
	return "head" if move.damage_head > move.damage_torso else "body"


static func strength_of(move: MoveDef) -> float:
	if move == null:
		return 0.5
	var total := move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs
	return clampf(total / FULL_DAMAGE, 0.35, MAX_STRENGTH)


## The flinch's size at `t` ticks after the blow: up to 1, back through
## zero with a small rebound, to rest.
static func envelope(t: float) -> float:
	if t < 0.0:
		return 0.0
	if t < ATTACK_TICKS:
		var s := t / ATTACK_TICKS
		return s * s * (3.0 - 2.0 * s)
	var u := t - ATTACK_TICKS
	return exp(-u / SETTLE_TICKS) * cos(u * RING)


func is_flinching() -> bool:
	return not _hits.is_empty()


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _hits.is_empty() or body == null:
		return
	var now := float(Engine.get_physics_frames()) + Engine.get_physics_interpolation_fraction()
	var to_skel := sk.global_basis.inverse()
	var done: Array[Dictionary] = []
	# Summed per bone as axis-angle in skeleton space, then applied parents
	# first so each bone adds its own share on top of the one above it.
	var turns := {}
	for h: Dictionary in _hits:
		var t := now - float(h["start"])
		if t > ATTACK_TICKS + SETTLE_TICKS * 6.0:
			done.append(h)
			continue
		var e := envelope(t) * float(h["strength"])
		var axis: Vector3 = (to_skel * (h["axis"] as Vector3)).normalized()
		var up := (to_skel * Vector3.UP).normalized()
		var twist: float = h["twist"]
		match h["zone"]:
			"head":
				_add(turns, "spine_03", axis * deg_to_rad(HEAD_DEG) * 0.2 * e)
				_add(turns, "neck_01", axis * deg_to_rad(HEAD_DEG) * 0.35 * e + up * twist * 0.25 * e)
				_add(turns, "Head", axis * deg_to_rad(HEAD_DEG) * 0.45 * e + up * twist * 0.35 * e)
			"body":
				_add(turns, "spine_01", axis * deg_to_rad(BODY_DEG) * 0.3 * e)
				_add(turns, "spine_02", axis * deg_to_rad(BODY_DEG) * 0.4 * e + up * twist * 0.15 * e)
				_add(turns, "spine_03", axis * deg_to_rad(BODY_DEG) * 0.3 * e + up * twist * 0.15 * e)
				# The head lags the chest: a little back the other way.
				_add(turns, "Head", -axis * deg_to_rad(BODY_DEG) * 0.15 * e)
			"legs":
				# The struck knee gives: the thigh swings forward, the shin
				# back, and the hips drop to the side of it.
				var side: String = h["side"]
				var knee_axis := (to_skel * body.global_basis.x).normalized()
				var bend := deg_to_rad(LEGS_DEG) * e
				_add(turns, "thigh_" + side, -knee_axis * bend * 0.6)
				_add(turns, "calf_" + side, knee_axis * bend * 1.2)
				_add(turns, "spine_02", axis * deg_to_rad(BODY_DEG) * 0.25 * e)
	for h in done:
		_hits.erase(h)
	for key: String in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
			"thigh_l", "calf_l", "thigh_r", "calf_r"]:
		if not turns.has(key) or int(_ids.get(key, -1)) < 0:
			continue
		var v: Vector3 = turns[key]
		var angle := v.length()
		if angle < 1e-5:
			continue
		var b: int = _ids[key]
		var g := sk.get_bone_global_pose(b)
		g.basis = Basis(v / angle, angle) * g.basis
		sk.set_bone_global_pose(b, g)


static func _add(turns: Dictionary, key: String, v: Vector3) -> void:
	turns[key] = (turns.get(key, Vector3.ZERO) as Vector3) + v
