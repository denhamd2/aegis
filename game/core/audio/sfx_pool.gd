class_name SfxPool
extends Node
## A handful of voices for one-shot sounds, round-robin, so a punch landing
## on top of a bump does not cut the bump off.
##
## Sounds are the .ogg files tools/audio/build_sfx.py writes to
## res://assets/audio/, asked for by name ("bell_ding") or by family
## ("hit_punch", which picks one of hit_punch_0.. at random). The pick uses
## this pool's own seeded generator, never the global one: the match seed is
## drawn from the global RNG, and a sound must not be able to change a match.
##
## Presentation only: nothing in a match reads what a pool played.

## Each sound as it starts, for tests and probes.
signal played(sound: String, volume_db: float)

const DIR := "res://assets/audio/"
const VOICES := 10

static var _cache := {}
static var _families := {}

var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0x5f3759df
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		add_child(p)
		_voices.append(p)
	guard_master()


## A limiter on the master bus, once: a finisher's bump, the crowd pop and the
## bell can land in the same frame, and they should squash, not clip.
static func guard_master() -> void:
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, limiter)


static func stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := DIR + sound + ".ogg"
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]


## How many variants a family has: hit_punch_0, hit_punch_1, ...
static func family_size(family: String) -> int:
	if not _families.has(family):
		var n := 0
		while ResourceLoader.exists("%s%s_%d.ogg" % [DIR, family, n]):
			n += 1
		_families[family] = n
	return _families[family]


## Play one named sound. Returns false if there is no such file.
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> bool:
	var s := stream(sound)
	if s == null or _voices.is_empty():
		return false
	var p := _voices[_next]
	_next = (_next + 1) % _voices.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	played.emit(sound, volume_db)
	return true


## Play a random member of a family, slightly detuned so repeats do not sound
## like a sample.
func play_any(family: String, volume_db := 0.0, detune := 0.04) -> bool:
	var n := family_size(family)
	if n == 0:
		return false
	var pick := _rng.randi_range(0, n - 1)
	return play("%s_%d" % [family, pick], volume_db,
			1.0 + _rng.randf_range(-detune, detune))


## A looping bed on its own player (crowd), started silent.
func make_loop(sound: String) -> AudioStreamPlayer:
	var s := stream(sound)
	var p := AudioStreamPlayer.new()
	p.name = "Loop_" + sound
	if s is AudioStreamOggVorbis:
		s = s.duplicate()
		(s as AudioStreamOggVorbis).loop = true
	p.stream = s
	p.volume_db = -80.0
	add_child(p)
	if s:
		p.play()
	return p
