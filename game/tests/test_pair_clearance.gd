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
# World-space float32 bone samples can land nanometres above an exact limit.
const MEASUREMENT_EPSILON := 0.000001


func test_no_paired_move_puts_one_body_through_the_other_and_hands_hold() -> void:
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
		failures.append_array(_contact_failures(move_id, r))
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()


## Hands where the move says they hold (PairedContacts), and off the man in a
## strike. Measured in the same run as the overlap: one pass through every
## move is the slow part of this suite.
func _contact_failures(move_id: String, r: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var move: MoveDef = load("res://resources/moves/%s.tres" % move_id)
	if PairedContacts.authored_hands(move):
		return _authored_contact_failures(move_id, move, r)
	var family := PairedContacts.family(move)
	if family == "none":
		if float(r["grip_blend"]) > PairClearanceBaseline.FREE_HANDS_MAX_BLEND:
			out.append("%s is a strike but the grip IK blended in to %.2f"
					% [move_id, r["grip_blend"]])
		return out
	var grip: Array = r["grip"]
	if family == "" or grip.size() < PairClearanceBaseline.MIN_CONTACT_FRAMES:
		return out
	grip.sort()
	var median: float = grip[grip.size() / 2]
	var limit := float(PairClearanceBaseline.GRIP.get(move_id, PairClearanceBaseline.CONTACT_LIMIT))
	if median > limit + SLACK:
		out.append("%s (%s): hands %.3f m from their hold, limit %.2f"
				% [move_id, family, median, limit])
	elif PairClearanceBaseline.GRIP.has(move_id) and median <= PairClearanceBaseline.CONTACT_LIMIT:
		out.append("%s's hands are FIXED (%.3f): delete it from PairClearanceBaseline.GRIP"
				% [move_id, median])
	return out


func _authored_contact_failures(move_id: String, move: MoveDef, r: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var samples: Array = r.get("authored_contacts", [])
	for required: Dictionary in PairedContacts.hand_profile(move).get("expected", []):
		failures.append_array(_required_contact_failures(move_id, required, samples, move.total_frames()))
	return failures


func _required_contact_failures(move_id: String, required: Dictionary, samples: Array,
		total_ticks: int) -> Array[String]:
	var failures: Array[String] = []
	var id: String = required["id"]
	var selected := samples.filter(func(c): return c["id"] == id)
	var window: Vector2 = required["window"]
	var ticks := {}
	for sample in selected:
		ticks[int(sample.get("clip_tick", -1))] = true
	var first := int(round(window.x * total_ticks))
	var last := int(round(window.y * total_ticks))
	for tick in range(first, last + 1):
		if not ticks.has(tick):
			failures.append("%s %s missing required clip tick%d" % [move_id, id, tick])
	var valid := selected.filter(func(c): return c.get("valid", false))
	if valid.size() != selected.size():
		failures.append("%s %s has %d missing/incoherent post-modifier anchors" % [move_id, id, selected.size() - valid.size()])
	if valid.is_empty():
		return failures
	var worst_penetration: float = valid.map(func(c): return c["penetration_m"]).max()
	if worst_penetration > PairClearance.ARM_LIMIT + SLACK + MEASUREMENT_EPSILON:
		failures.append("%s %s shoulder penetration %.3fm exceeds arm limit" % [move_id, id, worst_penetration])
	var gaps := valid.map(func(c): return c["gap_m"])
	gaps.sort()
	var median: float = gaps[gaps.size() / 2]
	var detached := valid.filter(func(c): return c["gap_m"] > PairClearanceBaseline.CONTACT_LIMIT + SLACK + MEASUREMENT_EPSILON)
	if not detached.is_empty():
		failures.append("%s %s loses required contact at ticks%s: maximum gap %.3fm, median %.3fm, limit %.3fm"
				% [move_id, id, str(detached.map(func(c): return c["clip_tick"])), gaps.back(), median,
				PairClearanceBaseline.CONTACT_LIMIT + SLACK])
	return failures


## The measure itself: two capsules a known distance apart overlap by exactly
## what is left of their radii.
func test_segment_distance_is_the_gap_between_centre_lines() -> void:
	var d := PairClearance.segment_distance(Vector3(0, 0, 0), Vector3(0, 1, 0),
			Vector3(0.2, 0, 0), Vector3(0.2, 1, 0))
	assert_float(d).is_equal_approx(0.2, 0.0001)


## Their own big moves, at their real sizes: Roman's Spear and Superman Punch
## on Cody, Cody's Cross Rhodes and Cody Cutter on Roman. The ratchet above
## runs on the mannequin the clips were authored on; this holds the moves
## that decide matches for the men who actually wrestle them.
func test_each_mans_finisher_and_signature_are_clean_on_the_other() -> void:
	var failures: Array[String] = []
	for spec: Array in [["roman", "cody", "finisher_spear"],
			["roman", "cody", "signature_superman_punch"],
			["cody", "roman", "finisher_cross_rhodes"],
			["cody", "roman", "signature_cody_cutter"]]:
		var r: Dictionary = await PairClearance.measure(self, spec[2],
				PackedStringArray([spec[0], spec[1]]))
		if r["body"] > PairClearance.BODY_LIMIT or r["arm"] > PairClearance.ARM_LIMIT:
			failures.append("%s on %s: %s body %.3f arm %.3f -- %s"
					% [spec[0], spec[1], spec[2], r["body"], r["arm"], r["where"]])
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()


func _complete_authored_contact_fixture() -> Dictionary:
	var contacts: Array = []
	for tick in range(98, 111):
		contacts.append({"id": "right_forearm", "clip_tick": tick, "valid": true,
				"gap_m": .01, "penetration_m": 0.0})
	return {"authored_contacts": contacts}


func test_authored_contact_cannot_hide_a_detached_tail_behind_a_good_median() -> void:
	var r := _complete_authored_contact_fixture()
	for index in range(7, 13):
		r["authored_contacts"][index]["gap_m"] = .5
	var required := {"id": "right_forearm", "window": Vector2(49.0/66, 55.0/66)}
	var failures := _required_contact_failures("synthetic_continuous_wrap", required, r["authored_contacts"], 132)
	assert_int(failures.size()).is_equal(1)
	assert_str(failures[0]).contains("loses required contact")


func test_authored_contact_requires_distinct_ticks_and_coherent_anchors() -> void:
	var r := _complete_authored_contact_fixture()
	r["authored_contacts"][12]["clip_tick"] = 109
	r["authored_contacts"][0]["valid"] = false
	var required := {"id": "right_forearm", "window": Vector2(49.0/66, 55.0/66)}
	var failures := _required_contact_failures("synthetic_continuous_wrap", required, r["authored_contacts"], 132)
	assert_int(failures.size()).is_equal(2)


func test_authored_contact_keeps_penetration_separate_from_surface_gap() -> void:
	var r := _complete_authored_contact_fixture()
	var required := {"id": "right_forearm", "window": Vector2(49.0/66, 55.0/66)}
	assert_array(_required_contact_failures("synthetic_continuous_wrap", required, r["authored_contacts"], 132)).is_empty()
	r["authored_contacts"][5]["penetration_m"] = .12
	var failures := _required_contact_failures("synthetic_continuous_wrap", required, r["authored_contacts"], 132)
	assert_int(failures.size()).is_equal(1)
	assert_str(failures[0]).contains("shoulder penetration")


func test_authored_running_wrap_is_clean_in_both_roster_orders() -> void:
	var failures: Array[String] = []
	for roster in [PackedStringArray(["cody", "roman"]), PackedStringArray(["roman", "cody"])]:
		var move_id := "running_grapple_inverted_drop"
		var r: Dictionary = await PairClearance.measure(self, move_id, roster)
		var label := "%s→%s" % [roster[0], roster[1]]
		if r["body"] > PairClearance.BODY_LIMIT or r["arm"] > PairClearance.ARM_LIMIT:
			failures.append("%s body %.3fm arm %.3fm" % [label, r["body"], r["arm"]])
		for failure in _contact_failures(move_id, r):
			failures.append("%s: %s" % [label, failure])
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
