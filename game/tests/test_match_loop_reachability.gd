extends GdUnitTestSuite
## Does the live match actually *reach* the grapple chain, and leave it
## cleanly?
##
## This is the coverage gap behind Priority 2 of
## gauntlet/status/roman_reigns_next.md. The four claims it asks about were
## all true when this suite was written -- but nothing tested them. Every
## other grapple assertion in the suite is either a direct unit call into
## WrestlerController._process_grapple_hold() or a check on a resource
## table; test_replay_roundtrip.gd is the only suite that runs a real match
## scene, and it asserts determinism, not reachability. So "a tie-up is
## reachable in play" and "both wrestlers leave a paired move" were
## properties nobody would notice losing.
##
## Three of the four claims had already been fixed in code by the time they
## were measured (tie-up entry, pending-hit resolution and reversal
## arbitration were moved off the scene-tree-order path into MatchReferee).
## These tests exist so they stay fixed.
##
## Kept to one live match rather than a sweep of seeds -- the per-seed
## survey is the reachability probe's job
## (tools/probe/reachability_probe.tscn, which runs matches to their
## finish); this is the regression net, and it has to stay cheap enough
## that the suite is still worth running.

const MATCH_SCENE := "res://scenes/match.tscn"
## Enough process frames to get past a first tie-up and a few grapple
## moves. Physics runs at roughly half the process rate under the runner
## (see test_replay_roundtrip.gd), and the probe measured the first tie-up
## landing around tick 51 with grapple moves following steadily after -- so
## this is several grapples' worth, not a single lucky one.
const SIMULATED_FRAMES := 600
## States a wrestler must not be in on the tick after a paired move lands.
## The attacker resolves to IDLE and the defender to DOWN or HIT_REACT, all
## within _resolve_grapple_move()'s own single _physics_process, so anything
## still holding the grapple here failed to hand off. Stated as a deny-list
## for the reason the probe's own copy is: the set of *legitimate* next
## states is wide (the AI can open a strike, walk in for a cover, or be
## pulled into the next tie-up on that very tick), and an allow-list
## reported all of those as failures.
const STRANDED_AFTER_HANDOFF := ["GRAPPLE_HOLD", "MOVE_EXEC"]

var _observed: Dictionary = {}

