extends GdUnitTestSuite
## The band WrestlerAI holds, against the distances the strikes actually reach.
##
## These two facts live in different files and drifted apart the moment they
## could. WrestlerAI's spacing constants (min_standoff 1.05, circle_distance
## 1.10) were chosen against WrestlerController.STRIKE_HIT_RANGE back when that
## single 1.15 m number was the reach of every strike in the game. Once each
## move carried its own measured contact volume, the cross reached 1.07 m --
## and the AI went on standing at 1.10, where every cross it drew missed by
## three centimetres. Nothing failed: the strikes simply stopped landing, which
## reads on screen as two men circling and swinging at nothing.
##
## So this suite asserts the RELATIONSHIP rather than either number. Re-measure
## a clip, extend a punch, or retune the standoff, and the one that has to stay
## true is that a wrestler holding his circling distance can hit the man
## opposite him with whatever strike he happens to draw.

const AI := preload("res://core/ai/wrestler_ai.gd")

const STRIKES := ["strike_jab", "strike_cross", "strike_kick", "strike_kick_heavy"]

func _move(id: String) -> MoveDef:
	return load("res://resources/moves/%s.tres" % id)

## A controller carrying the strike pool a match actually wires up.
func _armed() -> WrestlerController:
	var w: WrestlerController = auto_free(WrestlerController.new())
	add_child(w)
	w.strike_move = _move("strike_jab")
	var pool: Array[MoveDef] = []
	for id in STRIKES.slice(1):
		pool.append(_move(id))
	w.strike_move_pool = pool
	return w


func test_every_strike_reaches_past_the_distance_the_ai_circles_at() -> void:
	# The invariant. A strike drawn while circling has to be able to land.
	var ai: WrestlerAI = auto_free(AI.new())
	for id in STRIKES:
		var move := _move(id)
		assert_float(WrestlerController.strike_reach(move)) \
			.override_failure_message(
				"%s reaches %.3f m but WrestlerAI circles at %.2f m: every one "
				% [id, WrestlerController.strike_reach(move), ai.circle_distance]
				+ "it draws at that distance misses.") \
			.is_greater(ai.circle_distance)


func test_the_shortest_strike_still_clears_the_standoff() -> void:
	# min_standoff is the nearest the AI is willing to stand. If a strike
	# could not reach from there either, there would be no distance at which
	# the AI can both stand and hit.
	var ai: WrestlerAI = auto_free(AI.new())
	assert_float(_armed().shortest_strike_reach()).is_greater(ai.min_standoff)


func test_the_standoff_band_is_not_empty() -> void:
	# min_standoff exists because two men at 0.80 m have their arms inside
	# each other; the reach ceiling exists because a fist is only so long.
	# If the floor ever rises above the ceiling the AI has nowhere to stand.
	var ai: WrestlerAI = auto_free(AI.new())
	assert_float(ai.min_standoff).is_less(_armed().shortest_strike_reach())
	assert_float(ai.circle_distance).is_between(
		ai.min_standoff, _armed().shortest_strike_reach())


func test_the_cross_out_reaches_the_jab() -> void:
	# A rear-hand cross thrown off a rotating torso is the longer punch. It
	# was briefly the shorter one (0.550 m of reach against the jab's 0.655),
	# which is what cost the AI its spacing, and the fix was to extend the
	# clip rather than pull the standoff in.
	assert_float(WrestlerController.strike_reach(_move("strike_cross"))) \
		.is_greater(WrestlerController.strike_reach(_move("strike_jab")))


func test_the_ai_gate_is_the_pool_minimum_not_one_move() -> void:
	# shortest_strike_reach() must consider the whole pool. Reading only
	# strike_move would let the AI stand where the jab reaches and the cross
	# does not -- the exact shape of the original defect, just inverted.
	var w := _armed()
	var shortest := w.shortest_strike_reach()
	for id in STRIKES:
		assert_float(WrestlerController.strike_reach(_move(id))) \
			.is_greater_equal(shortest)


func test_a_move_with_no_contact_volume_reports_the_fallback_range() -> void:
	# Grapples and timed stubs have no authored limb, so their "reach" is the
	# proximity constant _strike_reaches() falls back to for them.
	assert_float(WrestlerController.strike_reach(MoveDef.new())) \
		.is_equal(WrestlerController.STRIKE_HIT_RANGE)
	assert_float(WrestlerController.strike_reach(null)) \
		.is_equal(WrestlerController.STRIKE_HIT_RANGE)
