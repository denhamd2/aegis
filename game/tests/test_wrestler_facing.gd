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