## Runs one AI-vs-AI match and records what it reached. Cached across the
## test cases in this suite so the match runs once, not once per assertion.
func _match_observations() -> Dictionary:
	if not _observed.is_empty():
		return _observed

	var scene: Node = load(MATCH_SCENE).instantiate()
	scene.match_seed = 3
	var runner := scene_runner(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")

	# match.tscn ships WrestlerA as the human slot, and MatchSetup only puts
	# both sides on the AI for a recording run -- an AI-vs-passive match is
	# "an infinite strike loop that never reaches a finish"
	# (match_setup.gd), and a passive wrestler never presses grapple, so it
	# loses every tie-up 0-10 and no grapple chain is reachable at all.
	for w: WrestlerController in [a, b]:
		w.is_ai = true
		if w.ai:
			w.ai.setup_jitter(3, w.player_index)

	var result := {
		"tie_up_entries": {a.name: 0, b.name: 0},
		"simultaneous_tie_ups": 0,
		"landed": 0,
		"stranded_after_handoff": [],
		"states_seen": {},
	}
	var landed_this_frame := [false]
	var on_landed := func(_attacker: WrestlerController, _defender: WrestlerController,
			_move: MoveDef) -> void:
		result["landed"] += 1
		landed_this_frame[0] = true
	a.move_landed.connect(on_landed)
	b.move_landed.connect(on_landed)

	var last_state := {a.name: -1, b.name: -1}
	var check_handoff_next := false
	for _i in SIMULATED_FRAMES:
		await runner.simulate_frames(1)

		if check_handoff_next:
			check_handoff_next = false
			for w: WrestlerController in [a, b]:
				var name_of: String = WrestlerFSM.State.keys()[w.fsm.current_state]
				if STRANDED_AFTER_HANDOFF.has(name_of):
					result["stranded_after_handoff"].append("%s in %s" % [w.name, name_of])
		if landed_this_frame[0]:
			landed_this_frame[0] = false
			check_handoff_next = true

		var both_tied_up := true
		for w: WrestlerController in [a, b]:
			var state_name: String = WrestlerFSM.State.keys()[w.fsm.current_state]
			result["states_seen"][state_name] = true
			if w.fsm.current_state != last_state[w.name]:
				last_state[w.name] = w.fsm.current_state
				if w.fsm.current_state == WrestlerFSM.State.TIE_UP:
					result["tie_up_entries"][w.name] += 1
			if w.fsm.current_state != WrestlerFSM.State.TIE_UP:
				both_tied_up = false
		if both_tied_up:
			result["simultaneous_tie_ups"] += 1

	# A match left in the tree keeps ticking and keeps writing to the
	# ReplaySystem autoload -- same reason test_replay_roundtrip.gd frees
	# its scenes by hand.
	if scene.get_parent():
		scene.get_parent().remove_child(scene)
	scene.free()
	await await_idle_frame()

	_observed = result
	return _observed

## The AI closes and a tie-up actually happens. This is the floor: without
## it, every grapple, power, signature and finisher move in the game is
## unreachable in play, however well its resource is authored.
func test_a_live_match_reaches_a_tie_up() -> void:
	var observed := await _match_observations()
	var total: int = 0
	for who: String in observed["tie_up_entries"]:
		total += observed["tie_up_entries"][who]
	assert_int(total).override_failure_message(
		"No tie-up in %d frames. The AI never closed to TIE_UP_RANGE, or "
		% SIMULATED_FRAMES + "entry is gated shut. States reached: %s"
		% str(observed["states_seen"].keys())
	).is_greater(0)

## Both wrestlers enter tie-up together, on the same tick.
##
## Entry used to be an inline opponent.fsm.transition_to(TIE_UP) inside
## whichever wrestler's _process_free_movement() ran first, so the other
## side's FSM changed mid-tick, before its own _physics_process -- and its
## AI then started counting mash ticks one tick early, every time,
## regardless of either wrestler's behaviour. MatchReferee._try_start_tie_up()
## now flips both FSMs in one call, after both wrestlers have run.
func test_both_wrestlers_enter_tie_up_together() -> void:
	var observed := await _match_observations()
	var counts: Array[int] = []
	for who: String in observed["tie_up_entries"]:
		counts.append(observed["tie_up_entries"][who])
	assert_int(counts[0]).override_failure_message(
		"One wrestler entered TIE_UP without the other: %s. Entry is "
		% str(observed["tie_up_entries"]) + "one-sided again."
	).is_equal(counts[1])
	assert_int(observed["simultaneous_tie_ups"]).override_failure_message(
		"The two never held TIE_UP on the same frame, so they were not in "
		+ "the same contest."
	).is_greater(0)

## A paired move actually resolves in play. move_landed is emitted only by
## WrestlerController._resolve_grapple_move(), which is reached from
## _process_grapple_hold() through the normal _physics_process dispatch --
## so this also witnesses that selection runs on the live controller path
## and not only through a test or capture harness calling into it.
func test_a_live_match_reaches_a_grapple_move() -> void:
	var observed := await _match_observations()
	assert_int(observed["landed"]).override_failure_message(
		"A tie-up was reached but no grapple move ever landed -- selection "
		+ "is not resolving through the controller path."
	).is_greater(0)

## Both wrestlers leave the paired move. GRAPPLE_HOLD and MOVE_EXEC have no
## timeout of their own; if a handoff fails, both sides are stuck there for
## the rest of the match with nothing able to pull them out.
func test_both_wrestlers_leave_a_paired_move_cleanly() -> void:
	var observed := await _match_observations()
	assert_int(observed["landed"]).override_failure_message(
		"No grapple move landed, so no handoff was observed"
	).is_greater(0)
	assert_array(observed["stranded_after_handoff"]).override_failure_message(
		"Still holding the grapple on the tick after it resolved: %s"
		% str(observed["stranded_after_handoff"])
	).is_empty()

## MOVE_EXEC is entered and left inside a single _physics_process for a
## rig-driven move (_resolve_grapple_move() transitions in and straight back
## out), so it should never be observable on a frame boundary. If it starts
## showing up, the synchronous handoff has become asynchronous and the
## reversal reasoning in MatchReferee._check_for_reversal() -- which skips
## MOVE_EXEC precisely because it cannot be observed -- no longer holds.
func test_move_exec_never_survives_a_frame() -> void:
	var observed := await _match_observations()
	assert_bool(observed["states_seen"].has("MOVE_EXEC")).override_failure_message(
		"MOVE_EXEC was observable on a frame boundary. A rig-driven grapple "
		+ "is supposed to enter and leave it within one _physics_process."
	).is_false()
