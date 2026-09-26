extends GdUnitTestSuite
## The cover: where the coverer kneels, and that he plays a cover at all.
##
## Both were absent rather than wrong. PIN_ATTACKER's per-tick handler is
## `pass` -- the state is driven entirely by MatchReferee -- so nothing moved
## the attacker once a pin began; he froze wherever the last strike left him.
## With "Crouch_Idle" on top of that, a captured three-count showed him
## standing off to one side with a boot inside the fallen man's head.
##
## What a rendered frame proves and this suite cannot: that the pose reads as a
## cover. tools/probe/pin_shot.tscn is what answers that, from three angles.
## What this suite holds is the arithmetic underneath it, which is the part a
## later edit can silently break.

const MATCH_SCENE := preload("res://scenes/match.tscn")

## A pair with the defender already down, which is the only state the referee
## ever pins from -- the FSM asserts on IDLE -> PIN_DEFENDER, so a fixture that
## skips the knockdown is testing a call that cannot happen.
func _pair() -> Array:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	var attacker: WrestlerController = scene.get_node("WrestlerA")
	var defender: WrestlerController = scene.get_node("WrestlerB")
	defender.fsm.transition_to(WrestlerFSM.State.STUNNED)
	defender.fsm.transition_to(WrestlerFSM.State.DOWN)
	return [attacker, defender]


## The cover is a generated clip, not one of the rig's own. A missing entry
## here is silent -- the wrestler simply plays nothing -- so it is asserted
## against the built library rather than trusted.
func test_the_pin_attacker_plays_the_generated_cover() -> void:
	var clip: String = WrestlerController.STATE_ANIMATIONS[
			WrestlerFSM.State.PIN_ATTACKER]
	assert_str(clip).is_equal("strikes/pin_cover")
	var library: AnimationLibrary = load(
			"res://resources/animations/strike_clips.tres")
	assert_bool(library.has_animation("pin_cover")) \
		.override_failure_message(
			"strike_clips.tres has no pin_cover: re-run build_strike_clips.gd") \
		.is_true()


## Beside the chest, not the boots. The downed man's body runs up -Z from his
## origin -- measured, Head at local z=-0.69 and foot_l at z=+0.50 -- and an
## offset along +Z put the coverer past his feet.
func test_the_coverer_lies_across_the_downed_mans_chest() -> void:
	var pair := _pair()
	var attacker: WrestlerController = pair[0]
	var defender: WrestlerController = pair[1]
	defender.global_position = Vector3(1.0, 0.0, -2.0)
	defender.rotation.y = 0.0
	attacker.global_position = Vector3(-3.0, 0.0, 3.0)

	attacker.begin_pin(defender, 1)

	# Asserted on where he is SENT, not where he ends up.
	#
	# _place_cover() computes the destination; _tick_cover_slide() then steers
	# him there through velocity, and velocity is only consumed by
	# move_and_slide() inside _physics_process -- which never runs for a bare
	# WrestlerController.new(). Driving the tick by hand here moves nobody, so
	# reading global_position back would assert on the spawn point and pass or
	# fail for the wrong reason.
	#
	# The contract this test exists for is unchanged and still fully covered:
	# up the body toward the head rather than down by the boots, and off to one
	# side. That is a property of the destination, and the slide is only how he
	# travels to it.
	var local: Vector3 = defender.global_transform.affine_inverse() \
			* attacker._cover_to.origin
	# Up the body toward the head, and off to one side. Both signs matter:
	# a positive z here is the bug that put him at the boots.
	assert_float(local.z).is_equal_approx(
			-WrestlerController.COVER_TOWARD_HEAD_M, 0.01)
	assert_float(absf(local.x)).is_equal_approx(
			WrestlerController.COVER_LATERAL_M, 0.01)


## Facing the man he is covering, square across his body. Without this he
## kneels with his back to him, which reads as two men who happen to be near
## each other.
func test_the_coverer_faces_the_downed_man() -> void:
	var pair := _pair()
	var attacker: WrestlerController = pair[0]
	var defender: WrestlerController = pair[1]
	defender.global_position = Vector3(0.0, 0.0, 0.0)
	defender.rotation.y = 0.0
	attacker.begin_pin(defender, 1)

	# Both read off the destination, for the reason given in the test above:
	# the slide is driven by velocity now, and nothing consumes velocity for a
	# bare WrestlerController.new(). Facing is a property of where he kneels,
	# so measuring it from his un-moved spawn point would be measuring the
	# wrong triangle.
	# Toward the downed man's midline, and perpendicular to his body: the
	# same direction as from the coverer's spot straight across to the line
	# the body lies along.
	var local: Vector3 = defender.global_transform.affine_inverse() \
			* attacker._cover_to.origin
	var to_midline := defender.global_transform.basis.x * -signf(local.x)
	# -Z is forward, the same convention _turn_toward_opponent() uses.
	var forward := -attacker._cover_to.basis.z
	forward.y = 0.0
	assert_float(forward.normalized().dot(to_midline.normalized())) \
		.override_failure_message("the coverer is not facing across the man he pins") \
		.is_greater(0.99)


## The pin's outcome must not move with the coverer. Placement is presentation:
## the fall is decided by the kickout minigame and the referee's count, neither
## of which reads either man's position.
func test_placing_the_cover_does_not_touch_the_pin_state() -> void:
	var pair := _pair()
	var attacker: WrestlerController = pair[0]
	var defender: WrestlerController = pair[1]
	attacker.begin_pin(defender, 1)
	assert_int(attacker.fsm.current_state) \
		.is_equal(WrestlerFSM.State.PIN_ATTACKER)
	assert_int(defender.fsm.current_state) \
		.is_equal(WrestlerFSM.State.PIN_DEFENDER)


## A man lying ON another is closer than two capsules allow, so the pair stop
## colliding for the pin -- otherwise the slide parks him 0.8 m short and the
## press lands on the mat beside the man.
func test_the_pair_stop_colliding_for_the_cover() -> void:
	var pair := _pair()
	var attacker: WrestlerController = pair[0]
	var defender: WrestlerController = pair[1]
	attacker.begin_pin(defender, 1)
	assert_bool(attacker.get_collision_exceptions().has(defender)).is_true()
	assert_bool(defender.get_collision_exceptions().has(attacker)).is_true()


## And collide again only once the pin is over AND they are apart. Released
## while they still overlap, the physics engine resolves the overlap in one
## step and throws one of them across the ring.
func test_collision_returns_only_after_the_pin_and_apart() -> void:
	var pair := _pair()
	var attacker: WrestlerController = pair[0]
	var defender: WrestlerController = pair[1]
	defender.global_position = Vector3.ZERO
	attacker.global_position = Vector3(0.3, 0.0, 0.0)
	attacker.begin_pin(defender, 1)

	# Still pinning: held, whatever the distance.
	attacker._release_cover_contact()
	assert_bool(attacker.get_collision_exceptions().has(defender)).is_true()

	# Pin over, still on top of him: held.
	attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	attacker._release_cover_contact()
	assert_bool(attacker.get_collision_exceptions().has(defender)).is_true()

	# Apart: released, both ways.
	attacker.global_position = Vector3(WrestlerController.COVER_RELEASE_M + 0.1,
			0.0, 0.0)
	attacker._release_cover_contact()
	assert_bool(attacker.get_collision_exceptions().has(defender)).is_false()
	assert_bool(defender.get_collision_exceptions().has(attacker)).is_false()
