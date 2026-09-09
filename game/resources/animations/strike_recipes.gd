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

	# The heavy kick: the same measured roundhouse as strike_kick, played
	# at two thirds speed (1.5x its 0.633s bake, so 0.950s). Retiming
	# scales the contact frame with everything else -- 0.133s * 1.5 =
	# 0.200s, tick 12 -- which is what strike_kick_heavy.tres says. It is
	# the one strike in the set that is genuinely slow, and it hurts
	# accordingly.
	"strike_kick_heavy": {"kind": "retime", "file": MOTIFECT_KICK,
		"source": "motifect_kick_raw", "seconds": 0.950},

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
