class_name ReplayResource
extends Resource
## A recorded match: seed plus one input frame per physics tick for each
## player slot. Deterministic playback depends on nothing else varying —
## same seed + same frames must always yield the same end-state hash.

@export var match_seed: int = 0
@export var tick_rate: int = 60
## Array[Array[Dictionary]] — frames[player_index][tick] = input dict.
@export var frames: Array = []

func add_frame(player_index: int, tick: int, input: Dictionary) -> void:
	while frames.size() <= player_index:
		frames.append([])
	var player_frames: Array = frames[player_index]
	while player_frames.size() <= tick:
		player_frames.append({})
	player_frames[tick] = input

func get_frame(player_index: int, tick: int) -> Dictionary:
	if player_index >= frames.size():
		return {}
	var player_frames: Array = frames[player_index]
	if tick >= player_frames.size():
		return {}
	return player_frames[tick]

func duration_ticks() -> int:
	var max_ticks := 0
	for player_frames in frames:
		max_ticks = max(max_ticks, player_frames.size())
	return max_ticks
