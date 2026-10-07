class_name TopRopeSpot
extends Node
## Cody's top-rope moonsault, as a set piece (gauntlet/refs/moveset_audit_2k26.md):
## twice in the owner's 2K26 match Cody climbs the corner over a downed Roman
## and comes off the top onto him, then covers. He walks to the corner whose
## distance from the man suits the dive, turns to the post, climbs to the
## middle rope (Corner_Climb), steps up to the top one and looks back at him
## (Top_Rope_Step), and moonsaults onto him (Moonsault). The match then covers.
##
## Built as DiveSpot is, for the same reasons: off the mat there is no
## collision for a man to stand on, so both men, their AI, the referee and the
## grapple rig are frozen while it plays and the climber is placed
## kinematically. The man on the mat stays down, playing his own DOWN clip.
## The referee is what advances ReplaySystem's tick, so the spot takes no match
## ticks; its trigger is deterministic, so a replay plays it identically.

signal finished

const TPS := 60.0
## Where the climber's root stands at a corner, in from the turnbuckle pad:
## EntranceDirector.CORNER_ROOT_M, where Corner_Climb's keys put the ropes.
const CORNER_ROOT_M := 0.62
## The moonsault carries him this far along the mat, best; a man further or
## nearer than the band takes a corner that suits, or no dive at all.
const BEST_REACH := 2.0
const MIN_REACH := 1.3
const MAX_REACH := 2.8
## His chest lands this far from the root, toward the corner (Moonsault's
## landing keys): the root lands short of the man's chest by it.
const CHEST_FROM_ROOT := 0.40
## The man's chest from his own root, lying down (pin_shot: his body runs up
## -Z toward the head).
const DOWNED_CHEST := Vector3(0.0, 0.0, -0.35)
const WALK := 1.6
const TURN_TICKS := 18
const CLIMB_TICKS := 72
const STEP_TICKS := 120
const MOONSAULT_TICKS := 72
## Moonsault frame 25.
const MOONSAULT_CONTACT := 50
const TURN_RATE := 6.0

var attacker: WrestlerController
var defender: WrestlerController
var _camera: MatchCamera
var _frozen: Array = []
var _segments: Array = []
var _seg := -1
var _tick := 0
var _corner := Vector2.ONE
var _stand := Vector3.ZERO
var _out := Vector3.FORWARD
var _land := Vector3.ZERO
var _cam_flip := 0.0


## The corner he would dive from at a man lying at `man`, as
## [corner (Vector2 of +-1), stand point], or [] if no corner suits.
static func pick_corner(man: Transform3D) -> Array:
	var chest := man * DOWNED_CHEST
	chest.y = 0.0
	var best := []
	var best_err := INF
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var stand := stand_at(corner)
		var reach := Vector3(stand.x, 0, stand.z).distance_to(chest) - CHEST_FROM_ROOT
		if reach < MIN_REACH or reach > MAX_REACH:
			continue
		var err := absf(reach - BEST_REACH)
		if err < best_err:
			best_err = err
			best = [corner, stand]
	return best


static func stand_at(corner: Vector2) -> Vector3:
	var pad := Vector3(corner.x * RingBuilder.TURNBUCKLE_PAD_XZ, 0.0,
			corner.y * RingBuilder.TURNBUCKLE_PAD_XZ)
	return pad - RingBuilder.step_out_dir(corner) * CORNER_ROOT_M


## Whether a man lying here can be dived on from some corner.
static func can_dive_on(man: WrestlerController) -> bool:
	return not pick_corner(man.global_transform).is_empty()


func begin(p_attacker: WrestlerController, p_defender: WrestlerController) -> void:
	attacker = p_attacker
	defender = p_defender
	var match_root := get_parent()
	_camera = match_root.get_node_or_null("MatchCamera") as MatchCamera
	for node: Node in [attacker, defender, attacker.ai, defender.ai,
			match_root.get_node_or_null("MatchReferee"),
			match_root.get_node_or_null("GrappleRig")]:
		if node:
			_frozen.append([node, node.is_physics_processing()])
			node.set_physics_process(false)
	for w: WrestlerController in [attacker, defender]:
		w.velocity = Vector3.ZERO
	var pick := pick_corner(defender.global_transform)
	_corner = pick[0]
	_stand = pick[1]
	_out = RingBuilder.step_out_dir(_corner)
	var chest := defender.global_transform * DOWNED_CHEST
	chest.y = attacker.global_position.y
	_land = chest - _out * CHEST_FROM_ROOT
	_stand.y = attacker.global_position.y
	if attacker.fsm.current_state != WrestlerFSM.State.IDLE:
		attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	_build()
	_next()


