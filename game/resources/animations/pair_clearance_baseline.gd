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
	# 7.2 cm, 2.2 cm over the body limit, at the landing (0.84): the victim's
	# left thigh through the attacker's pelvis as he sits out. It appeared when
	# downed legs were lengthened (stage 8) and three targeted refit passes
	# traded it between 5.4 and 7.2 cm without clearing it -- the fit cannot
	# move a leg, only a root. The fix is a knees-up landing key for the
	# victim in wrestling_clips.py. (Clothesline From Hell, the last entry
	# before this, measured clean after the same refit.)
	"power_samoan_drop": [0.08, 0.06],  # A pelvis-spine_03 x B thigh_l-calf_l
}


## Hand contact (PairedContacts; Phase 2 "contact"): median distance from each
## of the attacker's hands to where the move says it holds, over the frames
## the hold is within his reach. CONTACT_LIMIT for every holding move except
## these, which measured over it when the contact IK went in -- rounded up a
## centimetre, and a ratchet like OVER above. All of them are moves where the
## attacker turns or rolls through the hold, and the arm chain lags the spin.
const CONTACT_LIMIT := 0.05
const GRIP := {
	# Stage 8: 5.6 cm, the same landing as its OVER entry above.
	"power_samoan_drop": 0.07,
	"running_rolling_codebreaker": 0.54,
	# 0.18 -> 0.21: re-measured when PairClearance went deterministic (one
	# physics tick per render frame). The old reading swung 0.17-0.20 with the
	# machine's frame timing; the move did not change. Its true median is 0.20.
	"running_tilt_a_whirl_backstabber": 0.21,
	"running_fallaway_moonsault_slam": 0.10,
	"running_reverse_swing_neckbreaker": 0.09,
	"running_rolling_thunder_flatliner": 0.07,
}
## Fewer in-reach frames than this and a median says nothing: the Cody
## Cutter's hold is in reach for three or four ticks of a jump, and its median
## swung between 1 and 12 cm on how the walk-in happened to land.
const MIN_CONTACT_FRAMES := 10
## A strike, kick or dive ("none") must leave his hands his own.
const FREE_HANDS_MAX_BLEND := 0.2
