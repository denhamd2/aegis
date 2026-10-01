class_name RefereeActor
extends Node3D
## The referee in the ring: Aubrey Edwards (AubreyModel), working the match
## the way a real official does on a broadcast (gauntlet/refs/referee.md):
##
##   * before the bell she waits by the far ropes (PARK);
##   * with both men up she keeps her distance -- STANDOFF from the pair's
##     midpoint, square to the line between them, always on the side AWAY
##     from the hard camera at -X so she is in the back of the shot rather
##     than in front of it -- and stands upright; when a man is down she bends
##     with her hands on her knees to watch the mat;
##   * on a cover she jogs to the pinned man's head, drops to her knees and
##     slaps the canvas on each count: every slap is started SLAP_LEAD ticks
##     before MatchReferee.COUNT_TICKS, so the palm lands on the count tick
##     itself, with the HUD digit and the slap sound (MatchAudio);
##   * a kick-out and she is back up; the three and she is up, waves for the
##     bell, walks to the winner and raises his hand.
##
## Presentation only. No collision and no physics: nothing in the match can
## touch her or read her, and she reads only what the referee and the two
## wrestlers already expose, so a match plays out tick for tick the same with
## her or without her.

const MODEL := "res://scenes/aubrey_model.tscn"

## Where she waits through the entrances and the face-off: by the far (+X)
## ropes, off the centre line, facing the middle.
const PARK := Vector3(2.35, 0.0, -1.4)
## She keeps inside this half-extent (the ropes are at 3.3).
const KEEP_IN := 2.6
const STANDOFF := 2.1
const WALK_SPEED := 1.4
const JOG_SPEED := 3.6
## Hysteresis: she moves off once the spot is this far away and settles
## within ARRIVED of it, so she does not shuffle after every step the men take.
const START_MOVE := 0.75
const ARRIVED := 0.18
const TURN_RATE := 7.0
## How close she lets herself come to either man while following.
const CLEARANCE := 1.0
## The cover: she kneels this far past the pinned man's neck, facing up his
## body, so her hands land by his shoulders.
const COVER_REACH := 0.62
## ref_slap's palm meets the mat on its frame 12 of 30 fps: 24 ticks at 60 Hz.
const SLAP_LEAD := 24
## Standing beside the winner for the hand raise: on her right (-Z when she
## faces the hard camera).
const WINNER_SIDE := Vector3(0.0, 0.0, 0.6)
## The two base-rig clips she moves in, and the speeds they were authored at.
const WALK_CLIP := "Walk"
const WALK_CLIP_SPEED := 1.3
const JOG_CLIP := "Jog_Fwd"
const JOG_CLIP_SPEED := 3.0

enum Mode { PARK, FOLLOW, TO_COVER, COUNTING, SUBMISSION, RISE, BELL, TO_WINNER, RAISE }

const GROUNDED := [
	WrestlerFSM.State.DOWN, WrestlerFSM.State.GETUP,
	WrestlerFSM.State.PIN_ATTACKER, WrestlerFSM.State.PIN_DEFENDER,
	WrestlerFSM.State.SUBMISSION_ATTACKER, WrestlerFSM.State.SUBMISSION_DEFENDER,
]

var mode := Mode.PARK
var model: Node3D
var slaps := 0

var _referee: MatchReferee
var _wrestlers: Array = []
var _player: AnimationPlayer
var _moving := false
var _yaw := 0.0
var _clip := ""
var _mode_time := 0.0
var _last_pin_tick := 0
var _winner: WrestlerController
var _separated := false
var _separating := false
var _checking := false
var _director: EntranceDirector


func _ready() -> void:
	model = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	_player = model.get_node("AnimationPlayer") as AnimationPlayer
	global_position = PARK
	_yaw = _yaw_towards(-PARK)
	rotation.y = _yaw
	_play("strikes/ref_stand")


func watch(referee: MatchReferee, wrestlers: Array) -> void:
	_referee = referee
	_wrestlers = wrestlers
	referee.match_won.connect(_on_match_won)


## The entrances: she waits by the ropes, and when the stare-down breaks
## ("faceoff", F7) she steps in between them to send them to their corners.
func follow(director: EntranceDirector) -> void:
	_director = director
	director.beat_started.connect(func(shot: String) -> void:
		# A5: the check walks her to the man nearer her; any other shot sends
		# her back to her spot by the ropes.
		_checking = shot == "ref_check" and mode == Mode.PARK
		if shot == "faceoff" and mode == Mode.PARK and not _separated:
			_separated = true
			_separating = true)


