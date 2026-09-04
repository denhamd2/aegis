class_name StrikeRecipes
extends RefCounted
## Declarative source for the single-character strike and hit-reaction
## clips, baked by tools/anim/build_strike_clips.gd.
##
## Strikes are not paired moves -- they don't go through GrappleRig, and each
## wrestler plays its own clip through its own AnimationTree
## (ARCHITECTURE.md, "GrappleRig owns paired moves"). But they had the same
## disease the paired moves had: the clip and the MoveDef disagreed about
## how long the move takes, and the FSM wins that argument.
##
## strike_jab.tres runs 20 ticks (0.333s) while a full punch clip is
## ~0.87s, so the arm cross-faded back to idle still travelling forward.
## The jab excerpt is therefore cut to 0.514s (31 ticks) with contact on
## tick 8, which is then what strike_jab.tres's startup_frames says, so the
## frame data and the animation finally describe the same punch.
##
## Measured on the old rig, by sampling the clip's own tracks and running
## forward kinematics by hand (neither AnimationPlayer.seek() nor
## set_bone_pose_rotation() reaches get_bone_global_pose() in a `-s` script,
## so every naive sample reads back identical rest values): the jab is
## thrown with the left hand and the fist peaks **0.76m ahead of the
## wrestler's own origin at t=0.22s**, a quarter of the way into the clip.
## Everything after that is the arm coming back to a neutral stance, which
## the cross-fade to IDLE already does.
##
## gauntlet/refs/timings.md measures a real strike's startup -- windup to
## contact -- at ~4 frames of 30fps footage, 0.13s. Every strike excerpt is
## cut so its contact lands at 0.13s for the same reason.
##
## Entry kinds:
##   trim    -- first `seconds` of the source, keys past it dropped. Keeps
##              every frame's timing exactly where it was.
##   retime  -- the whole source scaled to `seconds`. Changes pacing, so it
##              is only used where the pose matters and the timing does not.
##   stitch  -- a pose sequence sampled out of other clips, exactly as
##              resources/animations/paired_recipes.gd does it. For motions
##              the rig simply does not contain.

const LIBRARY := "strikes"

## Motion-captured sources (Motifect Martial Arts pack, retargeted onto the
## mannequin by retarget.py -- see assets/animations/ for the baked .glb
## intermediates, raw FBX deliberately not vendored per the pack's licence).
## A recipe with a "file" key samples the baked clip instead of the rig's
## own; trim/retime behave exactly as below. Baked excerpts are cut so the
## strike's contact lands 4 frames (0.133s) in, preserving the tick-8
## contact contract the Quaternius clips hold.
const MOTIFECT_JAB := "res://assets/animations/motifect_jab_raw.glb"
const MOTIFECT_KICK := "res://assets/animations/motifect_kick_raw.glb"
const MOTIFECT_DOUBLELEG := "res://assets/animations/motifect_doubleleg_raw.glb"

const RECIPES := {
	# Was a retimed Punch_Jab (contact tick 8 via 0.13/0.22). Now a real
	# punching excerpt: muay_thai_combination's hardest straight, baked
	# 0.567s with contact at 0.133s, trimmed to the same 0.514s/31 ticks.
	"strike_jab": {"kind": "trim", "file": MOTIFECT_JAB,
		"source": "motifect_jab_raw", "seconds": 0.514},

	# Was a stitched posed kick (Idle + thigh_l/calf_l offsets) -- the
	# "borrowed stance" the README apologises for. Now a real roundhouse
	# excerpt, baked 0.633s with peak extension at 0.133s, trimmed to the
	# same 0.583s so strike_kick.tres's tick-8 contact still holds.
	"strike_kick": {"kind": "trim", "file": MOTIFECT_KICK,
		"source": "motifect_kick_raw", "seconds": 0.583},

	# Double-leg takedown for the second running attack: first 1.333s of
	# the 5s clip (stance, level change, penetration), retimed to the
	# 69-tick (1.15s) running-attack window. Contact beat is an estimate --
	# the excerpt was aligned by hand-speed peak, not measured footage.
	"running_double_leg": {"kind": "retime", "file": MOTIFECT_DOUBLELEG,
		"source": "motifect_doubleleg_raw", "seconds": 1.15},

	# Both reactions are cut to exactly WrestlerController.HIT_REACT_TICKS
	# (20 ticks, 0.333s) so the clip ends as the state does. Hit_Chest is
	# already 0.33s and is trimmed by nothing; Hit_Head is 0.43s and loses
	# its tail.
	"hit_head": {"kind": "trim", "source": "Hit_Head", "seconds": 0.333},
	"hit_torso": {"kind": "trim", "source": "Hit_Chest", "seconds": 0.333},

	# STUNNED runs 45 ticks (0.75s) and Hit_Head is 0.43s, so the clip ended
	# and the pose froze for the remaining 19 ticks. Retimed rather than
	# trimmed: a stagger is the one case where slowing the motion down is
	# the point.
	"stunned": {"kind": "retime", "source": "Hit_Head", "seconds": 0.75},
}

## Clip name as registered on the wrestler's AnimationPlayer.
static func clip(name: String) -> String:
	if not RECIPES.has(name):
		return ""
	return "%s/%s" % [LIBRARY, name]

## Which reaction a landed move should produce, from where it did its
## damage. One clip for every hit -- a jab to the head and a slam to the
## ribs both played Hit_Chest -- was the reason a match read as two men
## flinching identically no matter what happened to them.
static func reaction_for(move: MoveDef) -> String:
	if not move:
		return clip("hit_torso")
	return clip("hit_head") if move.damage_head > move.damage_torso \
			else clip("hit_torso")
