class_name PairedRecipes
extends RefCounted
## Declarative source for the bone-level halves of every paired grapple move.
##
## `resources/animations/paired_moves.tres` animates only the two
## CharacterBody3D roots -- the throw *trajectory*. Each wrestler's skeleton
## was posed independently by a borrowed single-character clip that has no
## idea another body exists, so a throw was two rigid capsules on an arc
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

## The paired moveset, after the power, finisher and reversal moves were
## cut. Those three families were paired throws whose generated performances
## did not hold up on screen -- an inverted victim, a carried body, a
## counter that interrupted a strike mid-swing -- and a paired move that
## does not read is worse than no paired move at all, so they are gone:
## their MoveDefs, their trajectories, their baked clips and their wiring.
##
## What is left is a grapple that opens an exchange and two signatures. An
## AI match now spends its length trading strikes (resources/animations/
## strike_recipes.gd) rather than escalating a throw ladder -- see
## WrestlerAI, which grapples once and then only strikes.
const RECIPES := {
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
	# --- moves authored after the first five ----------------------------
	# Over the hip: A pivots and drops a shoulder, B goes over and lands
	# in front. Peak 1.28m at t=0.45 (raised from 1.05: the tucked-body
	# clearance gate caught the victim's head 0.16m under at t=0.53).
	"grapple_hiptoss": {
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.20, "clip": "PickUp_Table", "at": 0.25},
			{"t": 0.45, "clip": "Punch_Cross", "at": 0.50},
			{"t": 0.70, "clip": "Sword_Attack", "at": 0.80},
			{"t": 1.00, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.25, "clip": "Jump_Start", "at": 0.80},
			{"t": 0.45, "clip": "Roll", "at": 0.40},
			{"t": 0.70, "clip": "Death01", "at": 0.40},
			{"t": 1.00, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.30,
	},
	# Pulled over the shoulder into a seat. B never gets far off the mat,
	# so he stays braced most of the way rather than going limp early.
	"grapple_snapmare": {
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.22, "clip": "PickUp_Table", "at": 0.25},
			{"t": 0.50, "clip": "PickUp_Table", "at": 0.65},
			{"t": 0.75, "clip": "Jump_Land", "at": 0.20},
			{"t": 1.00, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.25, "clip": "Jump_Start", "at": 0.30},
			{"t": 0.45, "clip": "Roll", "at": 0.40},
			{"t": 0.70, "clip": "Sitting_Enter", "at": 0.60},
			{"t": 1.00, "clip": "Fixing_Kneeling", "at": 2.00},
		],
		"defender_grips_until": 0.45,
	},
	# Wrist control into a drag past the shoulder. Barely leaves the mat,
	# so both men stay on their feet the whole way through.
	"grapple_armdrag": {
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.25, "clip": "Punch_Cross", "at": 0.50},
			{"t": 0.55, "clip": "Push", "at": 0.40},
			{"t": 0.80, "clip": "Jump_Land", "at": 1.00},
			{"t": 1.00, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.22, "clip": "Hit_Chest", "at": 0.15},
			{"t": 0.45, "clip": "Roll", "at": 0.40},
			{"t": 0.70, "clip": "Death01", "at": 0.40},
			{"t": 1.00, "clip": "Death01", "at": 0.90},
		],
		"defender_grips_until": 0.35,
	},
	# Attacker drops backwards and snaps the head down beside him. Both
	# men finish low, which is what makes it read as a signature rather
	# than a basic.
	"signature_neckbreaker": {
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.25, "clip": "PickUp_Table", "at": 0.25},
			{"t": 0.55, "clip": "Sword_Attack", "at": 0.80},
			{"t": 0.75, "clip": "Fixing_Kneeling", "at": 2.00},
			{"t": 1.00, "clip": "Fixing_Kneeling", "at": 2.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.30, "clip": "Hit_Head", "at": 0.15},
			{"t": 0.55, "clip": "Roll", "at": 0.70},
			{"t": 0.75, "clip": "Death01", "at": 0.90},
			{"t": 1.00, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.35,
	},
}

