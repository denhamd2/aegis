extends GdUnitTestSuite
## A wrestler cannot leave the ring, by any route.
##
## He could. Measured on seed 4 of tools/probe/strike_connect_probe.tscn:
## WrestlerB was walked out to x = -3.07 over six ticks of a GRAPPLE_HOLD,
## past the mat's own edge at 3.0 and out over a stretch of arena that has no
## floor collider under it at all -- scenes/ring.tscn's floor is 6 m square and
## nothing else in the scene is walkable. He fell for the remaining 17 000
## ticks of that match and finished 411 490 m below the mat.
##
## Everything downstream then read as something else. The match could not end,
## because a pinfall needs the attacker within COVER_RANGE of a downed man.
## Every strike thrown at him was recorded as a miss "off to the side" at a
## median 0 degrees off the attacker's facing -- facing him, horizontally
## inside reach, separated only in a dimension the miss report does not print.
## That one seed contributed 383 of the 386 misses in a four-seed run and took
## the measured connect rate from 70% to 10%.
##
## The route out was GrappleRig, which SUSPENDS both bodies for the length of
## a paired move and drives their transforms from the clip. A suspended body
## collides with nothing, so the rope walls are not in that code path at all,
## and the rig's own clamp is on the pair's MIDPOINT -- each wrestler still
## sits an authored offset away from it, and the offsets reach past the mat.
##
## So the containment is asserted per wrestler and from both paths that can
## move one.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")
const OUTSIDE := 6.0


func _wrestler() -> WrestlerController:
	var wrestler: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(wrestler)
	return wrestler


func test_the_keep_in_extent_leaves_the_whole_body_on_the_mat() -> void:
	# Geometry, not taste: the mat is 6 m square and the capsule is 0.4, so a
	# wrestler clamped to 2.6 has his far side exactly on the edge.
	assert_float(WrestlerController.RING_KEEP_IN
			+ WrestlerController.BODY_RADIUS) \
		.override_failure_message(
			"a wrestler at RING_KEEP_IN hangs over the edge of the mat") \
		.is_less_equal(RingBuilder.MAT_HALF)


func test_the_keep_in_extent_never_fights_the_ropes() -> void:
	# The rope walls are 0.3 thick at +-3.1, so their inner faces are at 2.95
	# and move_and_slide() holds a walking man at 2.95 - 0.4 = 2.55. The
	# backstop has to sit OUTSIDE that, or it would be shoving wrestlers around
	# during ordinary play instead of only catching bodies that never collided
	# with anything.
	var rope_stop := 3.1 - 0.15 - WrestlerController.BODY_RADIUS
	assert_float(WrestlerController.RING_KEEP_IN).is_greater(rope_stop)


func test_a_wrestler_put_outside_the_ring_is_put_back() -> void:
	for corner: Vector3 in [Vector3(OUTSIDE, 0.0, 0.0), Vector3(-OUTSIDE, 0.0, 0.0),
			Vector3(0.0, 0.0, OUTSIDE), Vector3(0.0, 0.0, -OUTSIDE),
			Vector3(OUTSIDE, 0.0, -OUTSIDE)]:
		var wrestler := _wrestler()
		wrestler.global_position = corner
		wrestler.keep_inside_the_ring()
		assert_float(absf(wrestler.global_position.x)) \
			.override_failure_message("still outside on X from %s" % corner) \
			.is_less_equal(WrestlerController.RING_KEEP_IN + 0.001)
		assert_float(absf(wrestler.global_position.z)) \
			.override_failure_message("still outside on Z from %s" % corner) \
			.is_less_equal(WrestlerController.RING_KEEP_IN + 0.001)


func test_a_wrestler_below_the_mat_is_put_back_on_it_and_stops_falling() -> void:
	var wrestler := _wrestler()
	wrestler.global_position = Vector3(0.0, -50.0, 0.0)
	wrestler.velocity = Vector3(0.0, -30.0, 0.0)
	wrestler.keep_inside_the_ring()
	assert_float(wrestler.global_position.y).is_equal_approx(
			WrestlerController.MAT_LEVEL, 0.001)
	# Left falling, he would drop straight back through on the next tick.
	assert_float(wrestler.velocity.y).is_equal_approx(0.0, 0.001)


func test_a_wrestler_lifted_off_the_mat_is_left_alone() -> void:
	# The clamp is one-sided on purpose. Every throw in the paired set carries
	# a man well clear of the mat, and a ceiling here would flatten all of
	# them.
	var wrestler := _wrestler()
	wrestler.global_position = Vector3(0.5, 1.4, -0.5)
	wrestler.velocity = Vector3(0.0, -2.0, 0.0)
	wrestler.keep_inside_the_ring()
	assert_vector(wrestler.global_position).is_equal_approx(
			Vector3(0.5, 1.4, -0.5), Vector3.ONE * 0.001)
	assert_float(wrestler.velocity.y).is_equal_approx(-2.0, 0.001)


func test_a_wrestler_already_inside_is_not_nudged() -> void:
	# It runs every tick on both men for the whole match, so a clamp that
	# rewrote the transform when it did not need to would be a per-tick source
	# of drift in a system whose whole contract is determinism.
	var wrestler := _wrestler()
	var where := Vector3(1.9, 0.0, -2.2)
	wrestler.global_position = where
	wrestler.velocity = Vector3(3.0, -9.0, 1.0)
	wrestler.keep_inside_the_ring()
	assert_vector(wrestler.global_position).is_equal_approx(where, Vector3.ONE * 0.0001)
	assert_vector(wrestler.velocity).is_equal_approx(
			Vector3(3.0, -9.0, 1.0), Vector3.ONE * 0.0001)


func test_the_grapple_rig_contains_the_bodies_it_has_suspended() -> void:
	# The route that actually let a man out. GrappleRig drives suspended
	# transforms from its own _physics_process, so that is where the clamp has
	# to be reached from -- the wrestler's own _physics_process is off.
	var rig: GrappleRig = auto_free(GrappleRig.new())
	add_child(rig)
	var anchor: Marker3D = Marker3D.new()
	rig.add_child(anchor)
	rig.anchor = anchor

	var attacker := _wrestler()
	var defender := _wrestler()
	attacker.global_position = Vector3(1.0, 0.0, 0.0)
	defender.global_position = Vector3(2.0, 0.0, 0.0)
	rig._attacker = attacker
	rig._defender = defender
	rig._active = true

	defender.global_position = Vector3(OUTSIDE, 0.0, 0.0)
	rig._physics_process(1.0 / 60.0)

	assert_float(defender.global_position.x) \
		.override_failure_message(
			"a suspended body is still outside the ring after a rig tick") \
		.is_less_equal(WrestlerController.RING_KEEP_IN + 0.001)
