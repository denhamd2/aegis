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
## How close she lets herself come to either man's body when she moves --
## measured to his bones (body_segments), so it holds for a man lying down.
const KEEP_CLEAR_M := 0.28
## The fallback cover, when no searched spot is inside the ropes: this far
## past the pinned man's neck, facing down his body.
const COVER_REACH := 0.62
## The cover search (cover_spot): rings round his neck, the step round them,
## and her kneeling footprint along her facing -- knees COVER_BACK behind the
## spot, hands COVER_FRONT ahead of it.
const COVER_RADII := [0.7, 0.85, 1.0, 1.15]
const COVER_STEP_DEG := 15.0
const COVER_BACK := 0.2
const COVER_FRONT := 0.3
## Her path to it (route_to): how far off the bodies a straight line must
## keep, and the ring round the pair she walks when it does not.
const ROUTE_CLEAR := 0.3
const ROUTE_RING := 1.5
## Clearance past which a spot is simply clear, and under which she moves.
const COVER_CLEAR := 0.5
const COVER_SHUFFLE := 0.2
## She may kneel by the ropes, not under them.
const COVER_ROPES := 2.95
## The body as bone chains (base-rig names).
const BODY_CHAINS := [["pelvis", "spine_02", "neck_01", "Head"],
		["upperarm_l", "lowerarm_l", "hand_l"], ["upperarm_r", "lowerarm_r", "hand_r"],
		["thigh_l", "calf_l", "foot_l"], ["thigh_r", "calf_r", "foot_r"],
		["pelvis", "thigh_l"], ["pelvis", "thigh_r"], ["neck_01", "upperarm_l"],
		["neck_01", "upperarm_r"]]
## ref_slap's palm meets the mat on its frame 12 of 30 fps: 24 ticks at 60 Hz.
const SLAP_LEAD := 24
## Standing beside the winner for the hand raise: on her right (-Z when she
## faces the hard camera).
const WINNER_SIDE := Vector3(0.0, 0.0, 0.48)
## The two base-rig clips she moves in, and the speeds they were authored at.
const WALK_CLIP := "Walk"
const WALK_CLIP_SPEED := 1.3
const JOG_CLIP := "Jog_Fwd"
const JOG_CLIP_SPEED := 3.0

enum Mode { PARK, FOLLOW, TO_COVER, COUNTING, SUBMISSION, RISE, BELL, TO_WINNER, RAISE, ERRAND }

const GROUNDED := [
	WrestlerFSM.State.DOWN, WrestlerFSM.State.GETUP,
	WrestlerFSM.State.PIN_ATTACKER, WrestlerFSM.State.PIN_DEFENDER,
	WrestlerFSM.State.SUBMISSION_ATTACKER, WrestlerFSM.State.SUBMISSION_DEFENDER,
]

## She has reached her errand spot and is squared up (PropHandoff).
signal errand_arrived

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
var _errand_target := Vector3.INF
var _errand_face := Vector3.ZERO
var _errand_faced := true
## The cover spot she is jogging to, and where the pinned man was when it was
## chosen.
var _cover_target: Array = []
var _cover_from: Array = []
var _recheck := 0


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


## An errand for PropHandoff, during the entrances: she leaves her spot, walks
## where she is told, plays the clips she is given, and goes back to her spot
## when it is over (the PARK branch walks her there).
func begin_errand() -> void:
	if mode == Mode.PARK:
		_separating = false
		_checking = false
		_set_mode(Mode.ERRAND)


## Walk to `spot` (on the mat) and turn to `face_dir`; errand_arrived fires
## once she is there and squared up.
func errand_go(spot: Vector3, face_dir: Vector3) -> void:
	_errand_target = _flat(spot)
	_errand_face = _flat(face_dir)
	_errand_faced = false


## A one-shot clip, from its first frame; she stands where she is for it.
func errand_play(clip: String) -> void:
	_errand_target = Vector3.INF
	_play(clip, 0.2, true)


func errand_idle() -> void:
	_play("strikes/ref_stand", 0.25)


func errand_clip_length(clip: String) -> float:
	return _clip_length(clip)


## The errand is over: back to her spot by the ropes.
func end_errand() -> void:
	_errand_target = Vector3.INF
	if mode == Mode.ERRAND:
		_set_mode(Mode.PARK)


func skeleton() -> Skeleton3D:
	return (model as AubreyModel).get_game_skeleton() if model else null


