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
## contact -- at ~4 frames of 30fps footage, 0.13s. That is a *jab's*
## startup, and the jab and the roundhouse are cut to land on it. The two
## heavier strikes added since (strike_cross, strike_kick_heavy) land later
## on purpose, each at its own measured contact frame: a match made of one
## startup value is a match made of one strike.
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
	# BACK to the rig's own Punch_Jab, and the mocap excerpt that replaced it
	# is gone. Measured with tools/probe/strike_clip_probe.tscn on the BASE
	# rig -- no retarget in the path at all -- the baked jab put the head
	# BELOW the hips on 21 of its 31 frames, worst 0.258 m under. Rendered,
	# that frame is a wrestler curled into a ball floating at rope height.
	# strike_cross, the one strike drawn from the rig's own library, measured
	# clean through the identical code path, which is what points at the
	# baked excerpts rather than the pipeline.
	#
	# It is a revert rather than a re-bake because a re-bake is not available:
	# the retarget.py this file used to credit is not in the repo, and the
	# source FBX was deliberately not vendored. Nothing here can reproduce
	# those .glb intermediates, so the choice was a broken clip or the plainer
	# one it replaced.
	#
	# Punch_Cross, not Punch_Jab: this rig HAS no Punch_Jab. The measurements
	# further up this file that name one were taken "on the old rig", and the
	# current wrestler_base.glb carries exactly one punch in its 42 clips.
	# Reverting the recipe verbatim from history failed loudly on that --
	# "source clip 'Punch_Jab' is not on the rig" -- which is the build script
	# doing its job.
	#
	# So the jab and the cross are now the same motion at two speeds, which
	# this file elsewhere calls out as a thing to avoid, and it is still the
	# better of the two options available: the alternative on the table was a
	# clip that renders as a ball of limbs at rope height. Worth replacing if a
	# real jab is ever sourced -- that is a missing ASSET, not a bug.
	#
	# Punch_Cross's contact is measured at t=0.300s of its 1.0s length
	# (tools/anim/measure_strike_contact.gd). Retimed to 0.514s / 31 ticks that
	# lands at 0.154s -- tick 9, not the tick 8 the old excerpt hit -- so
	# strike_jab.tres moves its startup_frames to 9 and gives the tick back out
	# of recovery, keeping the move 31 ticks and the clip exactly as long as
	# the state that plays it.
	"strike_jab": {"kind": "retime", "source": "Punch_Cross", "seconds": 0.514},

	# BACK to the stitched posed kick, for the same reason as the jab above:
	# the baked roundhouse put the head below the hips on every one of its 35
	# frames, worst 0.390 m under, and renders as a collapsed blob on the mat.
	# This is the "borrowed stance" the README apologises for, and a borrowed
	# stance that stands upright beats a real one that does not.
	#
	# The rig has no kick: 43 clips and not one of them throws a leg at
	# anything, and -- measured -- it has no pose to build one out of either.
	# Running FK over all 43, the highest a foot ever gets relative to the
	# hips is -0.22m (Jump_Start's airborne tuck), still below the pelvis.
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

	# !! KNOWN BROKEN, and left that way deliberately. This is the last recipe
	# still sourced from the mocap bake, and it has the same fault the three
	# strikes above were reverted off: measured with
	# tools/probe/strike_clip_probe.tscn, head below hips on 59 of its 69
	# frames, worst 0.268 m under.
	#
	# Not fixed here for two reasons. It cannot be re-baked -- retarget.py is
	# not in the repo and the source FBX was never vendored -- and it cannot
	# currently be SEEN: RUNNING_ATTACK fires zero times in an AI match,
	# because input["run"] is only ever set by the whip decision inside
	# GRAPPLE_HOLD (see gauntlet/status/roman_reigns_next.md, "The AI never
	# runs in open play"). Replacing it means authoring a stitched takedown
	# blind, against a state nothing reaches. That is its own piece of work,
	# and it belongs with the fix that makes the AI run.
	#
	# Double-leg takedown for the second running attack: first 1.333s of
	# the 5s clip (stance, level change, penetration), retimed to the
	# 69-tick (1.15s) running-attack window. Contact beat is an estimate --
	# the excerpt was aligned by hand-speed peak, not measured footage.
	"running_double_leg": {"kind": "retime", "file": MOTIFECT_DOUBLELEG,
		"source": "motifect_doubleleg_raw", "seconds": 1.15},

	# The second punch, and the only strike drawn from the rig's own
	# library rather than the mocap pack: Punch_Cross is a real cross, a
	# visibly different punch from the mocap jab rather than the same
	# motion replayed at another speed.
	#
	# Measured with tools/anim/measure_strike_contact.gd rather than
	# guessed -- the right fist peaks 0.683m in front of the pelvis at
	# t=0.300s of the 1.0s clip, and nothing else in it reaches half that.
	# Retimed by exactly 2/3 (0.667s), which puts that contact frame on
	# tick 12 and is what strike_cross.tres's startup_frames says. A cross
	# lands later than the 4-frame jab because it is a bigger punch; the
	# 0.133s figure in gauntlet/refs/timings.md is a jab's startup, not
	# every strike's.
	"strike_cross": {"kind": "retime", "source": "Punch_Cross",
		"seconds": 0.667},

	# The heavy kick: the same posed kick as strike_kick, thrown slower. It
	# used to retime the mocap roundhouse, which measured head-below-hips on
	# all 57 of its frames -- the worst of the three.
	#
	# Written out as its own stitch rather than retimed, because "retime"
	# scales a clip from the RIG's library and this kick is not one: it is
	# assembled here. The sample times are stretched so the contact frame
	# lands at 0.200s -- tick 12, which is what strike_kick_heavy.tres's
	# startup_frames says -- rather than by scaling everything uniformly,
	# which would have put it on tick 13.
	"strike_kick_heavy": {
		"kind": "stitch",
		"seconds": 0.950,
		"samples": [
			{"t": 0.000, "clip": "Idle", "at": 0.00},
			{"t": 0.100, "clip": "Idle", "at": 0.00,
				"bones": {"thigh_l": Vector3(-25, 0, 0), "calf_l": Vector3(25, 0, 0)}},
			{"t": 0.150, "clip": "Idle", "at": 0.00,
				"bones": {"thigh_l": Vector3(-70, 0, 0), "calf_l": Vector3(90, 0, 0),
					"spine_01": Vector3(8, 0, 0)}},
			# Contact, on tick 12.
			{"t": 0.200, "clip": "Idle", "at": 0.00,
				"bones": {"thigh_l": Vector3(-75, 0, 0), "spine_01": Vector3(12, 0, 0)}},
			{"t": 0.360, "clip": "Idle", "at": 0.00,
				"bones": {"thigh_l": Vector3(-70, 0, 0), "calf_l": Vector3(90, 0, 0),
					"spine_01": Vector3(8, 0, 0)}},
			{"t": 0.590, "clip": "Idle", "at": 0.00,
				"bones": {"thigh_l": Vector3(-25, 0, 0), "calf_l": Vector3(25, 0, 0)}},
			{"t": 0.950, "clip": "Idle", "at": 0.00},
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

	# The cover. PIN_ATTACKER played "Crouch_Idle", which is a man crouching
	# on his own -- so a captured three-count showed the attacker standing
	# beside the fallen man with a boot through his head while the referee
	# counted. Nothing about it read as a pin.
	#
	# A stitch rather than a clip choice, because the rig has no cover in it.
	# Sitting_Enter at 0.60 was tried first and rendered as a man bent at the
	# waist but still standing on both feet, so the base is Fixing_Kneeling at
	# 2.00 ("kneeling, settled" in the reference table paired_recipes.gd
	# keeps), which is already down on the mat. The offsets below carry it the
	# rest of the way -- the spine pitched over the man on the mat and the arms
	# brought in to press his shoulders.
	#
	# One sample, held. PIN_ATTACKER is a state the referee holds for the
	# whole count rather than a move with a beat, and a stitched clip keeps
	# its last pose, so a single pose at t=0 is the cover for as long as the
	# count runs. The 0.6s length only has to outlast the cross-fade in.
	#
	# The pose alone is half the fix; without the placement in
	# WrestlerController.begin_pin() the attacker still covers thin air
	# wherever he happened to be standing.
	# The getup. GETUP played "Roll", which is a tucked forward roll: measured
	# against the state it fills, the clip is 1.467s and GETUP_RISE_TICKS is
	# 126 (2.10s), so the wrestler curled into a ball on the mat and then FROZE
	# in it for the remaining 0.63s. In a captured match that is a man landing
	# from a throw, becoming a compact ball for about half a second, and then
	# popping upright -- which is what "the downed wrestler crumples" turns out
	# to be. It is the same clip-shorter-than-its-state disease as "stunned"
	# above, except the pose it freezes in is a ball rather than a stagger.
	#
	# Stitched into an actual rise, because the rig has no getup either: prone,
	# up onto a knee, into a crouch, standing. Every pose is a real frame of a
	# real clip (see the reference table in paired_recipes.gd).
	#
	# Authored at the DEFAULT rise, 2.10s, not the input-driven fast one
	# (GETUP_RISE_FAST_TICKS, 68 ticks / 1.14s). One clip cannot be both, and
	# this is the choice that fails better: a fast rise truncates it around the
	# crouch, which reads as scrambling up quicker, whereas authoring it short
	# would leave the slow rise frozen standing for a second -- and freezing is
	# the bug being fixed.
	"getup_rise": {
		"kind": "stitch", "seconds": 2.10,
		"samples": [
			{"t": 0.00, "clip": "Death01", "at": 1.60},       # settled prone
			{"t": 0.70, "clip": "Death01", "at": 0.90},       # on the ground
			{"t": 1.25, "clip": "Fixing_Kneeling", "at": 2.00},  # onto a knee
			{"t": 1.70, "clip": "Crouch_Idle", "at": 1.00},   # crouched
			{"t": 2.10, "clip": "Idle", "at": 0.00},          # on his feet
		],
	},

	"pin_cover": {
		"kind": "stitch", "seconds": 0.6,
		"samples": [
			{"t": 0.0, "clip": "Fixing_Kneeling", "at": 2.00, "bones": {
				# Down over the opponent rather than upright off the mat.
				"spine_01": Vector3(22.0, 0.0, 0.0),
				"spine_02": Vector3(18.0, 0.0, 0.0),
				"spine_03": Vector3(12.0, 0.0, 0.0),
				# Both arms reaching down to the shoulders he is holding.
				"upperarm_l": Vector3(0.0, 0.0, -38.0),
				"upperarm_r": Vector3(0.0, 0.0, 38.0),
				"lowerarm_l": Vector3(0.0, 0.0, -20.0),
				"lowerarm_r": Vector3(0.0, 0.0, 20.0),
				# Watching the shoulders, not the lights.
				"neck_01": Vector3(12.0, 0.0, 0.0),
			}},
		],
	},
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
