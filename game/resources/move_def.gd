class_name MoveDef
extends Resource
## Tuning surface for a single move (strike, grapple, or paired move).
##
## This is the resource gauntlet builders edit to fix timing/feel gaps
## without touching code — a slice's largest gap is often "startup is 4
## frames too slow" rather than a logic bug.

## Identifier of the paired animation clip(s) this move drives.
@export var animation_pair_id: StringName

## Frame data, at the project's fixed 60 Hz tick.
@export var startup_frames: int = 6
@export var active_frames: int = 4
@export var recovery_frames: int = 10

## Reversal window, expressed as an inclusive frame range relative to
## move start. reversal_window_end must be >= reversal_window_start.
##
## Nothing reads these today. The reversal mechanic was removed with the
## paired counter animations it played (see MatchReferee's note on why),
## and these are kept because they are measured frame numbers -- the jab's
## 8-11 came off the clip's own contact frame, not off a preference -- and
## re-measuring them later is more work than carrying them.
@export var reversal_window_start: int = 0
@export var reversal_window_end: int = 0

## Damage dealt per limb if the move connects.
@export var damage_head: float = 0.0
@export var damage_torso: float = 0.0
@export var damage_arms: float = 0.0
@export var damage_legs: float = 0.0

## Where the striking limb actually is, in the wrestler's own local space,
## on the tick this move applies damage -- forward is -Z, matching the
## model's PI-Y mount in WrestlerController._install_character_model().
##
## Measured, never chosen: run
## `godot4 --headless -s res://tools/anim/measure_contact_offsets.gd` and
## paste what it prints. Re-run it after any change to the clip or to
## startup_frames, because it samples the clip at exactly that tick.
##
## This replaced a single 1.15 m sphere between the two capsule ORIGINS,
## shared by every strike in the game. Measured against the clips as played,
## the four strikes put their limb 0.42 / 0.55 / 0.82 / 0.82 m in front of
## the origin, so one range landed the jab through a third of a metre of
## clear air and cut both kicks short. It also asked nothing about direction,
## so a strike thrown while moving away from the opponent connected.
##
## Left at ZERO, the move falls back to that proximity test -- which is what
## the grapple and paired moves still want, since GrappleRig places both
## wrestlers itself and no limb of theirs is being aimed at anything.
@export var contact_offset: Vector3 = Vector3.ZERO

## Radius of the striking surface -- a fist is about 0.12, a boot 0.15. Zero
## means "this move has no authored contact volume", which is what selects
## the proximity fallback above.
@export var contact_radius: float = 0.0

@export var momentum_cost: float = 0.0
@export var momentum_gain: float = 0.0

## Minimum/maximum weight class allowed to perform this move.
@export var weight_class_min: int = 0
@export var weight_class_max: int = 2

## Whether this paired move ends with the defender lying on the mat.
##
## A grapple that does not knock a man down hands him a standing HIT_REACT,
## which is right for the clinch knee -- he finishes it on his feet -- and
## wrong for a slam, whose clip ends with him flat on his back: the next
## tick stood him straight up out of it. A move that sets this puts him in
## DOWN instead, for THROWN_DOWN_TICKS, whether or not it knocked him down.
## It is not a knockdown -- see WrestlerController._lie_down_after_throw().
@export var leaves_defender_down: bool = false

## Opponent WrestlerFSM.State required for this move to be legal.
@export var required_opponent_state: int = -1

func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames

func is_in_reversal_window(frame_offset: int) -> bool:
	return frame_offset >= reversal_window_start and frame_offset <= reversal_window_end