## The bell: from here she works the match.
func go_live() -> void:
	if mode == Mode.ERRAND:
		_errand_target = Vector3.INF
		_set_mode(Mode.PARK)
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
			_square_winner(delta)
			var spot := _inside(_flat(_winner.global_position) + WINNER_SIDE)
			if _go(spot, WALK_SPEED, delta, false):
				_set_mode(Mode.RAISE)
		Mode.RAISE:
			_square_winner(delta)
			_face(_yaw_towards(Vector3.LEFT), delta)
		Mode.ERRAND:
			_errand(delta)


## The winner turns square to the hard camera (-X) so his raised left arm is
## on her side and the two wrists meet (Ref_Raise_Hand / Win_Arm_Raised).
func _square_winner(delta: float) -> void:
	if _winner and is_instance_valid(_winner):
		_winner.rotation.y = lerp_angle(_winner.rotation.y, PI * 0.5, 1.0 - exp(-delta * 5.0))


## How far apart her right hand and his left hand are, metres; INF if either
## skeleton is missing. A probe/test number: the raise reads when this is small.
func raise_hand_offset() -> Vector3:
	var theirs := _winner.skeleton if _winner else null
	if theirs == null or skeleton() == null:
		return Vector3.INF
	var a := skeleton().find_bone("hand_r")
	var b := theirs.find_bone(_winner._skeleton_bone_name("hand_l"))
	if a < 0 or b < 0:
		return Vector3.INF
	return (theirs.global_transform * theirs.get_bone_global_pose(b).origin) \
			- (skeleton().global_transform * skeleton().get_bone_global_pose(a).origin)


func raise_hand_gap() -> float:
	if _winner == null or not is_instance_valid(_winner) or skeleton() == null:
		return INF
	var theirs := _winner.skeleton
	if theirs == null:
		return INF
	var a := skeleton().find_bone("hand_r")
	var b := theirs.find_bone(_winner._skeleton_bone_name("hand_l"))
	if a < 0 or b < 0:
		return INF
	return (skeleton().global_transform * skeleton().get_bone_global_pose(a).origin).distance_to(
			theirs.global_transform * theirs.get_bone_global_pose(b).origin)


func _errand(delta: float) -> void:
	if _errand_target == Vector3.INF:
		return
	if _flat(global_position).distance_to(_errand_target) > ARRIVED:
		_go(_errand_target, WALK_SPEED, delta, false)
		return
	_play("strikes/ref_stand", 0.25)
	var want := _yaw_towards(_errand_face) if _errand_face.length() > 0.01 else _yaw
	_face(want, delta)
	if not _errand_faced and absf(angle_difference(_yaw, want)) < 0.05:
		_errand_faced = true
		_errand_target = Vector3.INF
		errand_arrived.emit()


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
			if _winner and is_instance_valid(_winner):
				_winner.raise_arm()


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
	var defender: WrestlerController = _referee._pin_defender
	# Chosen once, and again only if the pair have moved: re-searched every
	# frame, two spots scoring alike would have her dithering between them.
	if _cover_target.is_empty() or _pair_moved():
		_cover_target = cover_spot(defender, _wrestlers)
		_cover_from = _pair_at()
	var next := route_to(_flat(global_position), _cover_target[0], _wrestlers)
	if next != _cover_target[0]:
		# Round the far side of the pair first: the path straight to her spot
		# runs through them, or between a man and the ropes where there is
		# no room.
		_go(next, JOG_SPEED, delta, true)
		return
	if _go(_cover_target[0], JOG_SPEED, delta, true):
		rotation.y = _yaw_towards(_cover_target[1])
		_yaw = rotation.y
		_set_mode(Mode.COUNTING)


## Both men's flat positions, to tell when the pair have moved since her
## cover spot was chosen -- the coverer is still sliding into place when she
## sets off.
func _pair_at() -> Array:
	return _wrestlers.map(func(w: WrestlerController) -> Vector3: return _flat(w.global_position))


func _pair_moved() -> bool:
	var now := _pair_at()
	if now.size() != _cover_from.size():
		return true
	for i in now.size():
		if (now[i] as Vector3).distance_to(_cover_from[i]) > 0.25:
			return true
	return false


