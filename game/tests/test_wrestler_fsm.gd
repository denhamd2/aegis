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

## --- ENTRANCE ---------------------------------------------------------------
##
## The walk to the ring is a real FSM state rather than something bolted on
## outside the machine, because WrestlerController builds its blend graph from
## LEGAL_TRANSITIONS and STATE_ANIMATIONS -- a pose the FSM does not know about
## has no node to cross-fade out of when the match starts.
##
## It is also the only state in the enum that no MATCH state can reach, and
## these tests are what keeps it that way. A wrestler who could walk out of a
## tie-up would be a wrestler who stopped fighting mid-match.

func test_a_wrestler_can_be_sent_out_for_his_entrance_from_idle() -> void:
	var fsm: WrestlerFSM = auto_free(WrestlerFSM.new())
	fsm.transition_to(WrestlerFSM.State.ENTRANCE)
	assert_int(fsm.current_state).is_equal(WrestlerFSM.State.ENTRANCE)

func test_the_entrance_hands_off_to_idle() -> void:
	var fsm: WrestlerFSM = auto_free(WrestlerFSM.new())
	fsm.transition_to(WrestlerFSM.State.ENTRANCE)
	fsm.transition_to(WrestlerFSM.State.IDLE)
	assert_int(fsm.current_state).is_equal(WrestlerFSM.State.IDLE)

## IDLE is the only way in. Every other state is a match state, and the match
## has not started while anybody is on the ramp.
func test_idle_is_the_only_state_that_leads_into_the_entrance() -> void:
	for state: int in WrestlerFSM.State.values():
		if state == WrestlerFSM.State.IDLE:
			continue
		var legal: Array = WrestlerFSM.LEGAL_TRANSITIONS.get(state, [])
		assert_bool(legal.has(WrestlerFSM.State.ENTRANCE)) \
			.override_failure_message(
				"%s can reach ENTRANCE; only IDLE may"
				% WrestlerFSM.State.keys()[state]) \
			.is_false()

## And IDLE is the only way out, so nothing can be done from the ramp.
func test_the_entrance_leads_nowhere_but_idle() -> void:
	assert_array(WrestlerFSM.LEGAL_TRANSITIONS[WrestlerFSM.State.ENTRANCE]) \
		.is_equal([WrestlerFSM.State.IDLE])

## Appending ENTRANCE rather than inserting it kept every match state's ordinal
## where it was. Nothing serialises those today, but the enum is read by index
## in several probes' output and this is the cheap guard on a future insert.
func test_appending_the_entrance_left_the_match_states_where_they_were() -> void:
	assert_int(WrestlerFSM.State.IDLE).is_equal(0)
	assert_int(WrestlerFSM.State.VICTORY).is_equal(
		WrestlerFSM.State.ENTRANCE - 1)
