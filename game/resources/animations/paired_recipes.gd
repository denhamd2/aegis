class_name PairedRecipes
extends RefCounted
## Declarative source for the bone-level halves of every paired grapple move.
##
## `resources/animations/paired_moves.tres` animates only the two
## CharacterBody3D roots -- the throw *trajectory*. Each wrestler's skeleton
## was posed independently by a borrowed single-character clip that has no
## idea another body exists, so a suplex was two rigid capsules on an arc
## with an unrelated gesture playing inside each of them.
##
## This file is the other half: per move, per role, a sequence of poses that
## `build_paired_poses.gd` bakes into real bone tracks. A pose is not typed
## out as quaternions -- it is *sampled* from a frame of one of the 43 clips
## on the CC0 rig, so every pose in the output is a real frame of real
## animation rather than 55 hand-guessed rotations. The recipe only chooses
## which frames, in what order, and how they are nudged.
##
## This is the tuning surface, in the same spirit as MoveDef: retiming a
## throw's load or softening a landing is an edit here plus a re-run of the
## generator, not a code change.
##
## Sample fields:
##   t      -- time in the output clip, in seconds. Output length matches the
##             move's root track in paired_moves.tres (1.0s for all of them),
##             so `t` lines the pose up with a beat of the trajectory.
##   clip   -- source clip on wrestler_base.glb. Note the glTF importer
##             strips the `_Loop` suffix: the clip authored as `Push_Loop`
##             is named `Push` here.
##   at     -- time within that source clip to sample, in seconds.
##   bones  -- optional per-bone Euler offsets in degrees, applied on top of
##             the sampled rotation. For poses the library simply does not
##             contain (an inverted victim, a deeper drive).
##   pelvis -- optional Vector3 offset on the sampled pelvis position, in
##             metres, for raising or dropping the whole body in its own
##             skeleton space.
##
## Reference frames used when picking `at` values, measured off the rig:
##   Push (2.667s)            0.8  braced two-armed shove
##   PickUp_Table (0.833s)    0.05 upright · 0.25 bent · 0.45 grip
##                            0.65 driving up · 0.80 upright holding
##   Jump_Start (1.333s)      0.30 crouch load · 0.80 extension
##   Jump (2.5s)              0.50 airborne, legs trailing
##   Jump_Land (1.267s)       0.20 contact · 0.50 deep absorb · 1.00 recover
##   Death01 (2.4s)           0.10 stagger · 0.40 falling · 0.90 ground
##                            1.60 settled prone
##   Roll (1.467s)            0.40 tucked · 0.70 inverted
##   Fixing_Kneeling (5.2s)   2.00 kneeling, settled
##   Crouch_Idle (2.933s)     1.00 crouched
##   Hit_Chest (0.333s)       0.15 recoil
##   Sword_Attack (1.533s)    0.40 overhead wind-up · 0.80 swing down
##   Sitting_Enter (1.3s)     0.60 knees bent, torso forward
##   Punch_Cross (1.0s)       0.50 torso twist
##   Idle (2.5s)              0.00 neutral standing

## Suffixes appended to a move's animation_pair_id to name its two role
## clips. Shared with wrestler_controller.gd so the two cannot drift.
const ATTACKER_SUFFIX := "__attacker"
const DEFENDER_SUFFIX := "__defender"

## Library name the generated clips are registered under on each wrestler's
## AnimationPlayer, so they never collide with the .glb's own clips.
const LIBRARY := "paired"

