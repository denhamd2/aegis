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
## strike_jab.tres runs 20 ticks (0.333s) while the rig's `Punch_Jab` clip is
## 0.87s, so 38% of the punch played and the arm cross-faded back to idle
## still travelling forward.
##
## Measured on the rig, by sampling the clip's own tracks and running
## forward kinematics by hand (neither AnimationPlayer.seek() nor
## set_bone_pose_rotation() reaches get_bone_global_pose() in a `-s` script,
## so every naive sample reads back identical rest values): the jab is
## thrown with the left hand and the fist peaks **0.76m ahead of the
## wrestler's own origin at t=0.22s**, a quarter of the way into the clip.
## Everything after that is the arm coming back to a neutral stance, which
## the cross-fade to IDLE already does.
##
## gauntlet/refs/timings.md measures a real strike's startup -- windup to
## contact -- at ~4 frames of 30fps footage, 0.13s. This clip contacts at
## 0.22s. Retimed by 0.13/0.22 so the two agree: contact lands on tick 8,
## which is then what strike_jab.tres's startup_frames says, so the frame
## data and the animation finally describe the same punch.
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

const RECIPES := {
	# 0.87s * (0.13 / 0.22) = 0.514s = 31 ticks, which puts contact on tick 8.
	"strike_jab": {"kind": "retime", "source": "Punch_Jab", "seconds": 0.514},

	# The rig has no kick: 43 clips and not one of them throws a leg at
	# anything. It is assembled from the two poses that come closest,
	# located by running FK over every clip and reading the foot's height
	# and its offset ahead of the pelvis:
	#
	#   Jump_Start @ 0.33s -- foot at 0.66m, the highest knee lift on the
	#                         rig, but tucked under the hips (-0.04m fwd)
	#   Sprint     @ 0.53s -- same (left) leg extended 0.48m ahead of the
	#                         pelvis at 0.32m high
	#
	# One gives the chamber, the other the extension, and they are the same
	# leg, so together they read as a kick thrown rather than a stride
	# taken. The first version of this sampled Sprint at 0.57s instead,
	# which is the *right* foot 0.64m behind the pelvis -- rendering it
	# showed a man throwing a punch, because the only thing moving was
	# Sprint's arm swing.
	# The rig has no kick, and -- measured -- it has no pose to build one
	# out of either. Running FK over all 43 clips, the highest a foot ever
	# gets *relative to the hips* is -0.22m: Jump_Start's airborne tuck,
	# still below the pelvis. Sprint's "raised" foot is a stride at ground
	# level 0.48m in front. A first attempt stitched from those rendered as
	# a man throwing a punch, because the only thing that actually moved
	# was Sprint's arm swing.
	#
	# So the leg is posed rather than sampled, on top of a real standing
	# stance. The axis and angles are measured, not guessed -- rotating
	# thigh_l about each axis in turn and reading the foot back through FK:
	#
	#   thigh_l -70, calf_l +90 -> knee at hip height, foot tucked: chamber
	#   thigh_l -75, calf_l   0 -> foot 0.80m high and 0.78m forward, level
	#                              with the hips: a front kick to the body
	#   thigh_l -25, calf_l +25 -> foot just off the mat: the step
	#
	# Positive X on the spine leans the torso back, which is the
	# counter-balance a thrown leg needs to not read as falling forward.
	"strike_kick": {
		"kind": "stitch",
		"seconds": 0.583,
		"samples": [
			{"t": 0.000, "clip": "Idle", "at": 0.00},
			# Weight shifts onto the standing leg before the other leaves it.
			{"t": 0.067, "clip": "Idle", "at": 0.00,
				"bones": {"thigh_l": Vector3(-25, 0, 0), "calf_l": Vector3(25, 0, 0)}},
			# Chamber: knee up to hip height, heel tucked under.
			{"t": 0.100, "clip": "Idle", "at": 0.00,
				"bones": {"thigh_l": Vector3(-70, 0, 0), "calf_l": Vector3(90, 0, 0),
					"spine_01": Vector3(8, 0, 0)}},
			# Extension -- the contact frame, on tick 8 like the jab's, so
			# both strikes land exactly on their startup_frames.
			{"t": 0.133, "clip": "Idle", "at": 0.00,
				"bones": {"thigh_l": Vector3(-75, 0, 0), "spine_01": Vector3(12, 0, 0)}},
			# Re-chamber, then the leg comes back down under him.
			{"t": 0.220, "clip": "Idle", "at": 0.00,
				"bones": {"thigh_l": Vector3(-70, 0, 0), "calf_l": Vector3(90, 0, 0),
					"spine_01": Vector3(8, 0, 0)}},
			{"t": 0.360, "clip": "Idle", "at": 0.00,
				"bones": {"thigh_l": Vector3(-25, 0, 0), "calf_l": Vector3(25, 0, 0)}},
			{"t": 0.583, "clip": "Idle", "at": 0.00},
		],
	},

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
