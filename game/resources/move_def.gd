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
@export var reversal_window_start: int = 0
@export var reversal_window_end: int = 0

## Damage dealt per limb if the move connects.
@export var damage_head: float = 0.0
@export var damage_torso: float = 0.0
@export var damage_arms: float = 0.0
@export var damage_legs: float = 0.0

@export var momentum_cost: float = 0.0
@export var momentum_gain: float = 0.0

## Minimum/maximum weight class allowed to perform this move.
@export var weight_class_min: int = 0
@export var weight_class_max: int = 2

## Opponent WrestlerFSM.State required for this move to be legal.
@export var required_opponent_state: int = -1

func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames

func is_in_reversal_window(frame_offset: int) -> bool:
	return frame_offset >= reversal_window_start and frame_offset <= reversal_window_end
