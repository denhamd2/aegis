extends GdUnitTestSuite
## Illegal FSM transitions assert; legal ones succeed and emit state_changed.

func test_legal_transition_succeeds() -> void:
	var fsm: WrestlerFSM = auto_free(WrestlerFSM.new())
	fsm.transition_to(WrestlerFSM.State.LOCOMOTION)
	assert_int(fsm.current_state).is_equal(WrestlerFSM.State.LOCOMOTION)

func test_illegal_transition_asserts() -> void:
	var fsm: WrestlerFSM = auto_free(WrestlerFSM.new())
	# IDLE -> FINISHER is not in LEGAL_TRANSITIONS[IDLE]. GDScript's assert()
	# prefixes the message with "Assertion failed: " when it fires, and
	# gdUnit4's is_runtime_error() matches the logged message exactly
	# (no regex support), so the expected string must match verbatim.
	await assert_error(func(): fsm.transition_to(WrestlerFSM.State.FINISHER)) \
		.is_runtime_error("Assertion failed: Illegal FSM transition: IDLE -> FINISHER")
