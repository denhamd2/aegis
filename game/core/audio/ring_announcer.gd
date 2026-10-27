class_name RingAnnouncer
extends Node
## The ring announcer: Justin Roberts' calls (assets/audio/announcer,
## owner-supplied) -- the main-event intro at the start of the first entrance,
## and each man's "From ... weighing ..." call during his entrance.
##
## Each man's call is started on a tick counted back from his card's moment
## (EntranceDirector._schedule_call), so the name -- NAME_AT seconds in -- is
## said as the card goes up. `name_called` reports the same moment off the
## audio clock, for anything that wants the voice itself.
##
## Clear over the music and the crowd. The owner, after playing: the music
## went too low under him -- keep it at its level and have Justin louder. So
## the entrance music is not ducked at all; he is lifted instead, on his own
## bus (VOICE_BUS) with VOICE_GAIN_DB of pre-gain into a hard limiter, so the
## lift can't clip (the calls already peak at -1.1 dBFS). Only the crowd beds
## (UNDER_BUS) dip, and only DUCK_DB, as a live crowd quietens for the
## announcer. Master gets a limiter too, so voice + music summed stay clean.

signal name_called(style: String)
signal finished(style: String)

const CLIPS := {
	"intro": "res://assets/audio/announcer/intro.ogg",
	"roman": "res://assets/audio/announcer/roman.ogg",
	"cody": "res://assets/audio/announcer/cody.ogg",
	"kenny": "res://assets/audio/announcer/kenny.ogg",
}
## Where in each call the man's name starts, in seconds: measured with an
## offline speech recogniser off the shipped files ("roman" 16.98-17.88,
## "reigns" 18.09-19.26; "cody" 7.26-8.01). Kenny's: the recogniser has
## "he is" ending at 18.39 and the name drawn out from 18.87 to the end (the
## name itself it mishears); the call is silent from 18.35 and comes back up
## at 18.87 (50 ms loudness windows).
const NAME_AT := {"roman": 16.98, "cody": 7.26, "kenny": 18.87}
## The calls are normalised to -12 LUFS; the entrance music runs to -11.9.
## Lifted VOICE_GAIN_DB into the limiter: he sits about 6 dB over the music.
const VOICE_DB := 0.0
const VOICE_BUS := "Announcer"
const VOICE_GAIN_DB := 7.0
const VOICE_CEILING_DB := -1.0
const MASTER_CEILING_DB := -0.3
## The bus the crowd goes through, and how far it comes down under the voice.
## The music is NOT on it (StageVideo._play_music): -9 dB on the music was
## the owner's complaint.
const UNDER_BUS := "UnderVoice"
const DUCK_DB := -4.0
## Seconds to duck and to come back up.
const DUCK_IN := 0.25
const DUCK_OUT := 0.8

var _player: AudioStreamPlayer
var _style := ""
var _named := false
var _duck := 0.0
var _voice_queue: Array[Dictionary] = []


## The bus to route the crowd through so it sits under the voice; made on
## first use, sending to Master.
static func under_bus() -> String:
	if AudioServer.get_bus_index(UNDER_BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, UNDER_BUS)
		AudioServer.set_bus_send(i, "Master")
	return UNDER_BUS


## His own bus: pre-gain into a hard limiter, then Master, which gets a
## limiter of its own. Made on first use.
static func voice_bus() -> String:
	if AudioServer.get_bus_index(VOICE_BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, VOICE_BUS)
		AudioServer.set_bus_send(i, "Master")
		var lift := AudioEffectHardLimiter.new()
		lift.pre_gain_db = VOICE_GAIN_DB
		lift.ceiling_db = VOICE_CEILING_DB
		AudioServer.add_bus_effect(i, lift)
	var master := AudioServer.get_bus_index("Master")
	var guarded := false
	for e in AudioServer.get_bus_effect_count(master):
		guarded = guarded or AudioServer.get_bus_effect(master, e) is AudioEffectHardLimiter
	if not guarded:
		var guard := AudioEffectHardLimiter.new()
		guard.ceiling_db = MASTER_CEILING_DB
		AudioServer.add_bus_effect(master, guard)
	return VOICE_BUS


static func has_call(style: String) -> bool:
	return CLIPS.has(style) and ResourceLoader.exists(CLIPS[style])


## Seconds of the call.
static func length_of(style: String) -> float:
	if not has_call(style):
		return 0.0
	return (load(CLIPS[style]) as AudioStream).get_length()


## Seconds into the call his name starts (0 for the intro: no card).
static func name_at(style: String) -> float:
	return float(NAME_AT.get(style, 0.0))


func _ready() -> void:
	under_bus()
	_player = AudioStreamPlayer.new()
	_player.name = "Voice"
	_player.volume_db = VOICE_DB
	_player.bus = voice_bus()
	add_child(_player)
	_player.finished.connect(_on_finished)


## Starts `style`'s call; false if there is none.
func play(style: String) -> bool:
	if not has_call(style):
		return false
	_queue_voice(load(CLIPS[style]), style)
	return true


## Commentary shares Justin's voice lane, so neither speaker can talk over
## another. It joins the same FIFO as his calls and keeps its full recording.
func play_commentary(stream: AudioStream) -> bool:
	if stream == null:
		return false
	_queue_voice(stream, "")
	return true


func has_voice() -> bool:
	return (_player != null and _player.playing) or not _voice_queue.is_empty()


func _queue_voice(stream: AudioStream, style: String) -> void:
	_voice_queue.append({"stream": stream, "style": style})
	_start_next_voice()


func _start_next_voice() -> void:
	if _player == null or _player.playing or _voice_queue.is_empty():
		return
	var request: Dictionary = _voice_queue.pop_front()
	_player.stream = request["stream"]
	_style = String(request["style"])
	_named = false
	_player.play()


func stop() -> void:
	if _player.playing:
		_player.stop()
	_style = ""


func is_speaking() -> bool:
	return _player != null and _player.playing


func speaking_style() -> String:
	return _style if is_speaking() else ""


## Seconds into the call being made.
func position() -> float:
	return _player.get_playback_position() if is_speaking() else 0.0


func _process(delta: float) -> void:
	if is_speaking() and not _named and NAME_AT.has(_style) \
			and _player.get_playback_position() + AudioServer.get_time_to_next_mix() \
			>= float(NAME_AT[_style]):
		_named = true
		name_called.emit(_style)
	var target := 1.0 if is_speaking() else 0.0
	var rate := delta / (DUCK_IN if target > _duck else DUCK_OUT)
	_duck = move_toward(_duck, target, rate)
	var i := AudioServer.get_bus_index(UNDER_BUS)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, DUCK_DB * smoothstep(0.0, 1.0, _duck))


## Never leave the building ducked: the director goes at the bell, and with
## it this node, possibly mid-fade.
func _exit_tree() -> void:
	var i := AudioServer.get_bus_index(UNDER_BUS)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, 0.0)


func _on_finished() -> void:
	var style := _style
	_style = ""
	if style != "":
		finished.emit(style)
	_start_next_voice()
