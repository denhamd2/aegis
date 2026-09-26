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

## Clips authored on the rig in Blender rather than sampled out of the CC0
## library. See tools/blender/wrestling_clips.py for why: the 42 source
## actions are a generic character set (Pistol_*, Sword_*, Swim_*, Sitting_*)
## with no wrestling in them, so anything wrestling-specific can only be
## approximated by recombining them -- or authored outright, which is what
## these are.
const AUTHORED := "res://assets/animations/wrestling_clips.glb"

## No recipe here samples a file any more, so the "file" key the builder
## still understands is currently unused: every clip below is cut from the
## rig's own library.
##
## It used to point at the baked Motifect excerpts under assets/animations/.
## Every one of them measured with the head below the hips on most of its
## frames (see the reverted strikes below), and none could be re-baked --
## the retarget.py this file used to credit is not in the repo and the raw
## FBX was deliberately not vendored per the pack's licence. The three
## motifect_*_raw.glb files are LEFT IN PLACE rather than deleted: they are
## the only copy of that motion in the repo, so someone with the pack may
## yet salvage them.

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
	# Authored. Punch_Cross retimed to 0.514s had the right duration but
	# spent it as one slow arc with no snap in it. The authored jab follows
	# the combat-timing reference -- short anticipation, a 2-frame action
	# phase, quick recovery -- and throws the LEFT hand, so the jab and the
	# cross read as different punches rather than the same arm twice.
	"strike_jab": {"kind": "retime", "source": "Strike_Jab",
		"seconds": 0.514, "file": AUTHORED},

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
	# Authored, replacing a stitch of Idle frames with hand-written thigh and
	# calf angles. The stitch could only ever pose the leg, because Idle has
	# no kick in it to sample -- so the arms, spine and standing leg kept
	# idling through a boot.
	"strike_kick": {"kind": "retime", "source": "Strike_Kick",
		"seconds": 0.583, "file": AUTHORED},

	# There is deliberately NO recipe for running_double_leg, the second
	# running attack. There was one -- the last still sourced from the mocap
	# bake -- and it carried the same fault as the three strikes reverted
	# above: measured with tools/probe/strike_clip_probe.tscn on the base rig,
	# head below hips on 59 of its 69 frames, worst 0.268 m under. Rendered,
	# that is a ball of limbs rather than a takedown.
	#
	# It is deleted rather than re-cut because it cannot be re-baked (no
	# retarget.py, no vendored FBX) and cannot be replaced honestly: the rig
	# has no takedown pose, and stitching one would mean inventing per-bone
	# angles for a move that fires ZERO times in a match -- input["run"] is
	# only ever set by the whip decision inside GRAPPLE_HOLD, so the AI never
	# runs in open play (gauntlet/status/roman_reigns_next.md).
	#
	# With no recipe, StrikeRecipes.clip() returns "" and _set_state_clip
	# ignores it, so running_attack_double_leg.tres falls back to
	# STATE_ANIMATIONS' RUNNING_ATTACK: "Punch_Cross" -- exactly what its
	# sibling running_attack_clothesline.tres already does. A missing asset,
	# not a bug.

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
	# Now AUTHORED rather than borrowed. Strike_Forearm is keyframed on the
	# rig in tools/blender/wrestling_clips.py: a wind-up that twists the
	# shoulder away, a contact frame driven by spine_03 rotation rather than
	# the arm alone, and a follow-through PAST the contact point instead of a
	# stop at it. Punch_Cross, the CC0 library's boxing cross, had none of
	# that -- it is a guard-to-guard jab with no torso in it.
	#
	# Retimed to the same 0.667s as before, so strike_cross.tres's
	# startup_frames (12) still lands on the contact frame and no MoveDef
	# timing moves.
	"strike_cross": {"kind": "retime", "source": "Strike_Forearm",
		"seconds": 0.667, "file": AUTHORED},

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
	# Authored. The heavy kick is the same boot wound further back and
	# recovered from properly: its length comes from anticipation and
	# recovery, never from a slower action phase.
	"strike_kick_heavy": {"kind": "retime", "source": "Strike_Kick_Heavy",
		"seconds": 0.950, "file": AUTHORED},

	# Both reactions are cut to exactly WrestlerController.HIT_REACT_TICKS
	# (20 ticks, 0.333s) so the clip ends as the state does. Hit_Chest is
	# already 0.33s and is trimmed by nothing; Hit_Head is 0.43s and loses
	# its tail.
	# Authored (tools/blender/wrestling_clips.py). Hit_React_Head snaps the
	# head first and furthest, then the neck, then the torso a beat behind,
	# so a hit reads as force arriving rather than the whole body turning as
	# one board. The rig's Hit_Head moves everything on the same frame.
	#
	# Retimed, not trimmed: the authored clip is longer than the state and
	# its recovery is part of the performance, so cutting the tail would end
	# it mid-recoil. Hit_Head was trimmed because its tail was surplus.
	"hit_head": {"kind": "retime", "source": "Hit_React_Head",
		"seconds": 0.333, "file": AUTHORED},
	# Authored. Hit_Chest flinches; this FOLDS around the hit -- chest
	# hollows, shoulders close in, knees give -- so a body shot and a head
	# shot are visibly different things happening to a man.
	"hit_torso": {"kind": "retime", "source": "Hit_React_Torso",
		"seconds": 0.333, "file": AUTHORED},

	# The winner's celebration, for WrestlerFSM.State.VICTORY. Authored, and
	# necessarily so: there is no celebration anywhere in the 42 source
	# actions, which is half of why this could not be built before -- the
	# other half being that the FSM had no state to play it in.
	#
	# Kept at its authored length. Nothing times out against it: VICTORY is
	# terminal and the clip holds its last pose.
	"win_celebrate": {"kind": "retime", "source": "Win_Celebrate",
		"seconds": 1.300, "file": AUTHORED},

	# --- the ring entrance (core/match/entrance_director.gd) ---------------
	#
	# Lengths are the clips' own frame counts at 30 fps and must stay so: the
	# director moves the root at the speed and over the durations these were
	# authored against (EntranceDirector.WALK_SPEED, CLIMB_SECONDS,
	# ROPE_SECONDS), and a retime here would slide the planted feet.
	"entrance_walk": {"kind": "retime", "source": "Entrance_Walk",
		"seconds": 0.800, "file": AUTHORED, "loop": true},
	"climb_steps": {"kind": "retime", "source": "Climb_Steps",
		"seconds": 1.200, "file": AUTHORED},
	"rope_step_through": {"kind": "retime", "source": "Rope_Step_Through",
		"seconds": 1.600, "file": AUTHORED},
	"rope_step_through_apron": {"kind": "retime", "source": "Rope_Step_Through_Apron",
		"seconds": 1.333, "file": AUTHORED},
	"apron_step": {"kind": "retime", "source": "Apron_Step",
		"seconds": 1.000, "file": AUTHORED},
	# Roman's entrance (gauntlet/refs/entrances.md). Own lengths, as above.
	"walk_slow": {"kind": "retime", "source": "Walk_Slow",
		"seconds": 1.000, "file": AUTHORED, "loop": true},
	"walk_slow_look": {"kind": "retime", "source": "Walk_Slow_Look",
		"seconds": 4.800, "file": AUTHORED, "loop": true},
	"roman_stand": {"kind": "retime", "source": "Roman_Stand",
		"seconds": 2.000, "file": AUTHORED, "loop": true},
	# Cody's entrance (gauntlet/refs/entrances.md). Own lengths, as above.
	"cody_stand": {"kind": "retime", "source": "Cody_Stand",
		"seconds": 2.000, "file": AUTHORED, "loop": true},
	"whoa_arms": {"kind": "retime", "source": "Whoa_Arms",
		"seconds": 2.000, "file": AUTHORED},
	"fists_up": {"kind": "retime", "source": "Fists_Up",
		"seconds": 1.000, "file": AUTHORED},
	"whoa_crouch": {"kind": "retime", "source": "Whoa_Crouch",
		"seconds": 0.700, "file": AUTHORED},
	"air_punch": {"kind": "retime", "source": "Air_Punch",
		"seconds": 1.500, "file": AUTHORED},
	"point_crowd": {"kind": "retime", "source": "Point_Crowd",
		"seconds": 2.000, "file": AUTHORED},
	"walk_crowd": {"kind": "retime", "source": "Walk_Crowd",
		"seconds": 3.467, "file": AUTHORED, "loop": true},
	"corner_climb": {"kind": "retime", "source": "Corner_Climb",
		"seconds": 1.200, "file": AUTHORED},
	"corner_pose": {"kind": "retime", "source": "Corner_Pose",
		"seconds": 3.000, "file": AUTHORED},
	"corner_down": {"kind": "retime", "source": "Corner_Down",
		"seconds": 1.000, "file": AUTHORED},
	"coat_off": {"kind": "retime", "source": "Coat_Off",
		"seconds": 2.000, "file": AUTHORED},
	"title_unbuckle": {"kind": "retime", "source": "Title_Unbuckle",
		"seconds": 1.500, "file": AUTHORED},
	"title_raise": {"kind": "retime", "source": "Title_Raise",
		"seconds": 2.000, "file": AUTHORED},
	"finger_raise": {"kind": "retime", "source": "Finger_Raise",
		"seconds": 2.000, "file": AUTHORED},
	"ula_fala_off": {"kind": "retime", "source": "Ula_Fala_Off",
		"seconds": 1.500, "file": AUTHORED},

	# --- states that were playing raw rig clips -------------------------
	#
	# These replace clips taken straight off wrestler_base.glb. Each names
	# what it is replacing and why the borrowed one was wrong; lengths match
	# the rig's originals so nothing downstream shifts.
	#
	# "loop": true is REQUIRED on the three a wrestler sits in. The rig's
	# Idle/Walk/Sprint carry LOOP_LINEAR; a generated clip inherits nothing
	# and would play once and freeze.

	# Idle is a relaxed civilian stand with the arms down. A wrestler at
	# rest is coiled: weight forward, hands up, always moving a little.
	"idle_ready": {"kind": "retime", "source": "Idle_Ready",
		"seconds": 2.500, "file": AUTHORED, "loop": true},

	# Walk is a stroll. This is a man circling an opponent -- short steps,
	# hands up, square to the danger.
	# 0.533s, matching Walk_Stalk's own 16 frames at 30fps. The cycle is
	# generated against MOVE_SPEED (see _gait() in tools/blender/
	# wrestling_clips.py), so this duration is not free: the planted foot
	# delivers travel / (contact_frames / frames * seconds), and retiming
	# this number without regenerating the clip puts the skate straight back.
	"walk_stalk": {"kind": "retime", "source": "Walk_Stalk",
		"seconds": 0.533, "file": AUTHORED, "loop": true},

	# Sprint is a jog with the torso upright and the arms barely moving.
	# 0.667s, matching Run_Drive's own 20 frames at 30fps -- and, like the
	# walk above, tied to RUN_SPEED through the generated contact phase.
	"run_drive": {"kind": "retime", "source": "Run_Drive",
		"seconds": 0.667, "file": AUTHORED, "loop": true},

	# TIE_UP played "Push", a two-armed shove -- closer than the one-armed
	# point it replaced, but still a man pushing a crate. A collar-and-elbow
	# has one hand high on the neck and one on the elbow, chest square, legs
	# braced and driving.
	"tie_up_collar": {"kind": "retime", "source": "Tie_Up_Collar",
		"seconds": 1.000, "file": AUTHORED, "loop": true},

	# DOWN and PIN_DEFENDER played Death01: a man dying, collapsing and
	# lying still with his arms splayed. A dropped wrestler is on his back
	# with his knees up, and he is still breathing.
	"down_supine": {"kind": "retime", "source": "Down_Supine",
		"seconds": 1.333, "file": AUTHORED, "loop": true},

	# FINISHER played Sword_Attack: a two-handed overhead sword swing. The
	# biggest moment in a match has been a man chopping at the air. This is
	# a lift-and-drive -- load deep, haul up through the legs, drive down.
	"finisher_drive": {"kind": "retime", "source": "Finisher_Drive",
		"seconds": 1.333, "file": AUTHORED},

	# SUBMISSION_ATTACKER played Crouch_Idle, a man crouching by himself.
	# This is someone working: down on a knee, hauling back rhythmically.
	"submission_work": {"kind": "retime", "source": "Submission_Work",
		"seconds": 1.000, "file": AUTHORED, "loop": true},

	# The grapple family: the last clips taken straight off the rig, and the
	# ones furthest from what they represent.

	# GRAPPLE_HOLD with no role known. "Interact" is a one-armed
	# reach-and-point: with both wrestlers playing it a lock-up rendered as
	# two men standing apart pointing past each other.
	"grapple_hold_neutral": {"kind": "retime", "source": "Grapple_Hold_Neutral",
		"seconds": 1.000, "file": AUTHORED, "loop": true},

	# The attacker in a hold played "PickUp_Table" -- a man lifting
	# furniture with a straight back. A front waistlock bends at the waist
	# and wraps LOW.
	"grapple_hold_attacker": {"kind": "retime", "source": "Grapple_Hold_Attacker",
		"seconds": 1.000, "file": AUTHORED, "loop": true},

	# The man being held played "Death01": a corpse. He is bent over and
	# braced, resisting.
	"grapple_hold_defender": {"kind": "retime", "source": "Grapple_Hold_Defender",
		"seconds": 1.000, "file": AUTHORED, "loop": true},

	# MOVE_EXEC played "Jump_Land", a man absorbing a drop he took himself.
	# This is the other side of it: he has just put someone down.
	"move_exec_impact": {"kind": "retime", "source": "Move_Exec_Impact",
		"seconds": 0.600, "file": AUTHORED},

	# IRISH_WHIP played "Push", a shove straight ahead. A whip turns the
	# hips and slings the other man PAST you.
	"irish_whip_throw": {"kind": "retime", "source": "Irish_Whip_Throw",
		"seconds": 0.800, "file": AUTHORED},

	# RUNNING_ATTACK plays Punch_Cross today: a wrestler sprints the width of
	# the ring and throws a boxing jab. A clothesline does not swing -- the
	# arm is out and locked before contact and the RUN supplies the force --
	# so no amount of retiming a punch produces one.
	# 1.150s = the 69 frames both running_attack_*.tres share (they leave
	# animation_pair_id empty, so both fall through to STATE_ANIMATIONS).
	# A 0.667s clip here would end 29 ticks early and hold its last pose,
	# which is the clip-shorter-than-its-state fault this file exists to
	# prevent.
	"running_clothesline": {"kind": "retime", "source": "Running_Clothesline",
		"seconds": 1.150, "file": AUTHORED},

	# STUNNED runs 45 ticks (0.75s) and Hit_Head is 0.43s, so the clip ended
	# and the pose froze for the remaining 19 ticks. Retimed rather than
	# trimmed: a stagger is the one case where slowing the motion down is
	# the point.
	# Authored. A retimed Hit_Head stretched a 0.43s flinch over 0.75s, which
	# reads as a man moving through treacle. This is a slow unbalanced sway
	# with the guard dropped: still on his feet, but gone.
	"stunned": {"kind": "retime", "source": "Stunned_Sway",
		"seconds": 0.750, "file": AUTHORED},

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
	# Authored. GETUP played "Roll", a tucked forward roll 1.467s against a
	# 126-tick (2.10s) state, so the wrestler curled into a ball and FROZE in
	# it for the remaining 0.63s -- which is what "the downed wrestler
	# crumples" turned out to be. The stitch that replaced it built a real
	# rise out of Death01, Fixing_Kneeling and Crouch_Idle; this authors the
	# same rise on the rig.
	#
	# Beats are kept where the stitch had them -- prone, off the mat, onto a
	# knee, crouched, standing. That is behavioural, not cosmetic: the
	# input-driven fast rise (GETUP_RISE_FAST_TICKS, 1.14s) plays this clip
	# and is cut off partway through, so moving a beat changes what a fast
	# getup looks like.
	"getup_rise": {"kind": "retime", "source": "Getup_Rise",
		"seconds": 2.100, "file": AUTHORED},

	# Authored. PIN_ATTACKER played "Crouch_Idle" -- a man crouching on his
	# own, so the three-count ran with the attacker standing beside the
	# fallen man rather than covering him. The stitch that replaced it bent
	# Fixing_Kneeling down over the opponent with per-bone offsets; this
	# authors the cover directly: down on both knees, chest low, both arms
	# pressing the shoulders into the mat, eyes on the shoulders.
	"pin_cover": {"kind": "retime", "source": "Pin_Cover",
		"seconds": 0.600, "file": AUTHORED},
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