func _build() -> void:
	var a0 := attacker.global_position
	# 1. To the corner, eyes on the man as he goes.
	_seg_add(maxi(DiveSpot._ticks(DiveSpot._flat(a0).distance_to(DiveSpot._flat(_stand)), WALK), 20),
			{"clip": "strikes/walk_slow_look", "from": a0, "to": _stand, "facing": Vector3.ZERO},
			"wide")
	# 2. Square to the post.
	_seg_add(TURN_TICKS, {"clip": "strikes/cody_stand", "from": _stand, "to": _stand,
			"facing": _out}, "wide")
	# 3. Up onto the middle rope, then the top, and the look back at him.
	_seg_add(CLIMB_TICKS, {"clip": "strikes/corner_climb", "from": _stand, "to": _stand,
			"facing": _out}, "corner")
	_seg_add(STEP_TICKS, {"clip": "strikes/top_rope_step", "from": _stand, "to": _stand,
			"facing": _out}, "corner")
	# 4. The moonsault: carried backward along the mat at a constant speed while
	# the clip turns him over.
	_seg_add(MOONSAULT_TICKS, {"clip": "strikes/moonsault", "from": _stand, "to": _land,
			"facing": _out}, "dive", [[MOONSAULT_CONTACT, "landed"]])


func _seg_add(ticks: int, a: Dictionary, shot: String, events: Array = []) -> void:
	_segments.append({"ticks": maxi(ticks, 1), "a": a, "shot": shot, "events": events})


func _next() -> void:
	_seg += 1
	_tick = 0
	if _seg >= _segments.size():
		_finish()
		return
	var seg: Dictionary = _segments[_seg]
	attacker.play_presentation_clip(seg["a"]["clip"])
	_frame_shot(seg, true, 1.0 / TPS)


func _physics_process(delta: float) -> void:
	if _seg < 0 or _seg >= _segments.size():
		return
	var seg: Dictionary = _segments[_seg]
	_tick += 1
	var t := clampf(float(_tick) / float(seg["ticks"]), 0.0, 1.0)
	var beat: Dictionary = seg["a"]
	attacker.global_position = (beat["from"] as Vector3).lerp(beat["to"], t)
	var facing: Vector3 = beat["facing"]
	if facing == Vector3.ZERO:
		facing = DiveSpot._flat(defender.global_position - attacker.global_position) \
				if t > 0.7 else DiveSpot._flat(beat["to"] - beat["from"])
	if facing.length() > 0.01:
		var want := atan2(-facing.x, -facing.z)
		attacker.rotation.y = rotate_toward(attacker.rotation.y, want, TURN_RATE * delta)
	for cue: Array in seg["events"]:
		if int(cue[0]) == _tick:
			_event(cue[1])
	_frame_shot(seg, false, delta)
	if _tick >= int(seg["ticks"]):
		_next()


func _event(what: String) -> void:
	if what == "landed" and attacker.top_rope_move:
		defender.combat.apply_damage(attacker.top_rope_move)
		attacker.combat.apply_momentum(attacker.top_rope_move)
		if defender.hit_flinch:
			defender.hit_flinch.hit(attacker.global_position, "body", 1.0)


## A wide from the side of the corner that holds the corner and the man; for
## the climb, lower and closer on the corner; for the dive, the wide again,
## lower, so the arc reads against the crowd.
func _frame_shot(seg: Dictionary, cut: bool, delta: float) -> void:
	if _camera == null:
		return
	var side := Vector3.UP.cross(_out).normalized()
	var mid := (_stand + defender.global_position) * 0.5
	# Away from the referee, who walks the ring through the spot.
	if _cam_flip == 0.0:
		_cam_flip = 1.0
		var ref := get_parent().find_child("RefereeActor", true, false) as Node3D
		if ref and side.dot(ref.global_position - mid) > 0.0:
			_cam_flip = -1.0
	side *= _cam_flip
	match seg["shot"]:
		"corner":
			_camera.set_entrance_shot(_stand - _out * 3.4 + side * 1.6 + Vector3(0, 1.6, 0),
					_stand + Vector3(0, 1.6, 0), 46.0, cut, delta)
		"dive":
			_camera.set_entrance_shot(mid + side * 4.6 + Vector3(0, 1.4, 0),
					mid + Vector3(0, 1.0, 0), 52.0, cut, delta)
		_:
			_camera.set_entrance_shot(mid + side * 5.2 + Vector3(0, 2.0, 0),
					mid + Vector3(0, 0.8, 0), 50.0, cut, delta)


func _finish() -> void:
	for entry: Array in _frozen:
		(entry[0] as Node).set_physics_process(entry[1])
	attacker.velocity = Vector3.ZERO
	# Lying across him: the match's cover is carried from here, not from a
	# cut to standing.
	attacker.end_presentation(true)
	MatchSmoothing.snap(attacker)
	if _camera:
		_camera.resume_play()
	finished.emit()
	queue_free()
