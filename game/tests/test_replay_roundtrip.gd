extends GdUnitTestSuite
## Recording and playback of a real match.
##
## ARCHITECTURE.md makes "same seed + same replay produces the same
## end-state hash" a hard requirement and names test_determinism.gd as its
## enforcement. That suite only ever checked that compute_end_state_hash()
## is a pure function of a hand-built dictionary -- it never ran a match,
## recorded, or played anything back. Underneath it,
## ReplaySystem.advance_tick() had no callers at all, so current_tick sat at
## 0 for whole matches: a recording overwrote frame 0 on every tick and kept
## only the last one, and playback fed that single frame to every tick of
## the match. Nothing tested it, so nothing noticed.
##
## These are the tests that would have noticed.

const MATCH_SCENE := "res://scenes/match.tscn"
## Long enough for both wrestlers to close, tie up and trade input, short
## enough to keep the suite fast -- the point is that the two runs agree,
## not that the match finishes.
const SIMULATED_FRAMES := 90

func _replay_system() -> Node:
	return auto_free((load("res://core/replay/replay_system.gd") as GDScript).new())

func test_recording_without_advancing_keeps_only_one_tick() -> void:
	var rs := _replay_system()
	rs.start_recording(1)
	for i in 10:
		rs.get_input(0, {"strike": i % 2 == 0})
	assert_int(rs.replay.duration_ticks()).override_failure_message(
		"A recording that never advances its tick counter collapses to one "
		+ "frame -- this is the shape of the bug, asserted so the fix stays."
	).is_equal(1)

func test_advancing_the_tick_records_one_frame_per_tick() -> void:
	var rs := _replay_system()
	rs.start_recording(1)
	for i in 10:
		rs.get_input(0, {"strike": i % 2 == 0})
		rs.advance_tick()
	assert_int(rs.replay.duration_ticks()).is_equal(10)

func test_playback_returns_each_tick_its_own_recorded_input() -> void:
	var recorder := _replay_system()
	recorder.start_recording(4)
	var sent: Array[Dictionary] = []
	for i in 12:
		var input := {"strike": i % 3 == 0, "grapple": i % 4 == 0}
		sent.append(input)
		recorder.get_input(0, input)
		recorder.advance_tick()

	var player := _replay_system()
	player.start_playback(recorder.replay)
	var received: Array[Dictionary] = []
	for i in 12:
		# The live input passed in is deliberately wrong: in PLAYING mode it
		# must be ignored entirely in favour of the recording.
		received.append(player.get_input(0, {"strike": true, "grapple": true}))
		player.advance_tick()
	assert_array(received).is_equal(sent)

## The scene-level half: a real match, recorded, then replayed.
##
## Simulated frames are process frames, and physics runs at roughly half
## that rate here -- so the assertions below are about the recording growing
## with the match, never about an exact frame:tick ratio.
func test_a_recorded_match_spans_its_whole_run() -> void:
	# _run_and_sample() rather than a bare runner because it also frees the
	# match afterwards; a match scene left in the tree is ~40 orphan nodes.
	await _run_and_sample(load(MATCH_SCENE).instantiate())
	assert_int(ReplaySystem.replay.duration_ticks()).override_failure_message(
		"A recorded match should hold one frame per physics tick it ran for, "
		+ "not a single overwritten frame."
	).is_greater(10)

## Compared tick by tick rather than only at the end: sampling both runs
## into a tick -> state map and asserting they agree on every tick they
## share is both stronger than a single end-state comparison and immune to
## the two runs getting a different number of process frames.
func test_replaying_a_recorded_match_reproduces_it() -> void:
	var recorded_path := "user://test_roundtrip_replay.tres"

	var recorded := await _run_and_sample(load(MATCH_SCENE).instantiate())
	assert_int(ResourceSaver.save(ReplaySystem.replay, recorded_path)).is_equal(OK)

	var scene: Node = load(MATCH_SCENE).instantiate()
	# Set before the runner puts it in the tree, so MatchSetup._ready() sees
	# it and starts playback instead of a fresh recording.
	scene.playback_replay_path = recorded_path
	var replayed := await _run_and_sample(scene)

	assert_bool(ReplaySystem.mode == ReplaySystem.Mode.PLAYING) \
		.override_failure_message("Second run never entered playback").is_true()

	var shared: Array[int] = []
	for tick: int in recorded:
		if replayed.has(tick):
			shared.append(tick)
	assert_int(shared.size()).override_failure_message(
		"The two runs shared no ticks to compare"
	).is_greater(5)

	var diverged: Array[String] = []
	for tick: int in shared:
		if recorded[tick] != replayed[tick]:
			diverged.append("tick %d" % tick)
	assert_array(diverged).override_failure_message(
		"Replay diverged from the recording at: %s" % [diverged]
	).is_empty()

func _run_and_sample(scene: Node) -> Dictionary:
	var runner := scene_runner(scene)
	var samples := {}
	for _i in SIMULATED_FRAMES:
		await runner.simulate_frames(1)
		samples[ReplaySystem.current_tick] = _snapshot(scene)
	# Freed before the next run starts. scene_runner only auto-frees a scene
	# it loaded by path itself, and a match left in the tree keeps ticking --
	# two live matches then write to the same ReplaySystem autoload and the
	# comparison below measures interference rather than replay fidelity.
	if scene.get_parent():
		scene.get_parent().remove_child(scene)
	scene.free()
	await await_idle_frame()
	return samples

func _snapshot(scene: Node) -> String:
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	return ReplaySystem.compute_end_state_hash({
		"a_state": a.fsm.current_state,
		"b_state": b.fsm.current_state,
		"a_damage": "%.4f" % a.combat.total_damage(),
		"b_damage": "%.4f" % b.combat.total_damage(),
		"a_momentum": "%.4f" % a.combat.momentum,
		"b_momentum": "%.4f" % b.combat.momentum,
		"a_pos": "%.3v" % a.global_position,
		"b_pos": "%.3v" % b.global_position,
	})

## A pin's kickout window has to differ between pins but be reproducible
## from the replay. It was seeded with Engine.get_physics_frames(), which is
## a *process*-global counter -- so replaying the same recording in a process
## that reached the pin at a different global frame handed the defender a
## different window, and the same inputs produced a different match.
##
## The seed must move with the match's own tick and with nothing else, which
## is what this checks: let real process (and physics) frames go by without
## advancing the match's tick, and the seed must not budge.
func test_the_pin_seed_ignores_how_long_the_process_has_been_running() -> void:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	referee.match_seed = 42
	ReplaySystem.start_recording(42)

	var before := referee._pin_seed()
	var physics_before := Engine.get_physics_frames()
	for _i in 8:
		await await_idle_frame()
	assert_int(Engine.get_physics_frames()).override_failure_message(
		"No physics frames elapsed, so this test proved nothing"
	).is_greater(physics_before)

	assert_int(referee._pin_seed()).override_failure_message(
		"The pin seed moved without the match tick moving -- it is reading "
		+ "process-global state again."
	).is_equal(before)

func test_the_pin_seed_moves_with_the_match_tick() -> void:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	referee.match_seed = 42
	ReplaySystem.start_recording(42)
	var first := referee._pin_seed()
	ReplaySystem.advance_tick()
	assert_int(referee._pin_seed()).override_failure_message(
		"Every pin in a match would get the same kickout window"
	).is_not_equal(first)