## The bell: from here she works the match.
func go_live() -> void:
	if mode == Mode.PARK:
		_separating = false
		_set_mode(Mode.FOLLOW)


func _process(delta: float) -> void:
	if _referee == null or _wrestlers.size() < 2:
		return
	_mode_time += delta
	match mode:
		Mode.PARK:
			if _separating:
				# Between them, on the far side of their line.
				var a := _flat(_wrestlers[0].global_position)
				var b := _flat(_wrestlers[1].global_position)
				var line := b - a
				var side := Vector3(-line.z, 0.0, line.x).normalized()
				if side.x < 0.0:
					side = -side
				if not _go(_inside((a + b) * 0.5 + side * 0.9), WALK_SPEED, delta, false):
					return
				_face(_yaw_towards(-side), delta)
			elif _checking and _director:
				var man: WrestlerController = _director.checked_man()
				if man == null:
					return
				var at := EntranceDirector.check_spot(man.global_position)
				if not _go(at, WALK_SPEED, delta, false):
					return
				_face(_yaw_towards(_flat(man.global_position) - at), delta)
			elif _flat(global_position).distance_to(PARK) > ARRIVED * 2.0 and _director:
				if not _go(PARK, WALK_SPEED, delta, false):
					return
				_face(_yaw_towards(-global_position), delta)
			else:
				_face(_yaw_towards(-global_position), delta)
			_play("strikes/ref_stand")
		Mode.FOLLOW:
			if _referee.is_pin_active():
				_set_mode(Mode.TO_COVER)
			elif _referee.is_submission_active():
				_set_mode(Mode.SUBMISSION)
			else:
				_follow(delta)
		Mode.TO_COVER:
			_to_cover(delta)
		Mode.COUNTING:
			_counting()
		Mode.SUBMISSION:
			_submission(delta)
		Mode.RISE:
			if _mode_time >= _clip_length("strikes/ref_count_up"):
				_set_mode(Mode.BELL if _winner else Mode.FOLLOW)
		Mode.BELL:
			if _mode_time >= _clip_length("strikes/ref_call_bell"):
				_set_mode(Mode.TO_WINNER)
		Mode.TO_WINNER:
			var spot := _inside(_flat(_winner.global_position) + WINNER_SIDE)
			if _go(spot, WALK_SPEED, delta, false):
				_set_mode(Mode.RAISE)
		Mode.RAISE:
			_face(_yaw_towards(Vector3.LEFT), delta)


func _set_mode(next: Mode) -> void:
	mode = next
	_mode_time = 0.0
	_moving = false
	match next:
		Mode.COUNTING:
			_play("strikes/ref_count_down", 0.12)
			_last_pin_tick = _referee._pin_ticks
		Mode.RISE:
			_play("strikes/ref_count_up", 0.1)
		Mode.BELL:
			_play("strikes/ref_call_bell", 0.2)
		Mode.RAISE:
			_play("strikes/ref_raise_hand", 0.25)


# --- the modes ------------------------------------------------------------------

func _follow(delta: float) -> void:
	var a := _flat(_wrestlers[0].global_position)
	var b := _flat(_wrestlers[1].global_position)
	var mid := (a + b) * 0.5
	var line := b - a
	var side := Vector3(-line.z, 0.0, line.x)
	side = Vector3.RIGHT if side.length() < 0.05 else side.normalized()
	# Away from the hard camera, which sits out at -X.
	if side.x < 0.0:
		side = -side
	var spot := _inside(mid + side * STANDOFF)
	var arrived := _go(spot, WALK_SPEED, delta, true)
	if arrived or not _moving:
		_face(_yaw_towards(mid - _flat(global_position)), delta)
		var down := false
		for w: WrestlerController in _wrestlers:
			if GROUNDED.has(w.fsm.current_state):
				down = true
		_play("strikes/ref_watch" if down else "strikes/ref_stand", 0.3)


func _to_cover(delta: float) -> void:
	if not _referee.is_pin_active():
		_set_mode(Mode.BELL if _winner else Mode.FOLLOW)
		return
	var at := cover_spot(_referee._pin_defender)
	if _go(at[0], JOG_SPEED, delta, false):
		rotation.y = _yaw_towards(at[1])
		_yaw = rotation.y
		_set_mode(Mode.COUNTING)


