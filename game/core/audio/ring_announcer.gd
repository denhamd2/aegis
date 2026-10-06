class_name RingAnnouncer
extends Node
## The ring announcer: Justin Roberts' three calls (assets/audio/announcer,
## owner-supplied) -- the main-event intro before the first entrance, and each
## man's "From ... weighing ..." call during his entrance.
##
## Each man's call is started on a tick counted back from his card's moment
## (EntranceDirector._schedule_call), so the name -- NAME_AT seconds in -- is
## said as the card goes up. `name_called` reports the same moment off the
## audio clock, for anything that wants the voice itself.
##
## Clear over the music and the crowd: everything routed through UNDER_BUS (the
## entrance music, the crowd beds) comes down DUCK_DB while he speaks and back
## up after, so the building stays audible underneath him.

signal name_called(style: String)
signal finished(style: String)

const CLIPS := {
	"intro": "res://assets/audio/announcer/intro.ogg",
	"roman": "res://assets/audio/announcer/roman.ogg",
	"cody": "res://assets/audio/announcer/cody.ogg",
}
## Where in each call the man's name starts, in seconds: measured with an
## offline speech recogniser off the shipped files ("roman" 16.98-17.88,
## "reigns" 18.09-19.26; "cody" 7.26-8.01).
const NAME_AT := {"roman": 16.98, "cody": 7.26}
## The calls are normalised to -12 LUFS; the entrance music runs to -11.9.
const VOICE_DB := 1.0
## The bus the music and the crowd go through, and how far it comes down
## under the voice.
const UNDER_BUS := "UnderVoice"
const DUCK_DB := -9.0
## Seconds to duck and to come back up.
const DUCK_IN := 0.25
const DUCK_OUT := 0.8

var _player: AudioStreamPlayer
var _style := ""
var _named := false
var _duck := 0.0


## The bus to route music and crowd through so they sit under the voice;
## made on first use, sending to Master.
static func under_bus() -> String:
	if AudioServer.get_bus_index(UNDER_BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, UNDER_BUS)
		AudioServer.set_bus_send(i, "Master")
	return UNDER_BUS


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
	add_child(_player)
	_player.finished.connect(_on_finished)


## Starts `style`'s call; false if there is none.
func play(style: String) -> bool:
	if not has_call(style):
		return false
	_player.stream = load(CLIPS[style])
	_style = style
	_named = false
	_player.play()
	return true


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
	finished.emit(style)
