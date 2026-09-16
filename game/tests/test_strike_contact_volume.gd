extends GdUnitTestSuite
## WrestlerController._strike_reaches() -- whether a strike's limb actually
## arrives on the opponent's body.
##
## What this replaced
## ------------------
## Strikes resolved on `global_position.distance_to(opponent.global_position)
## <= STRIKE_HIT_RANGE`: one 1.15 m sphere between the two capsule ORIGINS,
## shared by every strike in the game and evaluated on every tick of the
## active window. Three things followed, and all three are asserted against
## below.
##
##   * One range for four limbs. Measured on the clips the game plays, the
##     striking limb ends up 0.655 / 0.550 / 0.820 / 0.819 m in front of the
##     origin for jab / cross / kick / heavy kick. A single 1.15 m test landed
##     the jab through a third of a metre of clear air and cut both kicks
##     short of where the boot really was.
##   * No direction. test_wrestler_facing.gd's header already records that
##     "strikes and tie-ups gate on distance only"; facing was produced only
##     as a side effect of movement and was never updated during STRIKE, so a
##     punch thrown while strafing away connected with a man behind the
##     attacker's shoulder.
##   * No height, so a boot to the midsection and a jab to the jaw tested
##     identically against the opponent's origin.
##
## The offsets are baked by tools/anim/measure_contact_offsets.gd and live on
## MoveDef. These tests pin the CONSEQUENCES of those numbers rather than the
## numbers themselves, so re-measuring a clip does not automatically mean
## editing this file -- but a jab that stops reaching, or a strike that starts
## landing backwards, does.

const WRESTLER_RADIUS := 0.4

func _make_pair() -> Array:
	var wrestler: WrestlerController = auto_free(WrestlerController.new())
	var opponent: WrestlerController = auto_free(WrestlerController.new())
	for w in [wrestler, opponent]:
		# global_position is physics-server-backed and silently no-ops on a
		# CharacterBody3D outside the tree.
		add_child(w)
	wrestler.global_transform = Transform3D.IDENTITY
	wrestler.opponent = opponent
	return [wrestler, opponent]

## Puts the opponent `gap` metres directly in front (forward is -Z).
func _place(opponent: WrestlerController, gap: float) -> void:
	opponent.global_transform = Transform3D(Basis(), Vector3(0.0, 0.0, -gap))

func _move(id: String) -> MoveDef:
	return load("res://resources/moves/%s.tres" % id)

## The furthest gap at which a move still connects, to the centimetre.
func _max_reach(wrestler: WrestlerController, opponent: WrestlerController,
		move: MoveDef) -> float:
	var furthest := 0.0
	var gap := 0.30
	while gap <= 2.50:
		_place(opponent, gap)
		if wrestler._strike_reaches(move):
			furthest = gap
		gap += 0.01
	return furthest


func test_every_strike_carries_a_measured_contact_volume() -> void:
	# A move with contact_radius 0 falls back to the old proximity sphere.
	# That is correct for grapples and deliberate; for a strike it means
	# someone added one without running measure_contact_offsets.gd.
	for id in ["strike_jab", "strike_cross", "strike_kick", "strike_kick_heavy",
			"running_attack_clothesline", "running_attack_double_leg"]:
		var move := _move(id)
		assert_float(move.contact_radius) \
			.override_failure_message(
				"%s has no contact_radius: run measure_contact_offsets.gd" % id) \
			.is_greater(0.0)
		# Forward is -Z, so a strike's limb must end up at NEGATIVE z. A
		# positive one would be a strike thrown out of the back of the model,
		# which is what a sign error in the PI-Y model mount looks like.
		assert_float(move.contact_offset.z) \
			.override_failure_message("%s strikes backwards: %v"
				% [id, move.contact_offset]) \
			.is_less(0.0)


