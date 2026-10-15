class_name CrowdChants
extends Node
## Recorded crowd chants, timed only from the opening bell. No chant is played
## over entrances; the match bed continues underneath each faded-in sample.

const CODY_CHANT_FADE_IN := 2.0
const CODY_CHANT_FADE_OUT := 3.0
const CODY_CHANT_LEVEL_DB := -4.0
const MATCH_END_FADE := 1.25

var clock := 0.0
var _bell_at := -1.0
var _chant_player: AudioStreamPlayer
var _chant_length := 0.0
var _chant_schedule: Array[float] = []
var _next_chant := 0
var _chant_elapsed := 0.0
var _chant_active := false
var _ending_elapsed := -1.0
var _match_finished := false
var _ending_base_db := CODY_CHANT_LEVEL_DB


func _ready() -> void:
	_chant_player = AudioStreamPlayer.new()
	_chant_player.name = "RecordedCodyCrowdChant"
	_chant_player.volume_db = -80.0
	add_child(_chant_player)


## Called by MatchAudio with the supplied recording and a per-match seed.
func configure_cody_chant(stream: AudioStream, bus: String, match_seed: int) -> void:
	if _chant_player == null:
		return
	_chant_player.bus = bus
	_chant_player.stream = stream
	_chant_length = stream.get_length() if stream else 0.0
	_chant_schedule = schedule_for_seed(match_seed) if stream else []
	_next_chant = 0


## Three potential slots, independently seeded per match and at least 90 s
## apart. Short matches naturally end before the later slots are reached.
static func schedule_for_seed(match_seed: int) -> Array[float]:
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 15485863 + 32452843
	var first := rng.randf_range(28.0, 38.0)
	var second := first + rng.randf_range(90.0, 105.0)
	var third := second + rng.randf_range(90.0, 105.0)
	return [first, second, third]


static func chant_gain_db(elapsed: float, length: float, ending := false,
		ending_elapsed := 0.0, ending_base_db := CODY_CHANT_LEVEL_DB) -> float:
	if ending:
		var end_gain := 1.0 - clampf(ending_elapsed / MATCH_END_FADE, 0.0, 1.0)
		return ending_base_db + linear_to_db(maxf(end_gain, 0.0001))
	var fade_in := smoothstep(0.0, CODY_CHANT_FADE_IN, elapsed)
	var fade_out := smoothstep(0.0, CODY_CHANT_FADE_OUT,
			maxf(length - elapsed, 0.0))
	return CODY_CHANT_LEVEL_DB + linear_to_db(maxf(minf(fade_in, fade_out), 0.0001))


func tick(delta: float, _excitement: float) -> void:
	clock += delta
	if _chant_player == null or _chant_schedule.is_empty():
		return
	if _ending_elapsed >= 0.0:
		_ending_elapsed += delta
		_chant_player.volume_db = chant_gain_db(_chant_elapsed, _chant_length,
				true, _ending_elapsed, _ending_base_db)
		if _ending_elapsed >= MATCH_END_FADE:
			_chant_player.stop()
			_chant_player.volume_db = -80.0
			_chant_active = false
			_ending_elapsed = -1.0
		return
	if _match_finished:
		return
	if _bell_at < 0.0 or _next_chant >= _chant_schedule.size():
		return
	if _chant_active:
		if not _chant_player.playing:
			_chant_active = false
			_chant_player.volume_db = -80.0
			return
		_chant_elapsed += delta
		_chant_player.volume_db = chant_gain_db(_chant_elapsed, _chant_length)
		return
	if match_time() >= _chant_schedule[_next_chant]:
		_next_chant += 1
		_chant_elapsed = 0.0
		_chant_active = true
		_chant_player.volume_db = chant_gain_db(0.0, _chant_length)
		_chant_player.play()


func bell() -> void:
	_bell_at = clock


func match_time() -> float:
	return clock - _bell_at if _bell_at >= 0.0 else -1.0


func moved(_favor: float, _pop: float) -> void:
	pass


func fired_up(_favor: float) -> void:
	pass


func kicked_out(_count: int) -> void:
	pass


func table_set_up() -> void:
	pass


func count(_number: int, _sfx: SfxPool) -> void:
	pass


func match_over(_winner_favor: float) -> void:
	_match_finished = true
	if _chant_active and _ending_elapsed < 0.0:
		_ending_elapsed = 0.0
		_ending_base_db = _chant_player.volume_db


func entrance(_style: String) -> void:
	pass
