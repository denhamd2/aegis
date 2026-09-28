class_name DiveSpot
extends Node
## Cody's dives, as one set piece off the ropes (gauntlet/refs/cody_moveset.md):
## the man he has knocked down near the ropes gets up and tumbles out through
## them to the floor; Cody hits the ropes behind him, rebounds, and goes
## head-first through the middle and top ropes into him -- the tope suicida --
## and they are both down on the floor. The man rolls back in, Cody climbs to
## the apron, and as the man turns to him, Cody springs off the middle rope
## into a spinning Disaster Kick that drops him inside for the cover.
##
## Built the way EntranceDirector is, and for the same reasons: there is no
## collision off the mat and keep_inside_the_ring() would snap a man on the
## floor back onto it, so while the spot plays both wrestlers, their AI, the
## referee and the grapple rig are frozen (set_physics_process(false)) and the
## men are placed kinematically on the floor and apron heights, playing the
## travelling clips wrestling_clips.py keys in world space. The referee is the
## only thing that advances ReplaySystem's tick, so the spot takes no match
## ticks: its trigger is deterministic, so a replay plays it identically.
##
## MatchReferee starts it (_wants_dive), once a match, for a wrestler whose
## Roster moveset carries "dive" -- Cody.

signal finished

const TPS := 60.0
## How far out the downed man has to be for the spot to be on: off the ropes,
## not from mid-ring.
const NEAR_ROPES := 1.0
## The ring, from RingBuilder/ArenaBuilder (and wrestling_clips.py's dive keys).
const FLOOR_Y := ArenaBuilder.FLOOR_Y + ArenaBuilder.RINGSIDE_MAT_LIFT
const TUMBLE_FROM := 2.35
const FLOOR_AT := 3.9
const RUN_TO := -2.45
const TAKEOFF := 1.30
const TOPE_TO := 3.25
const ROLL_IN_FROM := 3.6
const ROLL_IN_TO := 2.3
const CLIMB_FROM := 3.6
const APRON_AT := 3.15
const SPRING_TO := 2.3
const KICKED_AT := 1.85
## Lateral spread along the rope side: the man rolls in on one side of where
## it started and Cody climbs on the other, so neither crosses the other.
const LANE := 0.5
## Clip timings in 60 Hz ticks (authored frames x 2).
const GETUP_TICKS := 126
const ROLL_OUT_TICKS := 92
const TOPE_TICKS := 120
const TOPE_CONTACT := 28
const TOPE_DEFENDER_TICKS := 340
const ROLL_IN_TICKS := 120
const CLIMB_TICKS := 72
const SPRING_TICKS := 96
const SPRING_CONTACT := 48
const KICKED_CONTACT := 36
const KICKED_TICKS := 84
## Pace of the clips the men travel on.
const HURT_WALK := 0.5
const WALK := 1.2
const RUN := 7.0
const TURN_RATE := 6.0

const TOPE_MOVE := "res://resources/moves/dive_tope_suicida.tres"
const SPRING_MOVE := "res://resources/moves/dive_springboard_disaster_kick.tres"

var attacker: WrestlerController
var defender: WrestlerController
var _camera: MatchCamera
var _frozen: Array = []
var _segments: Array = []
var _seg := -1
var _tick := 0
var _out := Vector3.RIGHT
var _lat := Vector3.BACK
var _lane := 0.0
var _cam_side := 1.0


## Whether a man down here is near enough the ropes for the spot.
static func near_ropes(w: WrestlerController) -> bool:
	return maxf(absf(w.global_position.x), absf(w.global_position.z)) >= NEAR_ROPES


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
	# The rope side nearest where he went down.
	var p := defender.global_position
	if absf(p.x) >= absf(p.z):
		_out = Vector3(signf(p.x), 0, 0)
		_lat = Vector3(0, 0, 1)
		_lane = clampf(p.z, -1.4, 1.4)
	else:
		_out = Vector3(0, 0, signf(p.z))
		_lat = Vector3(1, 0, 0)
		_lane = clampf(p.x, -1.4, 1.4)
	_cam_side = -1.0 if _lane > 0.0 else 1.0
	# Out of DOWN on the FSM's own legal route, so the animation tree is in a
	# state the presentation clips can travel from.
	if defender.fsm.current_state == WrestlerFSM.State.DOWN:
		defender.fsm.transition_to(WrestlerFSM.State.GETUP)
	defender.fsm.transition_to(WrestlerFSM.State.IDLE)
	if attacker.fsm.current_state != WrestlerFSM.State.IDLE:
		attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	_build()
	_next()


## A point by the rope side: `out` metres from the centre toward it, the lane
## `lat` along it, at height `y`.
func at(out: float, lat: float, y: float = 0.0) -> Vector3:
	return _out * out + _lat * lat + Vector3(0, y, 0)