func test_each_strike_reaches_as_far_as_its_own_limb_and_no_further() -> void:
	# The whole point of the change: four moves, four different ranges,
	# each one its measured limb reach plus the body it has to arrive on.
	var pair := _make_pair()
	for id in ["strike_jab", "strike_cross", "strike_kick", "strike_kick_heavy"]:
		var move := _move(id)
		# The limb is not on the centre line -- a boot swings across, and
		# strike_kick_heavy's lands 0.148 m off it -- so the gap it reaches is
		# not simply its forward offset plus the bodies. What has to be within
		# (radius + radius) of the opponent's capsule AXIS is the contact
		# point, so the lateral offset eats into the forward budget.
		var lateral: float = move.contact_offset.x
		var span: float = WRESTLER_RADIUS + move.contact_radius
		var expected: float = -move.contact_offset.z \
				+ sqrt(span * span - lateral * lateral)
		var actual := _max_reach(pair[0], pair[1], move)
		assert_float(actual) \
			.override_failure_message(
				"%s reaches %.2f m, but its limb + body says %.2f m"
				% [id, actual, expected]) \
			.is_equal_approx(expected, 0.02)


func test_the_jab_and_the_kick_no_longer_share_a_range() -> void:
	# They did, at 1.15 m, and the boot is 0.165 m further out than the fist.
	var pair := _make_pair()
	var jab := _max_reach(pair[0], pair[1], _move("strike_jab"))
	var kick := _max_reach(pair[0], pair[1], _move("strike_kick"))
	assert_float(kick).is_greater(jab + 0.10)


func test_a_strike_does_not_land_on_a_man_behind_you() -> void:
	var pair := _make_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	for id in ["strike_jab", "strike_cross", "strike_kick", "strike_kick_heavy"]:
		var move := _move(id)
		# A gap this move definitely covers when facing the right way.
		_place(opponent, 0.80)
		wrestler.rotation.y = 0.0
		assert_bool(wrestler._strike_reaches(move)) \
			.override_failure_message("%s does not reach 0.8 m facing forward" % id) \
			.is_true()

		wrestler.rotation.y = PI
		assert_bool(wrestler._strike_reaches(move)) \
			.override_failure_message("%s lands with its back turned" % id) \
			.is_false()

		wrestler.rotation.y = PI / 2.0
		assert_bool(wrestler._strike_reaches(move)) \
			.override_failure_message("%s lands on a man 90 degrees off" % id) \
			.is_false()
	wrestler.rotation.y = 0.0


func test_a_move_with_no_contact_volume_keeps_the_proximity_test() -> void:
	# Grapples and paired moves: GrappleRig places both wrestlers itself, so
	# no limb of theirs is being aimed at anything and the old sphere is the
	# right test. Facing must NOT matter here.
	var pair := _make_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	var move := MoveDef.new()
	assert_float(move.contact_radius).is_equal(0.0)

	_place(opponent, 1.0)
	wrestler.rotation.y = 0.0
	assert_bool(wrestler._strike_reaches(move)).is_true()
	wrestler.rotation.y = PI
	assert_bool(wrestler._strike_reaches(move)).is_true()

	_place(opponent, WrestlerController.STRIKE_HIT_RANGE + 0.2)
	assert_bool(wrestler._strike_reaches(move)).is_false()
	wrestler.rotation.y = 0.0


func test_height_is_part_of_the_test() -> void:
	# The opponent's capsule spans y 0.4 .. 1.4 plus its 0.4 radius, so it
	# tops out around 1.8 -- a man's height. A jab aimed at 1.399 should miss
	# him entirely if he is standing in a hole deep enough, which is the
	# cheapest way to assert that the y component is actually read.
	var pair := _make_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	var move := _move("strike_jab")

	_place(opponent, 0.80)
	assert_bool(wrestler._strike_reaches(move)).is_true()

	opponent.global_transform = Transform3D(Basis(), Vector3(0.0, -2.0, -0.80))
	assert_bool(wrestler._strike_reaches(move)) \
		.override_failure_message("the jab connects with a man 2 m below it") \
		.is_false()
