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


## Beside the chest, not the boots. The first version offset along -Z and put
## the coverer down by the feet, because a prone wrestler's node keeps his
## standing yaw and the body runs up +Z from it -- measured, Head sits at
## local z=+1.25 and foot_l at z=-0.26.
func test_the_coverer_kneels_beside_the_downed_mans_chest() -> void:
	var pair := _pair()
	var attacker: WrestlerController = pair[0]
	var defender: WrestlerController = pair[1]
	defender.global_position = Vector3(1.0, 0.0, -2.0)
	defender.rotation.y = 0.0
	attacker.global_position = Vector3(-3.0, 0.0, 3.0)

	attacker.begin_pin(defender, 1)

	var local: Vector3 = defender.global_transform.affine_inverse() \
			* attacker.global_position
	# Up the body toward the head, and off to one side. Both signs matter:
	# a negative z here is the bug that put him at the boots.
	assert_float(local.z).is_equal_approx(
			WrestlerController.COVER_TOWARD_HEAD_M, 0.01)
	assert_float(absf(local.x)).is_equal_approx(
			WrestlerController.COVER_LATERAL_M, 0.01)


## Facing the man he is covering. Without this he kneels with his back to him,
## which reads as two men who happen to be near each other.
func test_the_coverer_faces_the_downed_man() -> void:
	var pair := _pair()
	var attacker: WrestlerController = pair[0]
	var defender: WrestlerController = pair[1]
	defender.global_position = Vector3(0.0, 0.0, 0.0)
	defender.rotation.y = 0.0
	attacker.begin_pin(defender, 1)

	var to_defender := defender.global_position - attacker.global_position
	to_defender.y = 0.0
	# -Z is forward, the same convention _turn_toward_opponent() uses.
	var forward := -attacker.global_transform.basis.z
	forward.y = 0.0
	assert_float(forward.normalized().dot(to_defender.normalized())) \
		.override_failure_message("the coverer is not facing the man he pins") \
		.is_greater(0.95)


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
