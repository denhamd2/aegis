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
var _roster := PackedStringArray()
var _trace_out := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--trace-out" and i + 1 < args.size():
			_trace_out = args[i + 1]
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_roster = args[i + 1].split(",")
		elif args[i] == "--moves" and i + 1 < args.size():
			for token in args[i + 1].split(","):
				_only.append(token)
	var results := []
	for move_id in PairClearance.paired_move_ids():
		if not _only.is_empty() and not _only.has(move_id):
			continue
		var r: Dictionary = await PairClearance.measure(self, move_id, _roster, not _trace_out.is_empty())
		results.append(r)
		if not _trace_out.is_empty():
			DirAccess.make_dir_recursive_absolute(_trace_out)
			var file := FileAccess.open(_trace_out.path_join(move_id.replace("/", "_") + ".json"), FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(r, "\t"))
			else:
				push_error("Cannot write trace: %s" % _trace_out)
				get_tree().quit(1)
				return
		if r.has("authored_contacts"):
			var contacts: Array = r["authored_contacts"]
			var gaps: Array = contacts.filter(func(c): return c.get("valid", false)).map(func(c): return c["gap_m"])
			gaps.sort()
			print("AUTHORED_CONTACT %s required %d valid %d median_gap %s" % [move_id,
					contacts.size(), gaps.size(), str(gaps[gaps.size() / 2]) if not gaps.is_empty() else "missing"])
		var g: Array = r["grip"]
		g.sort()
		if not g.is_empty():
			print("GRIP %-36s %-6s median %.3f  p90 %.3f  (%d in reach, %d out)" % [move_id,
					PairedContacts.family(load("res://resources/moves/%s.tres" % move_id)),
					g[g.size() / 2], g[int(g.size() * 0.9)], g.size(), int(r.get("out_of_reach", 0))])
		elif PairedContacts.family(load("res://resources/moves/%s.tres" % move_id)) == "none":
			print("GRIP %-36s none   grip blend peak %.2f" % [move_id, r["grip_blend"]])
		print("PAIR %-36s worst %.3f m  %s @%.2f   body-body %.3f   arm %.3f   moved A %.3f D %.3f" % [move_id,
				r["worst"], r["where"], r["at"], r["body"], r["arm"], r["moved_attacker"], r["moved_defender"]])
		if r.has("body_clip_seconds"):
			print("PAIR_BODY_CLOCK %s %s clip_seconds %.6f authored_30fps_frame %.3f" % [move_id,
					r["body_where"], r["body_clip_seconds"], float(r["body_clip_seconds"]) * 30.0])
			print("PAIR_BODY_POINTS %s %s" % [move_id, JSON.stringify(r.get("body_role_points", {}))])
		if r.has("worst_clip_seconds"):
			print("PAIR_CLOCK %s elapsed_tick %d lead_in_ticks %d clip_seconds %.6f authored_30fps_frame %.3f" % [move_id,
					r["worst_elapsed_tick"], r["lead_in_ticks"], r["worst_clip_seconds"], float(r["worst_clip_seconds"]) * 30.0])
			print("PAIR_POINTS %s %s" % [move_id, JSON.stringify(r.get("worst_role_points", {}))])
	results.sort_custom(func(x, y): return x["worst"] > y["worst"])
	print("PAIR_DONE %d moves; over %.2f m: %d" % [results.size(), PairClearance.BODY_LIMIT,
			results.filter(func(r): return r["body"] > PairClearance.BODY_LIMIT).size()])
	get_tree().quit()
