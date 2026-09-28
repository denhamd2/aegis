extends Node
## Two-man moves: how deep one body goes into the other, over every tick of
## every paired move (gauntlet/refs/animation_gap.md, Phase 1 "pair lint").
##
##   godot4 --headless --path game tools/probe/pair_clearance.tscn \
##       [-- --moves grapple_vertical_suplex,signature_cody_cutter]
##
## Each body is modelled as the eye reads it -- capsules round the torso,
## neck and head, upper and lower arms, thighs and shins (radii a little under
## the rendered limbs, so a graze does not count) -- and each tick the deepest
## overlap between any of one man's capsules and any of the other's is kept.
## The move runs through the real GrappleRig in the real match scene, so the
## pair frame, the lead-in and the root trajectories are the shipped ones.
##
## Prints, per move, the worst overlap with where and when, plus a summary.
## PairClearance.body_depth() is the measure tests/test_pair_clearance.gd
## gates on.

const MATCH_SCENE := "res://scenes/match.tscn"
const MOVES_DIR := "res://resources/moves"

var _only: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--moves" and i + 1 < args.size():
			for token in args[i + 1].split(","):
				_only.append(token)
	var results := []
	for move_id in PairClearance.paired_move_ids():
		if not _only.is_empty() and not _only.has(move_id):
			continue
		var r: Dictionary = await PairClearance.measure(self, move_id)
		results.append(r)
		print("PAIR %-36s worst %.3f m  %s @%.2f   body-body %.3f   arm %.3f   moved A %.3f D %.3f" % [move_id,
				r["worst"], r["where"], r["at"], r["body"], r["arm"], r["moved_attacker"], r["moved_defender"]])
	results.sort_custom(func(x, y): return x["worst"] > y["worst"])
	print("PAIR_DONE %d moves; over %.2f m: %d" % [results.size(), PairClearance.BODY_LIMIT,
			results.filter(func(r): return r["body"] > PairClearance.BODY_LIMIT).size()])
	get_tree().quit()