## Root-transform trajectories for the moves authored after the original
## five. The first five moves' arcs were hand-keyed straight into
## `paired_moves.tres` and are left exactly as they are; everything added
## since is authored here and baked by `build_paired_moves.gd`, which adds
## its clips to that same library without touching the hand-keyed ones.
##
## A rotation key is [t, pitch, yaw, roll] in **degrees**, converted with
## Basis.from_euler's default YXZ order -- so yaw is world, and pitch and
## roll are applied in the wrestler's own frame afterwards. That makes a
## throw's flip a plain run of pitch values rather than a column of
## quaternions nobody can read or retune.
##
## Yaw is +90 for the wrestler starting at +0.40 X and -90 for the one at
## -0.40 X, which is what makes them face each other (Godot's forward is
## -Z; a +90 yaw maps -Z onto -X).
##
## A position key is [t, x, y, z] in metres, in the pair's own local space:
## +X is the axis between the two wrestlers, y = 0 is the mat, and the model
## origin is at the **feet**, so a body pitched flat at y = 0 hangs its whole
## length below the mat. Hence the invariant the generator enforces: any
## wrestler whose arc peaks at y >= 0.30 must have its last rotation key
## equal its first, so the flip resolves to a full 360 and he lands upright.
## That is exactly the bug that put suplex victims half a metre into the mat.
const TRAJECTORIES := {
	# --- grapple, basic tier -------------------------------------------
	# Over the hip and down in front of the attacker. Fast, low-ish arc.
	"grapple_hiptoss": {
		"length": 1.0,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.20, 0.36, 0.00, 0.00],
					[0.45, 0.31, 0.00, 0.00], [0.70, 0.33, 0.00, 0.00],
					[1.00, 0.36, 0.00, 0.00]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [0.45, 0.0, 66.0, 0.0],
					[0.70, 0.0, 98.0, 0.0], [1.00, 0.0, 90.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.25, -0.18, 0.38, 0.00],
					[0.45, 0.16, 1.28, 0.00], [0.70, 0.50, 0.75, 0.00],
					[0.88, 0.70, 0.05, 0.00], [1.00, 0.74, 0.00, 0.00]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [0.30, -70.0, -90.0, 0.0],
					[0.50, -160.0, -90.0, 0.0], [0.70, -260.0, -90.0, 0.0],
					[0.88, -360.0, -90.0, 0.0], [1.00, -360.0, -90.0, 0.0]],
		},
	},
	# Pulled over the shoulder and dumped seated alongside. Lowest arc of
	# the basic tier -- it is a transition, not a bomb.
	"grapple_snapmare": {
		"length": 1.0,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.22, 0.37, 0.00, 0.00],
					[0.50, 0.34, 0.00, 0.00], [0.75, 0.35, 0.00, 0.00],
					[1.00, 0.36, 0.00, 0.00]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [0.50, 0.0, 74.0, 0.0],
					[1.00, 0.0, 90.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.25, -0.15, 0.65, 0.00],
					[0.45, 0.20, 1.10, 0.00], [0.53, 0.28, 1.10, 0.00],
					[0.70, 0.45, 0.53, 0.00],
					[0.90, 0.55, 0.00, 0.00], [1.00, 0.55, 0.00, 0.00]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [0.35, -90.0, -90.0, 0.0],
					[0.55, -200.0, -90.0, 0.0], [0.78, -320.0, -90.0, 0.0],
					[0.90, -360.0, -90.0, 0.0], [1.00, -360.0, -90.0, 0.0]],
		},
	},
	# Wrist control into a drag past the shoulder. The flip completes at the
	# arc's peak (t≈0.47, root ≈1.1) rather than on the way down: a full
	# inversion finishing at 0.5m of root height puts the head through the
	# mat no matter how tucked the pose, which is what the clearance gate
	# kept catching here through two rounds of pure lifting.
	"grapple_armdrag": {
		"length": 1.0,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.25, 0.34, 0.00, 0.08],
					[0.55, 0.30, 0.00, 0.14], [0.80, 0.34, 0.00, 0.06],
					[1.00, 0.36, 0.00, 0.00]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [0.40, 0.0, 118.0, 0.0],
					[0.75, 0.0, 96.0, 0.0], [1.00, 0.0, 90.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.22, -0.10, 0.60, 0.16],
					[0.42, 0.10, 1.00, 0.40], [0.48, 0.12, 1.15, 0.45],
					[0.65, 0.18, 0.55, 0.60],
					[0.85, 0.20, 0.00, 0.70], [1.00, 0.20, 0.00, 0.70]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [0.35, -80.0, -90.0, 0.0],
					[0.52, -200.0, -90.0, 0.0], [0.80, -330.0, -90.0, 0.0],
					[0.90, -360.0, -90.0, 0.0], [1.00, -360.0, -90.0, 0.0]],
		},
	},

	# --- grapple, signature tier ---------------------------------------
	# Attacker drops back and snaps the head down beside him. Low arc,
	# both men end up near the mat.
	"signature_neckbreaker": {
		"length": 1.0,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.25, 0.38, 0.00, 0.00],
					[0.55, 0.30, 0.00, 0.00], [0.75, 0.22, 0.00, 0.00],
					[1.00, 0.22, 0.00, 0.00]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [0.55, 0.0, 76.0, 0.0],
					[1.00, 0.0, 88.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.30, -0.20, 0.48, 0.00],
					[0.50, 0.05, 1.01, 0.00], [0.60, 0.12, 1.03, 0.00],
					[0.72, 0.20, 0.48, 0.00],
					[0.88, 0.28, 0.00, 0.00], [1.00, 0.30, 0.00, 0.00]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [0.35, -70.0, -90.0, 0.0],
					[0.55, -180.0, -90.0, 0.0], [0.75, -290.0, -90.0, 0.0],
					[0.88, -360.0, -90.0, 0.0], [1.00, -360.0, -90.0, 0.0]],
		},
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
