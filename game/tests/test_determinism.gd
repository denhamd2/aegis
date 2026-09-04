extends GdUnitTestSuite
## compute_end_state_hash() itself: same inputs hash the same, different
## seeds hash differently.
##
## ARCHITECTURE.md names this suite as the enforcement of its hard
## determinism requirement ("same seed + same replay must always produce the
## same compute_end_state_hash()"). It is not, and never was: both cases
## below build a ReplayResource by hand and hash a two-key dictionary. No
## match runs, nothing is recorded, and nothing is played back — so they
## passed happily while ReplaySystem.advance_tick() had no callers at all
## and the replay system could not record or replay anything.
##
## They are kept, because the hash function is worth pinning down, but the
## requirement itself is enforced by tests/test_replay_roundtrip.gd, which
## records a real match and replays it.

func test_same_seed_and_replay_hash_matches() -> void:
	var replay := ReplayResource.new()
	replay.match_seed = 12345
	replay.add_frame(0, 0, {"strike": true})
	replay.add_frame(0, 1, {"strike": false})
	replay.add_frame(1, 0, {"block": true})

	var hash_a := _simulate_and_hash(replay)
	var hash_b := _simulate_and_hash(replay)

	assert_str(hash_a).is_equal(hash_b)

func test_different_seed_hash_differs() -> void:
	var replay_a := ReplayResource.new()
	replay_a.match_seed = 1
	replay_a.add_frame(0, 0, {"strike": true})

	var replay_b := ReplayResource.new()
	replay_b.match_seed = 2
	replay_b.add_frame(0, 0, {"strike": true})

	assert_str(_simulate_and_hash(replay_a)).is_not_equal(_simulate_and_hash(replay_b))

func _simulate_and_hash(replay: ReplayResource) -> String:
	var rs: Node = auto_free((load("res://core/replay/replay_system.gd") as GDScript).new())
	rs.start_playback(replay)
	var snapshot := {
		"seed": replay.match_seed,
		"frame_count": replay.duration_ticks(),
	}
	return rs.compute_end_state_hash(snapshot)
