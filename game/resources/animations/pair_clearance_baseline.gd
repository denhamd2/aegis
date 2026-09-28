class_name PairClearanceBaseline
extends RefCounted
## The Phase 2 work queue (gauntlet/refs/animation_gap.md): every paired move
## whose bodies measured INSIDE each other past PairClearance's limits when
## the pair check was written, with the depth then, rounded up a centimetre.
##
## tests/test_pair_clearance.gd is a ratchet on these: a move listed here may
## not get worse, a move not listed may not go over the limits at all, and a
## move fixed below the limits should be DELETED from here so it stays fixed.
## Worst first; the comment is where it was worst.
const OVER := {
	"running_float_over_liger_bomb": [0.27, 0.10],  # A pelvis-spine_03 x B pelvis-spine_03
	"running_tilt_a_whirl_ddt": [0.26, 0.18],  # A pelvis-spine_03 x B pelvis-spine_03
	"running_tilt_a_whirl_backstabber": [0.25, 0.14],  # A pelvis-spine_03 x B pelvis-spine_03
	"power_alabama_slam": [0.23, 0.09],  # A pelvis-spine_03 x B pelvis-spine_03
	"running_rolling_codebreaker": [0.23, 0.16],  # A pelvis-spine_03 x B pelvis-spine_03
	"finisher_spear": [0.23, 0.11],  # A pelvis-spine_03 x B pelvis-spine_03
	"running_spear": [0.23, 0.12],  # A pelvis-spine_03 x B pelvis-spine_03
	"running_dragon_twist_cutter": [0.22, 0.15],  # A pelvis-spine_03 x B spine_03-Head
	"running_play_of_the_day": [0.22, 0.06],  # A pelvis-spine_03 x B spine_03-Head
	"running_stundog_millionaire": [0.22, 0.09],  # A pelvis-spine_03 x B spine_03-Head
	"grapple_vertical_suplex": [0.22, 0.12],  # A spine_03-Head x B pelvis-spine_03
	"power_bodyslam": [0.22, 0.17],  # A spine_03-Head x B pelvis-spine_03
	"power_powerslam": [0.22, 0.17],  # A spine_03-Head x B pelvis-spine_03
	"signature_backbreaker": [0.22, 0.17],  # A spine_03-Head x B pelvis-spine_03
	"running_leaping_mushroom_stomp": [0.21, 0.09],  # A pelvis-spine_03 x B pelvis-spine_03
	"running_reverse_swing_neckbreaker": [0.21, 0.18],  # A pelvis-spine_03 x B spine_03-Head
	"finisher_cross_rhodes": [0.18, 0.12],  # A calf_r-foot_r x B pelvis-spine_03
	"signature_cody_cutter": [0.18, 0.10],  # A calf_r-foot_r x B pelvis-spine_03
	"running_rolling_thunder_flatliner": [0.17, 0.03],  # A spine_03-Head x B spine_03-Head
	"signature_neckbreaker": [0.16, 0.11],  # A thigh_r-calf_r x B spine_03-Head
	"grapple_clinch_knee": [0.15, 0.08],  # A pelvis-spine_03 x B spine_03-Head
	"running_fallaway_moonsault_slam": [0.15, 0.10],  # A spine_03-Head x B spine_03-Head
	"running_cave_in": [0.14, 0.06],  # A thigh_l-calf_l x B thigh_r-calf_r
	"signature_superman_punch": [0.14, 0.09],  # A thigh_l-calf_l x B thigh_r-calf_r
	"running_cyclone_kick": [0.12, 0.08],  # A calf_r-foot_r x B pelvis-spine_03
	"running_knee_lift": [0.12, 0.01],  # A thigh_r-calf_r x B calf_l-foot_l
	"running_clothesline_from_hell": [0.11, 0.10],  # A spine_03-Head x B calf_l-foot_l
	"running_last_shot": [0.10, 0.05],  # A calf_r-foot_r x B thigh_l-calf_l
	"running_leg_lariat": [0.09, 0.04],  # A calf_r-foot_r x B thigh_l-calf_l
	"running_claymore": [0.09, 0.01],  # A calf_r-foot_r x B calf_l-foot_l
	"running_single_leg_dropkick": [0.09, 0.01],  # A calf_r-foot_r x B pelvis-spine_03
	"running_gamengiri": [0.08, 0.09],  # A thigh_r-calf_r x B pelvis-spine_03
}
