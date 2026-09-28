extends GdUnitTestSuite
## Two-man moves may not put one body through the other (PairClearance;
## gauntlet/refs/animation_gap.md Phase 1). Every paired move runs through the
## real GrappleRig in the real match scene and is measured every tick.
##
## A ratchet, because when this was written 32 of 37 moves were already over:
## the lifts carry a man THROUGH the lifter's chest, the spears drive pelvis
## into pelvis. Those are listed in PairClearanceBaseline, which is Phase 2's
## work queue. Here:
##   * a listed move may not get worse than it measured;
##   * an unlisted move may not go over the limits at all;
##   * a listed move now under the limits fails too -- delete it from the
##     baseline, so the ratchet holds it there.

const SLACK := 0.005


func test_no_paired_move_puts_one_body_through_the_other() -> void:
	var failures: Array[String] = []
	for move_id in PairClearance.paired_move_ids():
		var r: Dictionary = await PairClearance.measure(self, move_id)
		var body: float = r["body"]
		var arm: float = r["arm"]
		if PairClearanceBaseline.OVER.has(move_id):
			var base: Array = PairClearanceBaseline.OVER[move_id]
			if body > float(base[0]) + SLACK or arm > float(base[1]) + SLACK:
				failures.append("%s got WORSE: body %.3f (was <= %.2f), arm %.3f (was <= %.2f) -- %s"
						% [move_id, body, base[0], arm, base[1], r["where"]])
			elif body <= PairClearance.BODY_LIMIT and arm <= PairClearance.ARM_LIMIT:
				failures.append("%s is FIXED (body %.3f, arm %.3f): delete it from PairClearanceBaseline"
						% [move_id, body, arm])
		elif body > PairClearance.BODY_LIMIT or arm > PairClearance.ARM_LIMIT:
			failures.append("%s puts one body through the other: body %.3f, arm %.3f -- %s @%.2f"
					% [move_id, body, arm, r["where"], r["at"]])
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()


## The measure itself: two capsules a known distance apart overlap by exactly
## what is left of their radii.
func test_segment_distance_is_the_gap_between_centre_lines() -> void:
	var d := PairClearance.segment_distance(Vector3(0, 0, 0), Vector3(0, 1, 0),
			Vector3(0.2, 0, 0), Vector3(0.2, 1, 0))
	assert_float(d).is_equal_approx(0.2, 0.0001)
