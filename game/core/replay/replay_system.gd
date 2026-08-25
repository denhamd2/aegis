extends Node
## Autoload. Records or plays back per-tick input for every player slot, and
## produces the end-state hash the evidence gate and determinism tests
## compare across runs.
##
## Mode is exclusive: a match is either RECORDING (reading live device
## input and writing it into a ReplayResource) or PLAYING (reading a
## ReplayResource and ignoring live devices). Gameplay code should never
## read raw Input singleton state directly — always go through
## get_input(player_index) so the same code path is exercised in both modes.

enum Mode { LIVE, RECORDING, PLAYING }

var mode: Mode = Mode.LIVE
var current_tick: int = 0
var replay: ReplayResource
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func start_recording(match_seed: int) -> void:
	mode = Mode.RECORDING
	current_tick = 0
	replay = ReplayResource.new()
	replay.match_seed = match_seed
	rng.seed = match_seed

func start_playback(source: ReplayResource) -> void:
	mode = Mode.PLAYING
	current_tick = 0
	replay = source
	rng.seed = source.match_seed

func advance_tick() -> void:
	current_tick += 1

func record_input(player_index: int, input: Dictionary) -> void:
	if mode == Mode.RECORDING:
		replay.add_frame(player_index, current_tick, input)

func get_input(player_index: int, live_input: Dictionary) -> Dictionary:
	if mode == Mode.PLAYING:
		return replay.get_frame(player_index, current_tick)
	if mode == Mode.RECORDING:
		record_input(player_index, live_input)
	return live_input

## Combines match-relevant state into a single hash. Called at match end
## by the capture harness; two runs of the same replay must match.
func compute_end_state_hash(state_snapshot: Dictionary) -> String:
	var keys: Array = state_snapshot.keys()
	keys.sort()
	var parts: Array = []
	for k in keys:
		parts.append("%s=%s" % [k, str(state_snapshot[k])])
	return String(",".join(parts)).sha256_text()