## Where she kneels for a cover, and which way she faces: by the pinned man's
## head and shoulders, wherever round them is clearest of BOTH men's bodies --
## never on top of either. It used to be a fixed 0.62 m past his neck, which
## took no account of the man lying across him and, clamped in at the ropes,
## put her knees on the pair.
##
## The search: every COVER_STEP_DEG round his neck at each of COVER_RADII, her
## kneeling footprint (knees to hands, COVER_BACK/COVER_FRONT along her
## facing, which is at his neck) measured against the bone segments of both
## men. Best clearance wins up to COVER_CLEAR, past which the shot's
## preferences decide: the head end, then the side away from the hard camera
## (she belongs in the back of the shot).
static func cover_spot(defender: WrestlerController, men: Array = []) -> Array:
	var bodies := men.duplicate()
	if not bodies.has(defender):
		bodies.append(defender)
	var neck: Vector3 = defender._bone_world("neck_01")
	var hips := _flat(defender.global_position)
	if neck == Vector3.INF:
		neck = hips + defender.global_transform.basis.z * -0.6
	neck = _flat(neck)
	var up_body := neck - hips
	up_body = Vector3.FORWARD if up_body.length() < 0.1 else up_body.normalized()
	var segments := body_segments(bodies)
	var best: Array = []
	var best_score := -INF
	for radius: float in COVER_RADII:
		for step in int(360.0 / COVER_STEP_DEG):
			var angle := deg_to_rad(step * COVER_STEP_DEG)
			var out := up_body.rotated(Vector3.UP, angle)
			var spot := neck + out * radius
			if absf(spot.x) > COVER_ROPES or absf(spot.z) > COVER_ROPES:
				continue
			var facing := -out
			var clear := _footprint_clearance(spot, facing, segments)
			var score := minf(clear, COVER_CLEAR) * 10.0
			score += out.dot(up_body) * 0.6
			score += 0.3 if out.x > 0.0 else 0.0
			score -= (radius - COVER_RADII[0]) * 0.8
			if score > best_score:
				best_score = score
				best = [spot, facing]
	if best.is_empty():
		var spot := neck + up_body * COVER_REACH
		spot.x = clampf(spot.x, -COVER_ROPES, COVER_ROPES)
		spot.z = clampf(spot.z, -COVER_ROPES, COVER_ROPES)
		return [spot, -up_body]
	return best


## The next point on her way from `from` to `to`: `to` itself when the
## straight line keeps ROUTE_CLEAR of both men's bodies, else the waypoint on
## a ring round them (ROUTE_RING out from their middle, inside the ropes)
## that makes the shortest clear two-leg route. A line between two points on
## the mat is all she can plan; a pair lying the length of the ropes is
## walked round, not through.
static func route_to(from: Vector3, to: Vector3, men: Array) -> Vector3:
	var segments := body_segments(men)
	if _line_clearance(from, to, segments) >= ROUTE_CLEAR:
		return to
	var mid := Vector3.ZERO
	for w: WrestlerController in men:
		mid += _flat(w.global_position) / float(men.size())
	# The shortest fully clear two-leg route; failing that (a body hard
	# against the ropes can leave none), the one that keeps furthest off them.
	var best := to
	var best_len := INF
	var fallback := to
	var fallback_clear := _line_clearance(from, to, segments)
	for radius: float in [ROUTE_RING, ROUTE_RING + 0.5]:
		for step in 16:
			var wp := mid + Vector3.FORWARD.rotated(Vector3.UP, TAU * step / 16.0) * radius
			if absf(wp.x) > COVER_ROPES or absf(wp.z) > COVER_ROPES \
					or wp.distance_to(from) < ARRIVED * 1.5:
				continue
			var clear := minf(_line_clearance(from, wp, segments),
					_line_clearance(wp, to, segments))
			if clear > fallback_clear:
				fallback_clear = clear
				fallback = wp
			if clear < ROUTE_CLEAR:
				continue
			var length := from.distance_to(wp) + wp.distance_to(to)
			if length < best_len:
				best_len = length
				best = wp
	return best if best_len < INF else fallback


static func _line_clearance(a: Vector3, b: Vector3, segments: Array) -> float:
	# The last stretch into a cover spot is allowed to come close: the spot
	# itself was chosen for its clearance.
	var end := b
	if a.distance_to(b) > 0.4:
		end = b + (a - b).normalized() * 0.35
	var best := INF
	for seg: Array in segments:
		best = minf(best, _segment_distance(a, end, seg[0], seg[1]))
	return best


## The flat distance from `spot` -- and, given a facing, from her whole
## kneeling footprint -- to the nearest bone segment of `men`.
static func body_clearance(spot: Vector3, men: Array, facing := Vector3.ZERO) -> float:
	return _footprint_clearance(_flat(spot), facing, body_segments(men))