const RECIPES := {
	# A dips, drives up, arches back; B rises to 2.4m overhead and comes
	# down behind. Root arc: B peaks at t=0.52, lands by t=0.88.
	"grapple_suplex": {
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.18, "clip": "PickUp_Table", "at": 0.25},
			{"t": 0.32, "clip": "PickUp_Table", "at": 0.45},
			# Overhead rather than PickUp_Table's waist-height carry: by this
			# beat the victim's hips are at 1.6m and a carry pose leaves the
			# attacker's arms clamped at full stretch below him, which reads
			# as him having let go at the apex.
			{"t": 0.52, "clip": "Sword_Attack", "at": 0.40},
			{"t": 0.72, "clip": "Jump_Land", "at": 0.50},
			{"t": 1.00, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.30, "clip": "Jump", "at": 0.50},
			{"t": 0.52, "clip": "Death01", "at": 0.40},
			{"t": 0.82, "clip": "Death01", "at": 0.90},
			{"t": 1.00, "clip": "Death01", "at": 1.60},
		],
		# Hooked round the attacker's waist on the way up, then let go.
		"defender_grips_until": 0.45,
	},
	# A drops to one knee; B is folded across it. B peaks at 1.55m, lands
	# forward at +0.65 X.
	"signature_backbreaker": {
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.20, "clip": "PickUp_Table", "at": 0.25},
			{"t": 0.35, "clip": "PickUp_Table", "at": 0.60},
			{"t": 0.52, "clip": "PickUp_Table", "at": 0.80},
			{"t": 0.72, "clip": "Fixing_Kneeling", "at": 2.00},
			{"t": 1.00, "clip": "Crouch_Idle", "at": 1.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.30, "clip": "Jump", "at": 0.50},
			{"t": 0.52, "clip": "Roll", "at": 0.70},
			{"t": 0.72, "clip": "Hit_Chest", "at": 0.15},
			{"t": 1.00, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.40,
	},
	# A turns and slams B sideways to the mat at +0.70 Z. B peaks at 1.25m.
	"power_bodyslam": {
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.15, "clip": "PickUp_Table", "at": 0.25},
			{"t": 0.30, "clip": "PickUp_Table", "at": 0.65},
			{"t": 0.45, "clip": "Sword_Attack", "at": 0.40},
			{"t": 0.65, "clip": "Sword_Attack", "at": 0.80},
			{"t": 1.00, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.15, "clip": "Jump_Start", "at": 0.30},
			{"t": 0.45, "clip": "Jump", "at": 0.50},
			{"t": 0.65, "clip": "Death01", "at": 0.90},
			{"t": 1.00, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.30,
	},
	# A drops to his knees driving B down head-first. B peaks inverted at
	# 2.2m and is driven into the mat by t=0.88.
	"finisher_piledriver": {
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.18, "clip": "PickUp_Table", "at": 0.25},
			{"t": 0.38, "clip": "PickUp_Table", "at": 0.65},
			{"t": 0.50, "clip": "PickUp_Table", "at": 0.80},
			{"t": 0.68, "clip": "Sitting_Enter", "at": 0.60},
			{"t": 0.85, "clip": "Fixing_Kneeling", "at": 2.00},
			{"t": 1.00, "clip": "Fixing_Kneeling", "at": 2.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.18, "clip": "Jump_Start", "at": 0.30},
			{"t": 0.50, "clip": "Roll", "at": 0.70},
			{"t": 0.80, "clip": "Death01", "at": 0.90},
			{"t": 1.00, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.35,
	},
	# The one move where B wins the exchange: A turns out of the lock-up and
	# B is shoved clear to -0.90 X. Nobody is lifted, so nobody goes limp.
	"reversal_counter": {
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.20, "clip": "Punch_Cross", "at": 0.50},
			{"t": 0.40, "clip": "Push", "at": 0.40},
			{"t": 0.70, "clip": "Push", "at": 1.20},
			{"t": 1.00, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.15, "clip": "Hit_Chest", "at": 0.15},
			{"t": 0.40, "clip": "Jump_Land", "at": 0.20},
			{"t": 0.70, "clip": "Jump_Land", "at": 1.00},
			{"t": 1.00, "clip": "Idle", "at": 0.00},
		],
		"defender_grips_until": 0.20,
	},
}

## Clip name for one role's half of a move, as registered on the wrestler's
## AnimationPlayer. Returns "" for a move with no recipe, which is the
## caller's cue to fall back to a borrowed single-character clip.
static func role_clip(move_id: StringName, is_attacker: bool) -> String:
	if not RECIPES.has(String(move_id)):
		return ""
	var suffix := ATTACKER_SUFFIX if is_attacker else DEFENDER_SUFFIX
	return "%s/%s%s" % [LIBRARY, move_id, suffix]

## How long into the move the defender keeps hold of the attacker, as a
## fraction of the clip. Past it he has been thrown and his arms go loose;
## a move he is never lifted in keeps him gripping for its whole length.
static func defender_grip_until(move_id: StringName) -> float:
	if not RECIPES.has(String(move_id)):
		return 0.0
	return RECIPES[String(move_id)].get("defender_grips_until", 0.0)