## Where she kneels for a cover, and which way she faces: past the pinned
## man's neck on the line up his body, facing back down it.
static func cover_spot(defender: WrestlerController) -> Array:
	var neck: Vector3 = defender._bone_world("neck_01")
	var hips := _flat(defender.global_position)
	if neck == Vector3.INF:
		neck = hips + defender.global_transform.basis.z * -0.6
	neck = _flat(neck)
	var up_body := neck - hips
	up_body = Vector3.FORWARD if up_body.length() < 0.1 else up_body.normalized()
	var spot := neck + up_body * COVER_REACH
	spot.x = clampf(spot.x, -KEEP_IN - 0.4, KEEP_IN + 0.4)
	spot.z = clampf(spot.z, -KEEP_IN - 0.4, KEEP_IN + 0.4)
	return [spot, -up_body]


func _counting() -> void:
	var ticks: int = _referee._pin_ticks
	if _referee.is_pin_active():
		for count in MatchReferee.COUNT_TICKS:
			var start: int = count - SLAP_LEAD
			if _last_pin_tick < start and ticks >= start:
				_play("strikes/ref_slap", 0.05, true)
				slaps += 1
		_last_pin_tick = ticks
	elif _mode_time > 0.1:
		# A kick-out or the three: either way she gets up.
		_set_mode(Mode.RISE)


func _submission(delta: float) -> void:
	if not _referee.is_submission_active():
		_set_mode(Mode.BELL if _winner else Mode.FOLLOW)
		return
	var defender: WrestlerController = _referee._submission_defender
	var at := cover_spot(defender)
	var spot: Vector3 = at[0] + (at[0] - _flat(defender.global_position)).normalized() * 0.3
	if _go(_inside(spot), WALK_SPEED, delta, false) or not _moving:
		_face(_yaw_towards(at[1]), delta)
		_play("strikes/ref_watch", 0.3)


func _on_match_won(winner: WrestlerController, _method: String) -> void:
	_winner = winner
	# A pinfall ends with her on her knees: COUNTING sees the pin end and
	# stands her up, and RISE hands on to the bell. Anything else, straight to
	# the bell from wherever she is.
	if mode != Mode.COUNTING and mode != Mode.TO_COVER:
		_set_mode(Mode.BELL)


# --- moving -------------------------------------------------------------------

## One step towards `spot`; true once she is there. Walks or jogs with the
## clip's rate matched to her speed, and turns to where she is going.
func _go(spot: Vector3, speed: float, delta: float, keep_clear: bool) -> bool:
	var here := _flat(global_position)
	var to := spot - here
	var far := to.length()
	if not _moving and far < START_MOVE and mode == Mode.FOLLOW:
		return true
	if far <= ARRIVED:
		_moving = false
		return true
	_moving = true
	var velocity := to / far * minf(speed, far / maxf(delta, 1e-4))
	if keep_clear:
		for w: WrestlerController in _wrestlers:
			var away := here - _flat(w.global_position)
			var d := away.length()
			if d < CLEARANCE and d > 0.01:
				velocity += away / d * (CLEARANCE - d) * 3.0
	global_position = _inside_soft(here + velocity * delta)
	var pace := velocity.length()
	if pace > 0.05:
		_face(_yaw_towards(velocity), delta)
	if speed > WALK_SPEED:
		_play(JOG_CLIP, 0.15, false, pace / JOG_CLIP_SPEED)
	else:
		_play(WALK_CLIP, 0.25, false, pace / WALK_CLIP_SPEED)
	return false


func _face(yaw: float, delta: float) -> void:
	_yaw = lerp_angle(_yaw, yaw, clampf(TURN_RATE * delta, 0.0, 1.0))
	rotation.y = _yaw


## The model faces its node's +Z (the kit is built facing Blender -Y).
static func _yaw_towards(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)


func _play(clip: String, blend := 0.2, restart := false, speed := 1.0) -> void:
	if _player == null or not _player.has_animation(clip):
		return
	if restart or clip != _clip:
		_player.play(clip, blend, 1.0)
		if restart:
			_player.seek(0.0, true)
		_clip = clip
	_player.speed_scale = clampf(speed, 0.3, 1.6)


func _clip_length(clip: String) -> float:
	return _player.get_animation(clip).length if _player and _player.has_animation(clip) else 0.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _inside(v: Vector3) -> Vector3:
	return Vector3(clampf(v.x, -KEEP_IN, KEEP_IN), 0.0, clampf(v.z, -KEEP_IN, KEEP_IN))


## The ring's edge is soft for the cover (she may kneel by the ropes), hard
## at the ropes themselves.
static func _inside_soft(v: Vector3) -> Vector3:
	const ROPES := 3.05
	return Vector3(clampf(v.x, -ROPES, ROPES), 0.0, clampf(v.z, -ROPES, ROPES))
