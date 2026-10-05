class_name InstantReplay
extends Node
## The in-match replay (camera_aaa_plan.md C2, "Replays: Frequent"): 2K26
## shows a big move again mid-match -- a signature slam, a dive -- at half
## speed from a new angle under a REPLAY badge, then goes back to the match.
## Until this, the menu offered FREQUENT and nothing in the match read it:
## every setting but OFF replayed the finish and only the finish.
##
## How it stays out of the match: it plays only between moves (never in a
## pin, a hold or the finisher, which PostMatch replays), at most once every
## COOLDOWN seconds, and while it plays the whole tree is PAUSED -- no tick
## runs, so the match resumes on exactly the tick it left and the recording
## (ReplaySystem) never sees it. The pictures come from ReplayBuffer, which
## hands every pose back afterwards. Headless and in captures the buffer
## records nothing, so this never fires there.

const LEAD := 0.5       # seconds of the run-up before the move starts
const TAIL := 0.6       # after it finishes
const DELAY := 0.15     # after the tail is in the buffer, before the cut
const SPEED := 0.5
const COOLDOWN := 40.0
const MAX_LENGTH := 4.0 # of the move, in match seconds

var buffer: ReplayBuffer
var camera: MatchCamera
var referee: MatchReferee
var audio: Node

var _from := -1.0
var _to := -1.0
var _due := -1.0
## A worthy move in progress: when it started on the buffer's clock.
var _capture_from := -1.0
## Any move in progress: a replay only ever starts between moves.
var _in_move := false
var _last := -INF
var _t := 0.0
var _playing := false
var _attacker: Node3D
var _defender: Node3D
var _layer: CanvasLayer
var _badge: Control
var _audio_mode := Node.PROCESS_MODE_INHERIT
var replays := 0


func watch(p_buffer: ReplayBuffer, p_camera: MatchCamera, rig: GrappleRig,
		p_referee: MatchReferee, p_audio: Node) -> void:
	buffer = p_buffer
	camera = p_camera
	referee = p_referee
	audio = p_audio
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 6
	add_child(_layer)
	_badge = PostMatch._ReplayBadge.new()
	_badge.visible = false
	_layer.add_child(_badge)
	rig.grapple_started.connect(_on_started)
	rig.grapple_finished.connect(_on_finished)


## A move worth replaying: a signature or bigger that is not the finisher
## (the finish has its own replay after the bell).
static func worth_replaying(attacker: WrestlerController, move: MoveDef) -> bool:
	return attacker != null and move != null \
			and attacker.tier_of(move) >= CombatSystem.Tier.SIGNATURE \
			and not attacker.is_finisher(move)


## Whether a replay may start now: replays on FREQUENT, nothing that needs
## the referee going on, and the last one long enough ago.
static func may_play(frequent: bool, busy: bool, now: float, last: float) -> bool:
	return frequent and not busy and now - last >= COOLDOWN


func _on_started(attacker: Node3D, defender: Node3D, move: MoveDef) -> void:
	_in_move = true
	if _playing or buffer == null:
		return
	if worth_replaying(attacker as WrestlerController, move):
		# A newer big move replaces any replay still waiting for its gap.
		_capture_from = buffer.now() - LEAD
		_attacker = attacker
		_defender = defender


func _on_finished(_a: Node3D, _d: Node3D) -> void:
	_in_move = false
	if _capture_from < 0.0 or _playing or buffer == null:
		return
	_from = _capture_from
	_capture_from = -1.0
	_to = minf(buffer.now() + TAIL, _from + LEAD + MAX_LENGTH)
	# Not before the tail has been recorded: the replay ends on it. A move
	# started in the meantime only delays it to the next gap (_in_move).
	_due = maxf(_to, buffer.now()) + DELAY


func _process(delta: float) -> void:
	if _playing:
		_play(delta)
		return
	if _due < 0.0 or buffer == null or _in_move or buffer.now() < _due:
		return
	_due = -1.0
	var busy := referee != null and (referee.is_pin_active() or referee.is_submission_active())
	if not may_play(CameraSettings.replay_frequent(), busy, buffer.now(), _last) \
			or not buffer.has_window(_from, _to):
		_from = -1.0
		return
	_begin()


func _begin() -> void:
	_playing = true
	_t = 0.0
	_last = buffer.now()
	replays += 1
	get_tree().paused = true
	if audio:
		# The crowd goes on under the replay.
		_audio_mode = audio.process_mode
		audio.process_mode = Node.PROCESS_MODE_ALWAYS
	buffer.begin_playback()
	_badge.visible = true


func _play(delta: float) -> void:
	_t += delta
	var length := (_to - _from) / SPEED
	buffer.show(_from + _t * SPEED)
	_shot(_t / length, delta)
	if _t >= length or Input.is_action_just_pressed("ui_accept"):
		_end()


func _end() -> void:
	buffer.restore()
	_badge.visible = false
	_playing = false
	_from = -1.0
	if audio:
		audio.process_mode = _audio_mode
	get_tree().paused = false
	if camera:
		camera.resume_play()


## One new angle, the one the live coverage never has: down at mat level,
## square to the pair, from the far side of the hard camera's line, pushing
## in slowly.
func _shot(k: float, delta: float) -> void:
	if camera == null or _attacker == null or _defender == null:
		return
	var mid := (_attacker.global_position + _defender.global_position) * 0.5
	var across := _defender.global_position - _attacker.global_position
	across.y = 0.0
	across = Vector3.RIGHT if across.length() < 0.2 else across.normalized()
	var side := Vector3.UP.cross(across).normalized()
	if side.dot(camera.hard_cam_position - mid) > 0.0:
		side = -side
	var back := lerpf(3.4, 2.8, smoothstep(0.0, 1.0, k))
	camera.set_entrance_shot(mid + side * back + Vector3.UP * 0.55, mid + Vector3.UP * 0.85,
			46.0, _t <= delta * 1.5, delta)
