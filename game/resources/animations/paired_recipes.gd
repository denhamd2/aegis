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
	# The one grapple, and deliberately not a throw. The three it replaces
	# (hiptoss, snapmare, armdrag) all put the victim in the air, and the
	# altitude was not a bug that could be capped away: the tucked-body
	# clearance gate requires root_y >= 1.15 * |up.y| - 0.12, so a body that
	# inverts MUST be lifted clear of the mat or its head goes through the
	# canvas. The way to stop a man flying is to stop him flipping.
	#
	# So nobody flips and nobody leaves the mat. Collar-and-elbow, a short
	# drag down into the clinch, one knee to the midsection, and a shove off.
	# Both men finish it on their feet, which is also what makes it a sane
	# opener for an exchange rather than a match-ending bomb.
	"grapple_clinch_knee": {
		# Authored in Blender: both halves keyframed against each other
		# beat for beat, rather than stitched out of unrelated clips.
		"authored": {"attacker": "Clinch_Knee_Attacker", "defender": "Clinch_Knee_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},          # collar and elbow
			{"t": 0.30, "clip": "PickUp_Table", "at": 0.25},  # drag him down
			{"t": 0.52, "clip": "Jump_Start", "at": 0.30},    # load the knee
			{"t": 0.68, "clip": "Sword_Attack", "at": 0.80},  # drive it in
			{"t": 0.85, "clip": "Push", "at": 0.80},          # shove off
			{"t": 1.00, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},          # answering the lock-up
			{"t": 0.30, "clip": "Sitting_Enter", "at": 0.60}, # bent forward, held
			{"t": 0.68, "clip": "Hit_Chest", "at": 0.15},     # the knee lands
			{"t": 0.85, "clip": "Hit_Head", "at": 0.20},      # folded back
			{"t": 1.00, "clip": "Idle", "at": 0.00},          # back on his feet
		],
		"defender_grips_until": 0.68,
	},
	# The power rung, and the one throw back in the set. The cut throws were
	# stitched out of borrowed clips and read as nothing; this one is keyed
	# in Blender beat for beat against its partner, like the signatures.
	#
	# A body slam: scooped, turned, held flat across the chest at 1.12 m,
	# dropped on his back. The victim is carried along his own axis and the
	# ATTACKER turns under him -- see Bodyslam_Attacker in
	# tools/blender/wrestling_clips.py for why it has to be that way round.
	"power_bodyslam": {
		"authored": {"attacker": "Bodyslam_Attacker", "defender": "Bodyslam_Defender"},
		# Fallback samples, used only if the authored clips are missing.
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.25, "clip": "PickUp_Table", "at": 0.25},
			{"t": 0.50, "clip": "PickUp_Table", "at": 0.80},
			{"t": 0.78, "clip": "PickUp_Table", "at": 0.45},
			{"t": 1.20, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.35, "clip": "Jump", "at": 0.50},
			{"t": 0.78, "clip": "Death01", "at": 0.90},
			{"t": 1.20, "clip": "Death01", "at": 1.60},
		],
		# He grabs at the man ducking under him, and lets go once he is off
		# his feet.
		"defender_grips_until": 0.35,
	},
	# The body slam's lift, then down onto one knee with the victim arched
	# face-up across the other. The samples below are only the fallback --
	# see Backbreaker_Attacker in tools/blender/wrestling_clips.py.
	# Running attack -- see Knee_Lift_Attacker in tools/blender/wrestling_clips.py.
	"running_knee_lift": {
		"authored": {"attacker": "Knee_Lift_Attacker", "defender": "Knee_Lift_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.25,
	},
	# Running attack -- see CFH_Attacker in tools/blender/wrestling_clips.py.
	"running_clothesline_from_hell": {
		"authored": {"attacker": "CFH_Attacker", "defender": "CFH_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.25,
	},
	# Running attack -- see Back_Elbow_Attacker in tools/blender/wrestling_clips.py.
	"running_spinning_back_elbow": {
		"authored": {"attacker": "Back_Elbow_Attacker", "defender": "Back_Elbow_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.30,
	},
	# Running attack -- see SL_Dropkick_Attacker in tools/blender/wrestling_clips.py.
	"running_single_leg_dropkick": {
		"authored": {"attacker": "SL_Dropkick_Attacker", "defender": "SL_Dropkick_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.25,
	},
	# Running attack -- see Tilt_DDT_Attacker in tools/blender/wrestling_clips.py.
	"running_tilt_a_whirl_ddt": {
		"authored": {"attacker": "Tilt_DDT_Attacker", "defender": "Tilt_DDT_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.60,
	},
	# Running attack -- see Bicycle_Knee_Attacker in tools/blender/wrestling_clips.py.
	"running_bicycle_knee": {
		"authored": {"attacker": "Bicycle_Knee_Attacker", "defender": "Bicycle_Knee_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.25,
	},
	# Running attack -- see Cave_In_Attacker in tools/blender/wrestling_clips.py.
	"running_cave_in": {
		"authored": {"attacker": "Cave_In_Attacker", "defender": "Cave_In_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.30,
	},
	# Running attack -- see Claymore_Attacker in tools/blender/wrestling_clips.py.
	"running_claymore": {
		"authored": {"attacker": "Claymore_Attacker", "defender": "Claymore_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.25,
	},
	# Running attack -- see Cyclone_Kick_Attacker in tools/blender/wrestling_clips.py.
	"running_cyclone_kick": {
		"authored": {"attacker": "Cyclone_Kick_Attacker", "defender": "Cyclone_Kick_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.30,
	},
	# Running attack -- see Dragon_Twist_Attacker in tools/blender/wrestling_clips.py.
	"running_dragon_twist_cutter": {
		"authored": {"attacker": "Dragon_Twist_Attacker", "defender": "Dragon_Twist_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.50,
	},
	# Running attack -- see Fallaway_Attacker in tools/blender/wrestling_clips.py.
	"running_fallaway_moonsault_slam": {
		"authored": {"attacker": "Fallaway_Attacker", "defender": "Fallaway_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.30,
	},
	# Running attack -- see Liger_Bomb_Attacker in tools/blender/wrestling_clips.py.
	"running_float_over_liger_bomb": {
		"authored": {"attacker": "Liger_Bomb_Attacker", "defender": "Liger_Bomb_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.60,
	},
	# Running attack -- see Hoedown_Attacker in tools/blender/wrestling_clips.py.
	"running_hoedown": {
		"authored": {"attacker": "Hoedown_Attacker", "defender": "Hoedown_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.40,
	},
	# Running attack -- see Cravate_Attacker in tools/blender/wrestling_clips.py.
	"running_jumping_cravate_driver": {
		"authored": {"attacker": "Cravate_Attacker", "defender": "Cravate_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.40,
	},
	# Running attack -- see Last_Shot_Attacker in tools/blender/wrestling_clips.py.
	"running_last_shot": {
		"authored": {"attacker": "Last_Shot_Attacker", "defender": "Last_Shot_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.35,
	},
	# Running attack -- see Mushroom_Stomp_Attacker in tools/blender/wrestling_clips.py.
	"running_leaping_mushroom_stomp": {
		"authored": {"attacker": "Mushroom_Stomp_Attacker", "defender": "Mushroom_Stomp_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.30,
	},
	# Running attack -- see Leg_Lariat_Attacker in tools/blender/wrestling_clips.py.
	"running_leg_lariat": {
		"authored": {"attacker": "Leg_Lariat_Attacker", "defender": "Leg_Lariat_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.25,
	},
	# Running attack -- see Play_Of_Day_Attacker in tools/blender/wrestling_clips.py.
	"running_play_of_the_day": {
		"authored": {"attacker": "Play_Of_Day_Attacker", "defender": "Play_Of_Day_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.35,
	},
	# Running attack -- see Swing_Neck_Attacker in tools/blender/wrestling_clips.py.
	"running_reverse_swing_neckbreaker": {
		"authored": {"attacker": "Swing_Neck_Attacker", "defender": "Swing_Neck_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.50,
	},
	# Running attack -- see Codebreaker_Attacker in tools/blender/wrestling_clips.py.
	"running_rolling_codebreaker": {
		"authored": {"attacker": "Codebreaker_Attacker", "defender": "Codebreaker_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.50,
	},
	# Running attack -- see Thunder_Flatliner_Attacker in tools/blender/wrestling_clips.py.
	"running_rolling_thunder_flatliner": {
		"authored": {"attacker": "Thunder_Flatliner_Attacker", "defender": "Thunder_Flatliner_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.50,
	},
	# Running attack -- see Gamengiri_Attacker in tools/blender/wrestling_clips.py.
	"running_gamengiri": {
		"authored": {"attacker": "Gamengiri_Attacker", "defender": "Gamengiri_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.25,
	},
	# Running attack -- see Run_Spear_Attacker in tools/blender/wrestling_clips.py.
	"running_spear": {
		"authored": {"attacker": "Run_Spear_Attacker", "defender": "Run_Spear_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.25,
	},
	# Running attack -- see Stundog_Attacker in tools/blender/wrestling_clips.py.
	"running_stundog_millionaire": {
		"authored": {"attacker": "Stundog_Attacker", "defender": "Stundog_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.40,
	},
	# Running attack -- see Backstabber_Attacker in tools/blender/wrestling_clips.py.
	"running_tilt_a_whirl_backstabber": {
		"authored": {"attacker": "Backstabber_Attacker", "defender": "Backstabber_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Punch_Cross", "at": 0.50},
		],
		"defender": [
			{"t": 0.00, "clip": "Idle", "at": 0.00},
			{"t": 0.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.50,
	},
	# Roman's own signature -- see Superman_Punch_Attacker.
	"signature_superman_punch": {
		"authored": {"attacker": "Superman_Punch_Attacker", "defender": "Superman_Punch_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.80, "clip": "Punch_Cross", "at": 0.50},
			{"t": 1.40, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.87, "clip": "Hit_Head", "at": 0.20},
			{"t": 1.40, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.10,
	},
	# Cody's own signature -- see Cody_Cutter_Attacker.
	"signature_cody_cutter": {
		"authored": {"attacker": "Cody_Cutter_Attacker", "defender": "Cody_Cutter_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.80, "clip": "Sitting_Enter", "at": 0.60},
			{"t": 1.40, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.90, "clip": "Death01", "at": 0.90},
			{"t": 1.40, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.10,
	},
	# Cody's finisher -- see Cross_Rhodes_Attacker.
	"finisher_cross_rhodes": {
		"authored": {"attacker": "Cross_Rhodes_Attacker", "defender": "Cross_Rhodes_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.80, "clip": "Sitting_Enter", "at": 0.60},
			{"t": 1.60, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.87, "clip": "Death01", "at": 0.90},
			{"t": 1.60, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.15,
	},
	# Roman's finisher -- see Spear_Attacker in tools/blender/wrestling_clips.py.
	"finisher_spear": {
		"authored": {"attacker": "Spear_Attacker", "defender": "Spear_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.60, "clip": "Jump_Start", "at": 0.30},
			{"t": 1.40, "clip": "Idle", "at": 0.00},
		],
		"defender": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.70, "clip": "Death01", "at": 0.40},
			{"t": 1.40, "clip": "Death01", "at": 1.60},
		],
		"defender_grips_until": 0.10,
	},
	"signature_backbreaker": {
		# Authored in Blender: both halves keyframed against each other
		# beat for beat, rather than stitched out of unrelated clips.
		"authored": {"attacker": "Backbreaker_Attacker", "defender": "Backbreaker_Defender"},
		"attacker": [
			{"t": 0.00, "clip": "Push", "at": 0.80},
			{"t": 0.20, "clip": "PickUp_Table", "at": 0.25},
			{"t": 0.35, "clip": "PickUp_Table", "at": 0.60},
			# The kneel is EARLY on purpose. It used to arrive at 0.72, well
			# after the victim's peak, which was survivable only because the
			# arc lifted him to 1.55 m -- clear over a standing man's head.
			# Lowering the arc without moving this put the two bodies through
			# each other at t=0.35: the height had been clearing the ATTACKER,
			# not just the mat. He is down on the knee by 0.50 now, so the
			# victim comes down ACROSS him, which is what a backbreaker is.
			{"t": 0.50, "clip": "Fixing_Kneeling", "at": 2.00},
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
	# The attacker takes the head and wrenches it down and across to his
	# hip; the victim is twisted over and dropped on his back beside him.
	# The samples below are only the fallback -- see Neckbreaker_Attacker.
	"signature_neckbreaker": {
		# Authored in Blender: both halves keyframed against each other
		# beat for beat, rather than stitched out of unrelated clips.
		"authored": {"attacker": "Neckbreaker_Attacker", "defender": "Neckbreaker_Defender"},
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
			# Was Roll at 0.70 ("inverted"), which was picked to match the
			# somersault the trajectory no longer does. Death01 at 0.40 is
			# "falling", which is what a back-drop looks like.
			{"t": 0.55, "clip": "Death01", "at": 0.40},
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
	# Nobody leaves the mat: every y is 0.00, by design. See the RECIPES entry
	# above for why a grapple that does not flip is the only kind that can
	# stay down here.
	"grapple_clinch_knee": {
		"length": 1.0,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.30, 0.34, 0.00, 0.00],
					[0.68, 0.30, 0.00, 0.00], [0.85, 0.36, 0.00, 0.00],
					[1.00, 0.40, 0.00, 0.00]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [0.52, 0.0, 82.0, 0.0],
					[1.00, 0.0, 90.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.30, -0.32, 0.00, 0.00],
					[0.68, -0.28, 0.00, 0.00], [0.85, -0.46, 0.00, 0.00],
					[1.00, -0.55, 0.00, 0.00]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [0.52, 0.0, -98.0, 0.0],
					[1.00, 0.0, -90.0, 0.0]],
		},
	},

	# --- grapple, power tier -------------------------------------------
	# Nobody's root leaves the mat: the 1.12 m the victim is held at is bone
	# pose (Bodyslam_Defender). What the roots do is the turn.
	#
	# The attacker yaws 90 -> 0, from facing the victim (-X) to facing -Z,
	# so the victim -- whose facing never changes, and who therefore lies
	# along X -- ends up ACROSS his chest rather than pointing into it. The
	# victim's root travels with him to stay in front of the chest through
	# the turn: at yaw theta the attacker faces (-sin theta, 0, -cos theta),
	# and the victim sits about 0.3 m out along that, his pelvis just short
	# of the attacker's centreline so his head and his legs overhang evenly.
	#
	# The slam carries him a further 0.15 m out, where the attacker's bend
	# puts him. The attacker ends still facing -Z, looking down at him.
	"power_bodyslam": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.23, 0.30, 0.00, 0.00],
					[0.43, 0.34, 0.00, 0.02], [0.63, 0.40, 0.00, 0.02],
					[1.20, 0.40, 0.00, 0.02]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [0.23, 0.0, 88.0, 0.0],
					[0.43, 0.0, 40.0, 0.0], [0.63, 0.0, 0.0, 0.0],
					[1.20, 0.0, 0.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.23, -0.28, 0.00, 0.00],
					[0.43, 0.10, 0.00, -0.20], [0.63, 0.30, 0.00, -0.30],
					[0.80, 0.30, 0.00, -0.30], [0.93, 0.30, 0.00, -0.45],
					[1.20, 0.30, 0.00, -0.45]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [1.20, 0.0, -90.0, 0.0]],
		},
	},

	# --- grapple, signature tier ---------------------------------------
	# The backbreaker. Its arc used to be hand-keyed straight into
	# paired_moves.tres, lifting the victim's root 1.55 m and pitching it --
	# a pitch the rig discards, so the lift is all that survived. It is
	# generated here now, and it is the body slam's path for the lift
	# (Backbreaker_* share Bodyslam_*'s first 20 frames), then the victim is
	# brought down over the attacker's raised left knee -- 0.20 to his left,
	# 0.28 in front of him, which with the attacker facing -Z is x 0.20,
	# z -0.28 -- and poured off to -Z onto the mat.
	"signature_backbreaker": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.23, 0.30, 0.00, 0.00],
					[0.43, 0.34, 0.00, 0.02], [0.63, 0.40, 0.00, 0.02],
					[1.20, 0.40, 0.00, 0.02]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [0.23, 0.0, 88.0, 0.0],
					[0.43, 0.0, 40.0, 0.0], [0.63, 0.0, 0.0, 0.0],
					[1.20, 0.0, 0.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.23, -0.28, 0.00, 0.00],
					[0.43, 0.10, 0.00, -0.20], [0.63, 0.30, 0.00, -0.30],
					[0.80, 0.20, 0.00, -0.28], [0.97, 0.20, 0.00, -0.30],
					[1.10, 0.20, 0.00, -0.62], [1.20, 0.20, 0.00, -0.62]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [1.20, 0.0, -90.0, 0.0]],
		},
	},

	# --- running attacks, from the reference video -------------------------
	# Each starts with the runner 1.6 m out at a sprint (x 1.20) and the
	# victim square to him at -0.40. A blow that puts the victim on his back
	# away from the runner yaws his root a half-turn over the two-to-five
	# frames after the hit (the Spear's method); a face-first landing and the
	# Clothesline From Hell's three-quarter flip need no yaw at all. The
	# Tilt-A-Whirl orbits the runner's root once round the victim at 0.35 m,
	# yawing to keep facing him. No root leaves the mat.
	"running_knee_lift": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.45, 0.00, 0.00], [0.300, 0.25, 0.00, 0.00], [0.400, 0.00, 0.00, 0.00], [0.600, -0.30, 0.00, 0.35], [1.200, -0.40, 0.00, 0.45]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.300, -0.40, 0.00, 0.00], [0.367, -0.65, 0.00, 0.00], [0.467, -1.00, 0.00, 0.00], [1.200, -1.00, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [0.300, 0.00, -90.00, 0.00], [0.367, 0.00, 0.00, 0.00], [0.467, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
	},
	"running_clothesline_from_hell": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.50, 0.00, 0.00], [0.300, 0.35, 0.00, 0.00], [0.433, 0.20, 0.00, 0.00], [0.600, 0.10, 0.00, 0.00], [1.200, 0.10, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.300, -0.40, 0.00, 0.00], [0.433, -0.60, 0.00, 0.00], [0.567, -0.75, 0.00, 0.00], [1.200, -0.75, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.200, 0.00, -90.00, 0.00]],
		},
	},
	"running_spinning_back_elbow": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.267, 0.45, 0.00, 0.00], [0.400, 0.40, 0.00, 0.00], [1.200, 0.40, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [0.267, 0.00, 90.00, 0.00], [0.333, 0.00, 0.00, 0.00], [0.400, 0.00, -90.00, 0.00], [0.467, 0.00, -180.00, 0.00], [0.533, 0.00, -270.00, 0.00], [1.200, 0.00, -270.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.400, -0.40, 0.00, 0.00], [0.467, -0.65, 0.00, 0.00], [0.567, -1.00, 0.00, 0.00], [1.200, -1.00, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [0.400, 0.00, -90.00, 0.00], [0.467, 0.00, 0.00, 0.00], [0.567, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
	},
	"running_single_leg_dropkick": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.30, 0.00, 0.00], [0.133, 0.85, 0.00, 0.00], [0.233, 0.55, 0.00, 0.00], [0.333, 0.40, 0.00, 0.00], [0.533, 0.35, 0.00, 0.00], [1.200, 0.35, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.333, -0.40, 0.00, 0.00], [0.400, -0.65, 0.00, 0.00], [0.500, -1.00, 0.00, 0.00], [1.200, -1.00, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [0.333, 0.00, -90.00, 0.00], [0.400, 0.00, 0.00, 0.00], [0.500, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
	},
	"running_tilt_a_whirl_ddt": {
		"length": 2.0,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.55, 0.00, 0.00], [0.200, 0.05, 0.00, 0.00], [0.267, -0.05, 0.00, 0.05], [0.367, -0.40, 0.00, 0.35], [0.467, -0.75, 0.00, 0.00], [0.567, -0.40, 0.00, -0.35], [0.667, -0.05, 0.00, 0.00], [1.200, -0.02, 0.00, 0.00], [1.333, 0.25, 0.00, 0.00], [2.000, 0.25, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [0.267, 0.00, 90.00, 0.00], [0.367, 0.00, 0.00, 0.00], [0.467, 0.00, -90.00, 0.00], [0.567, 0.00, -180.00, 0.00], [0.667, 0.00, -270.00, 0.00], [2.000, 0.00, -270.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [1.200, -0.40, 0.00, 0.00], [1.333, -0.20, 0.00, 0.00], [1.533, -0.05, 0.00, 0.00], [2.000, -0.05, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [2.000, 0.00, -90.00, 0.00]],
		},
	},

	"running_bicycle_knee": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.50, 0.00, 0.00], [0.300, 0.35, 0.00, 0.00], [0.467, 0.55, 0.00, 0.30], [1.200, 0.70, 0.00, 0.40]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.400, -0.40, 0.00, 0.00], [0.533, -0.55, 0.00, 0.00], [1.200, -0.55, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.200, 0.00, -90.00, 0.00]],
		},
	},
	"running_cave_in": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.50, 0.00, 0.00], [0.333, 0.30, 0.00, 0.00], [0.400, 0.10, 0.00, 0.00], [0.500, -0.25, 0.00, 0.00], [1.200, -0.25, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.400, -0.40, 0.00, 0.00], [0.467, -0.65, 0.00, 0.00], [0.567, -1.00, 0.00, 0.00], [1.200, -1.00, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [0.400, 0.00, -90.00, 0.00], [0.467, 0.00, 0.00, 0.00], [0.567, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
	},
	"running_claymore": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.30, 0.00, 0.00], [0.133, 0.85, 0.00, 0.00], [0.233, 0.60, 0.00, 0.00], [0.333, 0.45, 0.00, 0.00], [0.533, 0.45, 0.00, 0.00], [1.200, 0.45, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.367, -0.40, 0.00, 0.00], [0.433, -0.65, 0.00, 0.00], [0.533, -1.00, 0.00, 0.00], [1.200, -1.00, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [0.367, 0.00, -90.00, 0.00], [0.433, 0.00, 0.00, 0.00], [0.533, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
	},
	"running_cyclone_kick": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.55, 0.00, 0.00], [0.400, 0.45, 0.00, 0.00], [1.200, 0.65, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [0.267, 0.00, 90.00, 0.00], [0.333, 0.00, 0.00, 0.00], [0.400, 0.00, -90.00, 0.00], [0.433, 0.00, -180.00, 0.00], [0.500, 0.00, -270.00, 0.00], [1.200, 0.00, -270.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.467, -0.40, 0.00, 0.00], [0.600, -0.60, 0.00, 0.00], [1.200, -0.60, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.200, 0.00, -90.00, 0.00]],
		},
	},
	"running_dragon_twist_cutter": {
		"length": 1.4,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.50, 0.00, 0.00], [0.300, 0.40, 0.00, 0.00], [0.500, 0.35, 0.00, 0.00], [0.700, 0.70, 0.00, 0.00], [1.400, 0.70, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.400, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.533, -0.40, 0.00, 0.00], [0.700, -0.50, 0.00, 0.00], [1.400, -0.50, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.400, 0.00, -90.00, 0.00]],
		},
	},
	"running_fallaway_moonsault_slam": {
		"length": 1.4,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.45, 0.00, 0.00], [0.300, 0.30, 0.00, 0.00], [0.500, 0.40, 0.00, 0.00], [1.400, 0.40, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.400, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.333, -0.30, 0.00, 0.00], [0.400, 0.30, 0.00, 0.00], [0.533, 1.30, 0.00, 0.00], [1.400, 1.30, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.400, 0.00, -90.00, 0.00]],
		},
	},
	"running_float_over_liger_bomb": {
		"length": 2.0,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.50, 0.00, 0.00], [0.333, 0.35, 0.00, 0.00], [1.400, 0.40, 0.00, 0.00], [2.000, 0.40, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [2.000, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.333, -0.20, 0.00, 0.00], [1.000, -0.05, 0.00, 0.00], [1.267, -0.05, 0.00, 0.00], [1.333, -0.30, 0.00, 0.00], [1.400, -0.55, 0.00, 0.00], [2.000, -0.55, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.267, 0.00, -90.00, 0.00], [1.333, 0.00, 0.00, 0.00], [1.400, 0.00, 90.00, 0.00], [2.000, 0.00, 90.00, 0.00]],
		},
	},
	"running_hoedown": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.50, 0.00, 0.00], [0.333, 0.40, 0.00, 0.00], [0.533, 0.65, 0.00, 0.00], [1.200, 0.65, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [1.200, -0.40, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.200, 0.00, -90.00, 0.00]],
		},
	},
	"running_jumping_cravate_driver": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.50, 0.00, 0.00], [0.333, 0.35, 0.00, 0.00], [0.533, 0.65, 0.00, 0.00], [1.200, 0.65, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [1.200, -0.40, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.200, 0.00, -90.00, 0.00]],
		},
	},
	"running_last_shot": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.50, 0.00, 0.00], [0.333, 0.35, 0.00, 0.00], [0.533, 0.55, 0.00, 0.00], [1.200, 0.55, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.400, -0.40, 0.00, 0.00], [0.500, -0.60, 0.00, 0.00], [1.200, -0.60, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.200, 0.00, -90.00, 0.00]],
		},
	},

	"running_leaping_mushroom_stomp": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.50, 0.00, 0.00], [0.333, 0.20, 0.00, 0.00], [0.400, -0.10, 0.00, 0.00], [0.500, -0.40, 0.00, 0.40], [1.200, -0.60, 0.00, 0.60]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [1.200, -0.40, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.200, 0.00, -90.00, 0.00]],
		},
	},
	"running_leg_lariat": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.30, 0.00, 0.00], [0.133, 0.85, 0.00, 0.00], [0.233, 0.60, 0.00, 0.00], [0.333, 0.35, 0.00, 0.00], [0.533, 0.45, 0.00, 0.00], [1.200, 0.45, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.367, -0.40, 0.00, 0.00], [0.500, -0.60, 0.00, 0.00], [0.633, -0.75, 0.00, 0.00], [1.200, -0.75, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.200, 0.00, -90.00, 0.00]],
		},
	},
	"running_play_of_the_day": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.45, 0.00, 0.00], [0.300, 0.30, 0.00, 0.00], [0.467, 0.35, 0.00, 0.00], [1.200, 0.35, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.400, -0.40, 0.00, 0.00], [0.467, -0.65, 0.00, 0.00], [0.567, -1.00, 0.00, 0.00], [1.200, -1.00, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [0.400, 0.00, -90.00, 0.00], [0.467, 0.00, 0.00, 0.00], [0.567, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
	},
	"running_reverse_swing_neckbreaker": {
		"length": 1.6,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.45, 0.00, 0.00], [0.300, 0.30, 0.00, 0.00], [0.433, -0.05, 0.00, 0.40], [0.567, -0.60, 0.00, 0.30], [0.700, -0.95, 0.00, 0.00], [0.833, -1.35, 0.00, 0.00], [1.600, -1.35, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [0.300, 0.00, 90.00, 0.00], [0.433, 0.00, 30.00, 0.00], [0.567, 0.00, -30.00, 0.00], [0.700, 0.00, -90.00, 0.00], [1.600, 0.00, -90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.767, -0.40, 0.00, 0.00], [0.833, -0.50, 0.00, 0.00], [0.933, -0.60, 0.00, 0.00], [1.600, -0.60, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [0.767, 0.00, -90.00, 0.00], [0.833, 0.00, 0.00, 0.00], [0.933, 0.00, 90.00, 0.00], [1.600, 0.00, 90.00, 0.00]],
		},
	},
	"running_rolling_codebreaker": {
		"length": 1.6,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.45, 0.00, 0.00], [0.300, 0.25, 0.00, 0.00], [0.433, -0.40, 0.00, 0.00], [0.567, -1.00, 0.00, 0.00], [0.700, -1.30, 0.00, 0.00], [0.867, -1.20, 0.00, 0.00], [1.000, -0.90, 0.00, 0.00], [1.100, -1.25, 0.00, 0.00], [1.600, -1.25, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [0.567, 0.00, 90.00, 0.00], [0.700, 0.00, -90.00, 0.00], [1.600, 0.00, -90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.567, -0.40, 0.00, 0.00], [0.700, -0.40, 0.00, 0.00], [1.033, -0.40, 0.00, 0.00], [1.100, -0.10, 0.00, 0.00], [1.200, 0.20, 0.00, 0.00], [1.600, 0.20, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [0.567, 0.00, -90.00, 0.00], [0.700, 0.00, 90.00, 0.00], [1.033, 0.00, 90.00, 0.00], [1.100, 0.00, 180.00, 0.00], [1.200, 0.00, 270.00, 0.00], [1.600, 0.00, 270.00, 0.00]],
		},
	},
	"running_rolling_thunder_flatliner": {
		"length": 1.4,
		"attacker": {
			"pos": [[0.000, 1.60, 0.00, 0.00], [0.133, 1.20, 0.00, 0.00], [0.233, 0.95, 0.00, 0.00], [0.433, 0.55, 0.00, 0.00], [0.633, 0.35, 0.00, 0.00], [0.767, 0.75, 0.00, 0.00], [1.400, 0.75, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.400, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [1.400, -0.40, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.400, 0.00, -90.00, 0.00]],
		},
	},
	"running_gamengiri": {
		"length": 1.2,
		"attacker": {
			"pos": [[0.000, 1.30, 0.00, 0.00], [0.133, 0.85, 0.00, 0.00], [0.233, 0.60, 0.00, 0.00], [0.333, 0.40, 0.00, 0.00], [0.533, 0.50, 0.00, 0.00], [1.200, 0.50, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.200, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.367, -0.40, 0.00, 0.00], [0.500, -0.55, 0.00, 0.00], [1.200, -0.55, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.200, 0.00, -90.00, 0.00]],
		},
	},
	"running_spear": {
		"length": 1.0,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.300, 0.00, 0.00, 0.00], [0.433, -0.35, 0.00, 0.00], [1.000, -0.40, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.000, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [0.300, -0.52, 0.00, 0.00], [0.433, -1.05, 0.00, 0.00], [1.000, -1.05, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [0.300, 0.00, -90.00, 0.00], [0.367, 0.00, 0.00, 0.00], [0.433, 0.00, 90.00, 0.00], [1.000, 0.00, 90.00, 0.00]],
		},
	},
	"running_stundog_millionaire": {
		"length": 1.4,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.75, 0.00, 0.00], [0.233, 0.45, 0.00, 0.00], [0.300, 0.30, 0.00, 0.00], [0.500, 0.55, 0.00, 0.00], [0.667, 0.75, 0.00, 0.00], [1.400, 0.75, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [1.400, 0.00, 90.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [1.400, -0.40, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.400, 0.00, -90.00, 0.00]],
		},
	},
	"running_tilt_a_whirl_backstabber": {
		"length": 1.8,
		"attacker": {
			"pos": [[0.000, 1.20, 0.00, 0.00], [0.133, 0.55, 0.00, 0.00], [0.200, 0.05, 0.00, 0.00], [0.267, -0.05, 0.00, 0.05], [0.367, -0.40, 0.00, 0.35], [0.467, -0.75, 0.00, 0.00], [0.567, -0.40, 0.00, -0.35], [0.667, -0.05, 0.00, 0.00], [0.933, -0.05, 0.00, 0.00], [1.100, -0.70, 0.00, 0.00], [1.800, -0.70, 0.00, 0.00]],
			"rot": [[0.000, 0.00, 90.00, 0.00], [0.267, 0.00, 90.00, 0.00], [0.367, 0.00, 0.00, 0.00], [0.467, 0.00, -90.00, 0.00], [0.567, 0.00, -180.00, 0.00], [0.667, 0.00, -270.00, 0.00], [0.933, 0.00, -270.00, 0.00], [1.000, 0.00, -360.00, 0.00], [1.100, 0.00, -450.00, 0.00], [1.800, 0.00, -450.00, 0.00]],
		},
		"defender": {
			"pos": [[0.000, -0.40, 0.00, 0.00], [1.033, -0.40, 0.00, 0.00], [1.100, -0.65, 0.00, 0.00], [1.200, -1.00, 0.00, 0.00], [1.800, -1.00, 0.00, 0.00]],
			"rot": [[0.000, 0.00, -90.00, 0.00], [1.033, 0.00, -90.00, 0.00], [1.100, 0.00, 0.00, 0.00], [1.200, 0.00, 90.00, 0.00], [1.800, 0.00, 90.00, 0.00]],
		},
	},

	# --- finisher tier -------------------------------------------------
	# Roman's Spear: he shoves off, loads 0.9 m back, and charges through
	# the victim's midsection -- 1.6 m in six frames -- going down on top of
	# him. The victim is driven 0.6 m back and, while airborne (t0.70-0.83),
	# his root yaws a half-turn so he lands facing the way Down_Supine lies;
	# Spear_Defender's bones counter-yaw so he keeps falling straight back in
	# the world. No root leaves the mat (y = 0 throughout), so the yaw is
	# free of the airborne-landing invariant.
	"finisher_spear": {
		"length": 1.4,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.20, 0.70, 0.00, 0.00],
					[0.40, 1.30, 0.00, 0.00], [0.53, 1.30, 0.00, 0.00],
					[0.63, 0.30, 0.00, 0.00], [0.70, 0.00, 0.00, 0.00],
					[0.83, -0.35, 0.00, 0.00], [1.40, -0.40, 0.00, 0.00]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [1.40, 0.0, 90.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.20, -0.52, 0.00, 0.00],
					[0.63, -0.52, 0.00, 0.00], [0.70, -0.62, 0.00, 0.00],
					[0.83, -1.05, 0.00, 0.00], [1.40, -1.05, 0.00, 0.00]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [0.70, 0.0, -90.0, 0.0],
					[0.77, 0.0, 0.0, 0.0], [0.83, 0.0, 90.0, 0.0],
					[1.40, 0.0, 90.0, 0.0]],
		},
	},

	# Cody's Cross Rhodes. The victim is spun a half-turn by the wrist
	# (t0.20-0.47, his root yawing -90 -> +90, so his back is to Cody) and
	# pulled in to 0.45 m; Cody hooks the head, leaps forward 1.3 m spinning a
	# half-turn himself (yaw 90 -> -90), and lands seated with the head behind
	# his right shoulder, while the victim is driven face-first 0.5 m forward
	# of where he stood. Roots stay at y = 0.
	"finisher_cross_rhodes": {
		"length": 1.6,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.33, 0.36, 0.00, 0.00],
					[0.60, 0.36, 0.00, 0.00], [0.73, -0.30, 0.00, 0.00],
					[0.87, -0.95, 0.00, 0.00], [1.60, -0.95, 0.00, 0.00]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [0.60, 0.0, 90.0, 0.0],
					[0.73, 0.0, 0.0, 0.0], [0.87, 0.0, -90.0, 0.0],
					[1.60, 0.0, -90.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.20, -0.36, 0.00, 0.00],
					[0.47, -0.08, 0.00, 0.00], [0.60, -0.08, 0.00, 0.00],
					[0.87, -0.58, 0.00, 0.00], [1.60, -0.58, 0.00, 0.00]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [0.20, 0.0, -90.0, 0.0],
					[0.33, 0.0, 0.0, 0.0], [0.47, 0.0, 90.0, 0.0],
					[1.60, 0.0, 90.0, 0.0]],
		},
	},

	# Roman's Superman Punch. He shoves off to 0.90, crouches and pounds the
	# mat, runs 1.30 -> 0.45, leaps (the height is bone pose) and lands the
	# right hand at t0.87; the victim falls straight back, his root yawing a
	# half-turn t0.87-1.03 as in the Spear.
	"signature_superman_punch": {
		"length": 1.4,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.20, 0.90, 0.00, 0.00],
					[0.47, 1.30, 0.00, 0.00], [0.63, 0.45, 0.00, 0.00],
					[0.87, 0.12, 0.00, 0.00], [0.97, 0.05, 0.00, 0.00],
					[1.40, 0.05, 0.00, 0.00]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [1.40, 0.0, 90.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.20, -0.55, 0.00, 0.00],
					[0.53, -0.45, 0.00, 0.00], [0.87, -0.45, 0.00, 0.00],
					[1.03, -0.95, 0.00, 0.00], [1.40, -0.95, 0.00, 0.00]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [0.87, 0.0, -90.0, 0.0],
					[0.93, 0.0, 0.0, 0.0], [1.03, 0.0, 90.0, 0.0],
					[1.40, 0.0, 90.0, 0.0]],
		},
	},

	# Cody's Cody Cutter. He shoves off, turns and runs for where the ropes
	# would be (yaw 90 -> -90 at t0.20-0.30, out to 1.30), turns back off
	# them (t0.47-0.53), runs in, leaps at t0.73 and falls back to a seat at
	# 0.50, the victim's head under his right arm. Cody faces -X at the
	# finish, so his right is -Z: the victim is pulled face-first 0.2 m
	# forward and 0.25 m to that side, so his head lands at Cody's hip.
	"signature_cody_cutter": {
		"length": 1.4,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.20, 0.60, 0.00, 0.00],
					[0.47, 1.30, 0.00, 0.00], [0.53, 1.30, 0.00, 0.00],
					[0.73, 0.30, 0.00, 0.00], [0.90, 0.50, 0.00, 0.00],
					[1.40, 0.50, 0.00, 0.00]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [0.20, 0.0, 90.0, 0.0],
					[0.30, 0.0, -90.0, 0.0], [0.47, 0.0, -90.0, 0.0],
					[0.53, 0.0, 90.0, 0.0], [1.40, 0.0, 90.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.17, -0.55, 0.00, 0.00],
					[0.73, -0.45, 0.00, 0.00], [0.80, -0.50, 0.00, 0.00],
					[0.90, -0.35, 0.00, -0.25], [1.40, -0.35, 0.00, -0.25]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [1.40, 0.0, -90.0, 0.0]],
		},
	},

	# A standing neckbreaker. Nobody leaves the mat: the victim is dragged
	# forward and twisted over by the head and lands on his back beside the
	# attacker's right boot -- all bone pose (Neckbreaker_Defender). The roots
	# only carry him there, and turn the attacker into the wrench.
	#
	# This used to lift the victim 0.45 m on a back-drop arc pitched to -85.
	# GrappleRig keeps only the yaw of a defender's root key, so the pitch was
	# discarded and the lift was not: rendered, he floated straight up,
	# draped over the attacker's back and came down on his face. His root
	# never leaves y = 0 now, so neither the airborne-landing invariant nor
	# the tucked-body clearance gate has anything to ask of it.
	#
	# The attacker's right is the pair frame's -Z, so the victim drifts to
	# -Z as he goes down, bringing his head in beside the boot rather than
	# under it.
	"signature_neckbreaker": {
		"length": 1.0,
		"attacker": {
			"pos": [[0.00, 0.40, 0.00, 0.00], [0.27, 0.38, 0.00, 0.00],
					[0.67, 0.40, 0.00, 0.04], [1.00, 0.40, 0.00, 0.04]],
			"rot": [[0.00, 0.0, 90.0, 0.0], [0.47, 0.0, 74.0, 0.0],
					[1.00, 0.0, 82.0, 0.0]],
		},
		"defender": {
			"pos": [[0.00, -0.40, 0.00, 0.00], [0.27, -0.34, 0.00, -0.04],
					[0.47, -0.34, 0.00, -0.18], [0.67, -0.38, 0.00, -0.26],
					[1.00, -0.38, 0.00, -0.26]],
			"rot": [[0.00, 0.0, -90.0, 0.0], [1.00, 0.0, -90.0, 0.0]],
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
