extends GdUnitTestSuite
## WrestlerController._turn_toward_opponent() -- squares a standing wrestler
## up against its opponent.
##
## Facing used to be produced only as a side effect of movement: look_at() on
## the input direction, inside `if direction.length() > 0.1`. A wrestler with
## no movement input never turned, so the authored spawn transforms in
## match.tscn (both facing along Z while standing apart along X) survived the
## whole match -- confirmed live, forward-dot-to-opponent was exactly 0.0 on
## tick 1. Strikes and tie-ups gate on distance only, so nothing else ever
## corrected it either.

func _make_pair() -> Array:
	var wrestler: WrestlerController = auto_free(WrestlerController.new())
	var opponent: WrestlerController = auto_free(WrestlerController.new())
	for w in [wrestler, opponent]:
		# global_position is physics-server-backed and silently no-ops on a
		# CharacterBody3D outside the tree -- same reason the referee suite
		# add_child()s its wrestlers.
		add_child(w)
		w.fsm = auto_free(WrestlerFSM.new())
		w.combat = CombatSystem.new()
	wrestler.global_position = Vector3.ZERO
	wrestler.opponent = opponent
	return [wrestler, opponent]

func _forward(w: WrestlerController) -> Vector3:
	return -w.global_transform.basis.z

## Facing alignment as a dot product: 1.0 is dead-on, 0.0 perpendicular.
func _alignment(w: WrestlerController) -> float:
	var to_opponent := w.opponent.global_position - w.global_position
	to_opponent.y = 0.0
	return _forward(w).dot(to_opponent.normalized())

func test_turns_to_face_an_opponent_off_to_the_side() -> void:
	var pair := _make_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	# The match.tscn case: opponent displaced along X while we face -Z.
	opponent.global_position = Vector3(3.0, 0.0, 0.0)
	assert_float(_alignment(wrestler)).is_equal_approx(0.0, 0.001)

	for _i in 40:
		wrestler._turn_toward_opponent()

	assert_float(_alignment(wrestler)).is_equal_approx(1.0, 0.001)

func test_turns_the_short_way_around() -> void:
	var pair := _make_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	opponent.global_position = Vector3(0.0, 0.0, 3.0) # directly behind

	# A single step must move toward the target, never jump past it.
	var before := wrestler.rotation.y
	wrestler._turn_toward_opponent()
	assert_float(absf(wrestler.rotation.y - before)).is_less_equal(
		WrestlerController.TURN_RATE_PER_TICK + 0.0001
	)

	for _i in 40:
		wrestler._turn_toward_opponent()
	assert_float(_alignment(wrestler)).is_equal_approx(1.0, 0.001)

func test_already_squared_up_is_a_no_op() -> void:
	var pair := _make_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	opponent.global_position = Vector3(0.0, 0.0, -3.0) # dead ahead of -Z
	var before := wrestler.rotation.y

	wrestler._turn_toward_opponent()

	assert_float(wrestler.rotation.y).is_equal_approx(before, 0.0001)

## Overlapping positions give a zero-length direction — must not spin or NaN.
func test_ignores_a_coincident_opponent() -> void:
	var pair := _make_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	opponent.global_position = wrestler.global_position
	var before := wrestler.rotation.y

	wrestler._turn_toward_opponent()

	assert_float(wrestler.rotation.y).is_equal_approx(before, 0.0001)

func test_ignores_a_missing_opponent() -> void:
	var wrestler: WrestlerController = auto_free(WrestlerController.new())
	add_child(wrestler)
	wrestler.fsm = auto_free(WrestlerFSM.new())
	var before := wrestler.rotation.y

	wrestler._turn_toward_opponent()

	assert_float(wrestler.rotation.y).is_equal_approx(before, 0.0001)

## Circling: a wrestler who moves sideways inside fighting distance must keep
## facing the man, not turn into his own direction of travel.
##
## This was the single biggest reason strikes did not connect, and the old
## proximity hit test hid it completely: a 1.15 m sphere between two capsule
## origins does not care which way anyone points, so a wrestler could fight a
## whole match side-on and land everything. Once contact became directional,
## 49 of 50 missed strikes were off to the SIDE rather than short, at a median
## 97 degrees off the attacker's facing (tools/probe/strike_connect_probe).
##
## _turn_toward_opponent() during a strike's startup is only the backstop:
## two men circling opposite ways swing the bearing between them by about
## 0.11 rad/tick, against TURN_RATE_PER_TICK's 0.12, so an attacker who enters
## STRIKE 90 degrees off recovers roughly 8 degrees across a whole jab.
func _strafe(w: WrestlerController, ticks: int) -> void:
	# Pure lateral input: straight across the opponent, never toward him.
	for _i in ticks:
		w._process_free_movement(1.0 / 60.0, {"move": Vector2(1.0, 0.0)})

func test_keeps_facing_the_opponent_while_circling_him() -> void:
	var pair := _make_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	# Squared up at circling distance, then strafing across him.
	opponent.global_position = Vector3(0.0, 0.0, -1.1)
	for _i in 40:
		wrestler._turn_toward_opponent()
	assert_float(_alignment(wrestler)).is_equal_approx(1.0, 0.01)

	_strafe(wrestler, 30)

	assert_float(_alignment(wrestler)) \
		.override_failure_message(
			"A wrestler strafing at %.2f m turned his shoulder to his opponent"
			% wrestler.global_position.distance_to(opponent.global_position)) \
		.is_greater(0.95)

func test_faces_where_he_is_going_when_crossing_the_ring() -> void:
	# Outside fighting distance the old behaviour is the right one: a man
	# crossing the ring looks where he is running.
	var pair := _make_pair()
	var wrestler: WrestlerController = pair[0]
	var opponent: WrestlerController = pair[1]
	opponent.global_position = Vector3(
		0.0, 0.0, -(WrestlerController.FACE_OPPONENT_RANGE + 2.0))

	_strafe(wrestler, 1)

	# Input was +X, so he should be looking along +X, not at the opponent.
	assert_float(_forward(wrestler).dot(Vector3.RIGHT)) \
		.override_failure_message(
			"A wrestler crossing the ring is not facing his direction of travel") \
		.is_greater(0.95)