func _build() -> void:
	var d0 := defender.global_position
	var a0 := attacker.global_position
	var tumble := at(TUMBLE_FROM, _lane)
	var floor_spot := at(FLOOR_AT, _lane, FLOOR_Y)
	var in_lane := _lane - LANE
	var up_lane := _lane + LANE
	# 1. He gets up where he lay.
	_seg_add(GETUP_TICKS, _hold("strikes/getup_rise", d0, -1),
			_hold("strikes/idle_ready", a0, 0, d0))
	# 2. Staggers to the ropes, facing them.
	var walk_ticks := _ticks(_flat(d0).distance_to(_flat(tumble)), HURT_WALK)
	_seg_add(maxi(walk_ticks, 20), _go("strikes/walk_slow_look", d0, tumble, _out),
			_hold("strikes/idle_ready", a0, 0, tumble))
	# 3. Out through them to the floor.
	_seg_add(ROLL_OUT_TICKS, _go("strikes/roll_out_ropes", tumble, floor_spot, _out),
			_hold("strikes/idle_ready", a0, 0, floor_spot))
	# 4. Cody to the far ropes while the man turns round on the floor.
	var far := at(RUN_TO, _lane)
	_seg_add(maxi(_ticks(_flat(a0).distance_to(_flat(far)), RUN), 24),
			_hold("strikes/stunned", floor_spot, 0, a0),
			_go("strikes/run_drive", a0, far, -_out))
	# 5. The rebound.
	_seg_add(12, _hold("strikes/stunned", floor_spot, 0, far),
			_go("strikes/run_drive", far, far, _out))
	# 6. The run in.
	var takeoff := at(TAKEOFF, _lane)
	_seg_add(_ticks(_flat(far).distance_to(_flat(takeoff)), RUN),
			_hold("strikes/stunned", floor_spot, 0, takeoff),
			_go("strikes/run_drive", far, takeoff, _out), "wide")
	# 7. The tope suicida.
	var landed := at(TOPE_TO, _lane, FLOOR_Y)
	_seg_add(TOPE_TICKS, _hold("strikes/tope_defender", floor_spot, 0, takeoff),
			_go("strikes/tope_attacker", takeoff, landed, _out), "floor",
			[[TOPE_CONTACT, "tope_hit"]])
	# 8. Both down on the floor; he is up first, Cody gathers himself and
	# heads for the apron.
	var climb_from := at(CLIMB_FROM, up_lane, FLOOR_Y)
	var recover := TOPE_DEFENDER_TICKS - TOPE_TICKS
	var cody_walk := _ticks(_flat(landed).distance_to(_flat(climb_from)), WALK)
	_seg_add(cody_walk, _cont(floor_spot), _go("strikes/walk_crowd", landed, climb_from, Vector3.ZERO))
	_seg_add(maxi(recover - cody_walk, 1), _cont(floor_spot),
			_hold("strikes/stunned", climb_from, 0, at(0.0, up_lane)))
	# 9. He walks to where he rolls in.
	var roll_from := at(ROLL_IN_FROM, in_lane, FLOOR_Y)
	_seg_add(maxi(_ticks(_flat(floor_spot).distance_to(_flat(roll_from)), HURT_WALK), 20),
			_go("strikes/walk_slow_look", floor_spot, roll_from, Vector3.ZERO),
			_hold("strikes/stunned", climb_from, 0, at(0.0, up_lane)))
	# 10. In under the bottom rope; Cody up onto the apron as he does.
	var inside := at(ROLL_IN_TO, in_lane)
	var apron := at(APRON_AT, up_lane)
	_seg_add(ROLL_IN_TICKS, _go("strikes/roll_in", roll_from, inside, -_out),
			_go("strikes/apron_climb", climb_from, apron, -_out, ROLL_IN_TICKS - CLIMB_TICKS),
			"wide")
	# 11. He staggers round to face Cody, into the kick's reach.
	var kicked := at(KICKED_AT, up_lane)
	_seg_add(maxi(_ticks(_flat(inside).distance_to(_flat(kicked)), HURT_WALK), 30),
			_go("strikes/walk_slow_look", inside, kicked, Vector3.ZERO),
			_hold("strikes/apron_climb", apron, 0, at(0.0, up_lane)))
	_seg_add(24, _hold("strikes/idle_ready", kicked, 0, apron),
			_hold("strikes/apron_climb", apron, 0, kicked))
	# 12. The springboard Disaster Kick.
	_seg_add(SPRING_TICKS,
			_go("strikes/disaster_kick_defender", kicked, kicked, _out,
					SPRING_CONTACT - KICKED_CONTACT),
			_go("strikes/springboard_dk_attacker", apron, at(SPRING_TO, up_lane), -_out),
			"wide", [[SPRING_CONTACT, "kick_hit"]])


## One segment: what each man does, the shot, and cues at ticks into it.
func _seg_add(ticks: int, d: Dictionary, a: Dictionary, shot := "wide",
		events: Array = []) -> void:
	_segments.append({"ticks": maxi(ticks, 1), "d": d, "a": a, "shot": shot,
			"events": events})


## Travel `from` -> `to` on `clip`, facing `facing` (ZERO: the way he walks),
## after `delay` ticks of whatever he was doing.
func _go(clip: String, from: Vector3, to: Vector3, facing: Vector3, delay := 0) -> Dictionary:
	return {"clip": clip, "from": from, "to": to, "facing": facing, "delay": delay}