static func _footprint_clearance(spot: Vector3, facing: Vector3, segments: Array) -> float:
	var a := spot
	var b := spot
	if facing.length() > 0.01:
		var f := _flat(facing).normalized()
		a = spot - f * COVER_BACK
		b = spot + f * COVER_FRONT
	var best := INF
	for seg: Array in segments:
		best = minf(best, _segment_distance(a, b, seg[0], seg[1]))
	return best


## Each man's body as flat line segments between his bones: the spine to the
## head, both arms, both legs.
static func body_segments(men: Array) -> Array:
	var out: Array = []
	for w: WrestlerController in men:
		if w == null:
			continue
		for chain: Array in BODY_CHAINS:
			var prev := Vector3.INF
			for bone: String in chain:
				var p: Vector3 = w._bone_world(bone)
				if p == Vector3.INF:
					continue
				p = _flat(p)
				if prev != Vector3.INF:
					out.append([prev, p])
				prev = p
		if out.is_empty():
			var root := _flat(w.global_position)
			out.append([root, root])
	return out


## Closest distance between segments ab and cd, in the floor plane.
static func _segment_distance(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> float:
	if _segments_cross(a, b, c, d):
		return 0.0
	return minf(minf(_point_segment(a, c, d), _point_segment(b, c, d)),
			minf(_point_segment(c, a, b), _point_segment(d, a, b)))


static func _point_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	var t := 0.0 if len2 < 1e-8 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _segments_cross(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> bool:
	var d1 := _cross2(d - c, a - c)
	var d2 := _cross2(d - c, b - c)
	var d3 := _cross2(b - a, c - a)
	var d4 := _cross2(b - a, d - a)
	return d1 * d2 < 0.0 and d3 * d4 < 0.0


static func _cross2(u: Vector3, v: Vector3) -> float:
	return u.x * v.z - u.z * v.x


func _counting() -> void:
	var ticks: int = _referee._pin_ticks
	if _referee.is_pin_active():
		for count in MatchReferee.COUNT_TICKS:
			var start: int = count - SLAP_LEAD
			if _last_pin_tick < start and ticks >= start:
				_play("strikes/ref_slap", 0.05, true)
				slaps += 1
		_last_pin_tick = ticks
		# The pair settle into the cover after she is down: if they have
		# shifted onto her, she shuffles to the next clear spot.
		_recheck += 1
		if _recheck % 10 == 0 and _referee._pin_defender:
			var now := body_clearance(global_position, _wrestlers, global_transform.basis.z)
			if now < COVER_SHUFFLE:
				var other := cover_spot(_referee._pin_defender, _wrestlers)
				if body_clearance(other[0], _wrestlers, other[1]) > now + COVER_SHUFFLE:
					_cover_target = other
					_cover_from = _pair_at()
					_set_mode(Mode.TO_COVER)
	elif _mode_time > 0.1:
		# A kick-out or the three: either way she gets up.
		_set_mode(Mode.RISE)


func _submission(delta: float) -> void:
	if not _referee.is_submission_active():
		_set_mode(Mode.BELL if _winner else Mode.FOLLOW)
		return
	var defender: WrestlerController = _referee._submission_defender
	var at := cover_spot(defender, _wrestlers)
	if _go(at[0], WALK_SPEED, delta, true) or not _moving:
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
	if keep_clear and far > 0.3:
		# Round the bodies, not through them, measured to the nearest bone
		# segment of either man rather than his root (a man lying down is two
		# metres long): inside KEEP_CLEAR_M she loses the part of her step
		# that goes into him and slides along him instead, so she walks round
		# a body rather than stalling against it.
		for seg: Array in body_segments(_wrestlers):
			var a: Vector3 = seg[0]
			var ab: Vector3 = (seg[1] as Vector3) - a
			var t := 0.0 if ab.length_squared() < 1e-8 else \
					clampf((here - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var away := here - (a + ab * t)
			var d := away.length()
			if d < KEEP_CLEAR_M and d > 0.01:
				var n := away / d
				var into := velocity.dot(n)
				if into < 0.0:
					velocity -= n * into
					var along := Vector3.UP.cross(n)
					if along.dot(to) < 0.0:
						along = -along
					velocity += along * absf(into) * 0.8
				velocity += n * (KEEP_CLEAR_M - d) * 2.0
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
