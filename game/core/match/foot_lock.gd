class_name FootLock
extends SkeletonModifier3D
## Feet that stay where they are put (gauntlet/refs/animation_gap.md, Phase 3
## "foot IK").
##
## Measured over two AI matches (tools/probe/foot_skate.tscn), a planted foot
## slid 77 cm for every second it was on the mat: 3.7 m/s circling (one walk
## clip, played while he strafes in every direction), 0.5 m/s standing (the
## body turns to face the other man and the feet swivel with it), 2.6 m/s
## getting up. The clips plant their feet; nothing held them there.
##
## So, per foot:
##   * PLANTED where the clip puts the ankle at standing height: the foot is
##     pinned to the canvas where it landed and two-bone leg IK bends the leg
##     to it, whatever the body does above;
##   * LET GO when the clip lifts the foot: it blends back onto the clip's
##     swing and lands again wherever the clip sets it down;
##   * a STEP when the body has drifted too far off a planted foot -- turning
##     on the spot, shoved back by a blow: it lifts and sets down under him,
##     one foot at a time. A man knocked back staggers instead of sliding.
##
## Off during the walk-in (FootPlant has it), lying down and getting up: the
## getup clips kneel and step, and pinning fought them -- the knees jerked
## (transition_pops --world) worse than the feet had slid. Presentation only (ARCHITECTURE.md).

## The clip's ankle within this of its standing height counts as planted.
const PLANT_MARGIN := 0.035
## Drift off a planted foot that starts a step, metres.
const STEP_DRIFT := 0.14
## Ticks a step takes, and how high it lifts.
const STEP_TICKS := 8.0
const STEP_LIFT := 0.07
## A pin further than this from the clip's foot is let go at once.
const RELEASE_CUT := 0.2
## Ticks to hand a foot back to the clip, or to take one over.
const BLEND_TICKS := 7.0

var legs: Array = [["thigh_l", "calf_l", "foot_l"], ["thigh_r", "calf_r", "foot_r"]]
var wrestler: WrestlerController

var _ids: Array = []
var _ankle_rest := 0.1
var _feet: Array[Dictionary] = []
var _last_frame := -1


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for leg: Array in legs:
		var ids := []
		for bone: String in leg:
			ids.append(sk.find_bone(bone))
		if ids.has(-1):
			_ids.clear()
			return
		_ids.append(ids)
	for side in 2:
		_feet.append({"locked": false, "at": Transform3D(), "weight": 0.0,
				"stepping": false, "from": Transform3D(), "t": 0.0})


func _states_on() -> bool:
	if wrestler.foot_plant and (wrestler.foot_plant.is_walking() or wrestler.foot_plant._release > 0):
		return false
	match wrestler.fsm.current_state:
		WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN, \
				WrestlerFSM.State.STRIKE, WrestlerFSM.State.HIT_REACT, WrestlerFSM.State.STUNNED, \
				WrestlerFSM.State.TIE_UP, WrestlerFSM.State.GRAPPLE_HOLD:
			return true
	return false


## The ankle's standing height above the body's origin, from the rest pose.
func _standing_height(sk: Skeleton3D) -> float:
	var rest := sk.global_transform * sk.get_bone_global_rest(_ids[0][2]).origin
	return rest.y - sk.global_transform.origin.y


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _ids.size() != 2 or wrestler == null or wrestler.fsm == null:
		return
	var homes: Array[Transform3D] = []
	for side in 2:
		homes.append(sk.global_transform * sk.get_bone_global_pose(_ids[side][2]))
	var frame := Engine.get_physics_frames()
	if frame != _last_frame:
		_last_frame = frame
		_ankle_rest = _standing_height(sk)
		_tick(homes)
	for side in 2:
		var f: Dictionary = _feet[side]
		var w: float = f["weight"]
		if w <= 0.0:
			continue
		var want: Transform3D = f["at"]
		if f["stepping"]:
			var s := clampf(float(f["t"]) / STEP_TICKS, 0.0, 1.0)
			var e := s * s * (3.0 - 2.0 * s)
			want = GrappleRig.blend_transforms(f["from"], homes[side], e)
			want.origin.y = lerpf((f["from"] as Transform3D).origin.y, homes[side].origin.y, e) \
					+ STEP_LIFT * sin(PI * s)
		# Eased, so a foot neither leaves the clip nor rejoins it with a jolt.
		var target := GrappleRig.blend_transforms(homes[side], want, w * w * (3.0 - 2.0 * w))
		FootPlant._solve_leg(sk, _ids[side], sk.global_transform.affine_inverse() * target,
				sk.global_basis.inverse() * -wrestler.global_basis.z)


## One physics tick of each foot's plant, release and step.
func _tick(homes: Array[Transform3D]) -> void:
	var on := _states_on()
	var ground := wrestler.global_position.y + _ankle_rest + PLANT_MARGIN
	var someone_stepping: bool = _feet[0]["stepping"] or _feet[1]["stepping"]
	for side in 2:
		var f: Dictionary = _feet[side]
		var home := homes[side]
		var planted := home.origin.y <= ground
		if not on:
			# Faded out where the clip's foot is still near the pin; cut where
			# it is not -- a man turned round as he goes down has his feet on
			# the other side, and fading dragged his legs back across.
			var gone := (home.origin - (f["at"] as Transform3D).origin).length() > RELEASE_CUT
			f["locked"] = false
			f["stepping"] = false
			f["weight"] = 0.0 if gone else maxf(0.0, float(f["weight"]) - 1.0 / BLEND_TICKS)
			continue
		if f["stepping"]:
			f["t"] = float(f["t"]) + 1.0
			if float(f["t"]) >= STEP_TICKS:
				# Down: planted where the clip has the foot now.
				f["stepping"] = false
				f["locked"] = planted
				f["at"] = home
				if not planted:
					f["weight"] = 0.0
			continue
		if f["locked"]:
			if not planted:
				# The clip lifts it: hand it back over a few ticks, from where it
				# stood.
				f["locked"] = false
				continue
			var drift := Vector2(home.origin.x - f["at"].origin.x, home.origin.z - f["at"].origin.z).length()
			if drift > STEP_DRIFT and not someone_stepping:
				f["stepping"] = true
				f["from"] = f["at"]
				f["t"] = 0.0
				someone_stepping = true
			f["weight"] = minf(1.0, float(f["weight"]) + 1.0 / BLEND_TICKS)
		elif planted:
			# Landing: pinned where it touched down, taken over gradually so the
			# first tick is exactly the clip's.
			f["locked"] = true
			f["at"] = home
			f["weight"] = minf(1.0, float(f["weight"]) + 1.0 / BLEND_TICKS)
		else:
			f["weight"] = maxf(0.0, float(f["weight"]) - 1.0 / BLEND_TICKS)
