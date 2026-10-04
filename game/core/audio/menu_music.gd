class_name MenuMusic
extends AudioStreamPlayer
## The title theme under the menu: it starts with the screen, loops, and on the
## way into a match is handed to the tree root and faded out, not cut.
##
## The owner's track is 3:29 and runs at full level to its last sample, while
## its head fades in from silence, so a plain loop would jump. The last
## LOOP_DIP seconds are therefore ducked to silence and the loop's head rises
## from it: the seam is a breath, not a click. Presentation only -- nothing in
## a match reads this.

const STREAM := "res://assets/audio/music/title_theme.ogg"
## Resting level under the menu's own sounds.
const LEVEL_DB := -9.0
const SILENT_DB := -60.0
const LOOP_DIP := 2.5

## True once release() has started the fade, so the dip stops fighting it.
var releasing := false
var _fade: Tween


func _init() -> void:
	name = "MenuMusic"
	volume_db = SILENT_DB


func _ready() -> void:
	var s := load(STREAM) as AudioStreamOggVorbis
	if s == null:
		return
	s = s.duplicate()
	s.loop = true
	s.loop_offset = 0.0
	stream = s
	# Rise from silence, so the first frame is not a hard start either.
	play()
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", LEVEL_DB, 1.5)


func _process(_delta: float) -> void:
	if releasing or not playing or stream == null:
		return
	if _fade != null and _fade.is_running():
		return
	volume_db = dip_db(get_playback_position(), stream.get_length())


## The level at a playback position: LEVEL_DB, ducked over the last LOOP_DIP
## seconds so the loop point is a dip, and back up over the first second.
static func dip_db(position: float, length: float) -> float:
	var left := length - position
	if left < LOOP_DIP:
		return lerpf(SILENT_DB, LEVEL_DB, smoothstep(0.0, 1.0, left / LOOP_DIP))
	if position < 1.0:
		return lerpf(SILENT_DB, LEVEL_DB, smoothstep(0.0, 1.0, position))
	return LEVEL_DB


## Hand the music to `root` so it outlives the title scene, and fade it out.
func release(root: Node, seconds: float) -> void:
	releasing = true
	if _fade != null:
		_fade.kill()
	if get_parent() != root:
		reparent(root, false)
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", SILENT_DB, seconds)
	_fade.finished.connect(queue_free)