## Stand at `where` playing `clip`, turning to look at `look` (or, with
## `facing_sign` -1, keeping his heading).
func _hold(clip: String, where: Vector3, facing_sign: int, look := Vector3.INF) -> Dictionary:
	var facing := Vector3.INF if facing_sign < 0 else Vector3.ZERO
	return {"clip": clip, "from": where, "to": where, "facing": facing, "look": look,
			"delay": 0}


## Carry on with the clip already playing, where he is.
func _cont(where: Vector3) -> Dictionary:
	return {"clip": "", "from": where, "to": where, "facing": Vector3.INF, "delay": 0}


static func _ticks(distance: float, speed: float) -> int:
	return maxi(1, int(ceil(distance / speed * TPS)))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _next() -> void:
	_seg += 1
	_tick = 0
	if _seg >= _segments.size():
		_finish()
		return
	var seg: Dictionary = _segments[_seg]
	for pair: Array in [[defender, seg["d"]], [attacker, seg["a"]]]:
		var beat: Dictionary = pair[1]
		if int(beat["delay"]) == 0 and beat["clip"] != "":
			(pair[0] as WrestlerController).play_presentation_clip(beat["clip"])
	_frame_shot(seg, true, 1.0 / TPS)


func _physics_process(delta: float) -> void:
	if _seg < 0 or _seg >= _segments.size():
		return
	var seg: Dictionary = _segments[_seg]
	_tick += 1
	var t := clampf(float(_tick) / float(seg["ticks"]), 0.0, 1.0)
	for pair: Array in [[defender, seg["d"]], [attacker, seg["a"]]]:
		_drive(pair[0], pair[1], t, delta)
	for cue: Array in seg["events"]:
		if int(cue[0]) == _tick:
			_event(cue[1])
	_frame_shot(seg, false, delta)
	if _tick >= int(seg["ticks"]):
		_next()


func _drive(w: WrestlerController, beat: Dictionary, t: float, delta: float) -> void:
	var delay: int = beat["delay"]
	if delay > 0 and _tick == delay and beat["clip"] != "":
		w.play_presentation_clip(beat["clip"])
	var from: Vector3 = beat["from"]
	var to: Vector3 = beat["to"]
	# A delayed clip's travel runs over what is left of the segment.
	var span := float(_segments[_seg]["ticks"]) - float(delay)
	var u := t if delay <= 0 else clampf((_tick - delay) / maxf(span, 1.0), 0.0, 1.0)
	w.global_position = from.lerp(to, u)
	var facing: Vector3 = beat["facing"]
	if facing == Vector3.ZERO:
		# The way he is going, or toward what he looks at.
		var look: Vector3 = beat.get("look", Vector3.INF)
		facing = _flat(to - from) if look == Vector3.INF else _flat(look - w.global_position)
	if facing != Vector3.INF and facing.length() > 0.01:
		var want := atan2(-facing.x, -facing.z)
		w.rotation.y = rotate_toward(w.rotation.y, want, TURN_RATE * delta)


func _event(what: String) -> void:
	match what:
		"tope_hit":
			var tope := load(TOPE_MOVE) as MoveDef
			if tope:
				defender.combat.apply_damage(tope)
				attacker.combat.apply_momentum(tope)
		"kick_hit":
			var kick := load(SPRING_MOVE) as MoveDef
			if kick:
				defender.combat.apply_damage(kick)
				attacker.combat.apply_momentum(kick)


## Two cameras: a wide from the side, level with the ropes, that holds both
## men; and for the tope, low on the floor outside, looking back at the ring
## so the dive comes through the ropes at the lens.
func _frame_shot(seg: Dictionary, cut: bool, delta: float) -> void:
	if _camera == null:
		return
	var mid := (attacker.global_position + defender.global_position) * 0.5
	match seg["shot"]:
		"floor":
			_camera.set_entrance_shot(at(5.7, _lane + 2.4 * _cam_side, FLOOR_Y + 0.45),
					at(3.2, _lane, FLOOR_Y + 0.9), 58.0, cut, delta)
		_:
			# Outside the rope side on the diagonal, a little above the
			# apron, looking back in: the floor, the ropes and the mat
			# inside them all in one frame. (From the far side, tried
			# first, the apron hid everything that happened on the floor.)
			var eye := at(6.2, _lane + 4.6 * _cam_side, 1.7)
			_camera.set_entrance_shot(eye, mid + Vector3(0, 0.6, 0), 50.0, cut, delta)


func _finish() -> void:
	for entry: Array in _frozen:
		(entry[0] as Node).set_physics_process(entry[1])
	for w: WrestlerController in [attacker, defender]:
		w.velocity = Vector3.ZERO
		w.end_presentation()
	# He lies head away from Cody, as the kick's victim half ends: turned
	# round on the mat and down, the knockdown a move gives.
	defender._turn_round_on_the_mat()
	defender._go_down()
	attacker.last_landed_tier = CombatSystem.Tier.SIGNATURE
	if _camera:
		_camera.resume_master()
	finished.emit()
	queue_free()
