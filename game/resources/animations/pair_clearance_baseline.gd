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
	# 5.3 cm, 3 mm over the body limit: his right thigh through the victim's
	# left shin as the lariat lands. Everything else on this list was fixed
	# by the Phase 2 separation and trajectory fit (see PairedFit).
	"running_clothesline_from_hell": [0.06, 0.06],  # A thigh_r-calf_r x B calf_l-foot_l
}
