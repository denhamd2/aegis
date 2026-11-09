class_name CageEscape
extends Node
## Getting out of the cage (gauntlet/refs/steel_cage.md): up the wall, over
## the top and down the outside, or calling for the door and going through it
## -- and the other man climbing after him to pull him off. Shared by every
## caged match (the Steel Cage now, Hell in a Cell next); the cage itself is
## CageBuilder, and this reads only its Spec.
##
## A man doing any of it is in WrestlerFSM.State.CAGE_ESCAPE, and this holds
## which part (Climb.route, Climb.phase). His root is placed on a scripted
## path each tick, as DiveSpot and the rope cross place it -- no physics, no
## clamps -- from his own CAGE_ESCAPE tick (WrestlerController), so it runs
## in his slot of the frame and a replay reproduces it. No randomness: every
## decision is input or a tick count.
##
##   route CLIMB   CLIMB -> OVER -> DESCEND -> DROP -> landed: escaped
##   route DOOR    CALL (the door unlocked and swung) -> EXIT -> landed: escaped
##   route CHASE   up the wall after a climber: pull him off, then BACK_DOWN
##
## Stoppable, as in 2K: a climb until he is over the top (OVER_SAFE); the door
## until the exit starts. After that it cannot be stopped.

signal escaped(wrestler: WrestlerController)
signal pulled_off(climber: WrestlerController, by: WrestlerController)
signal attempt_started(wrestler: WrestlerController, route: int)

const GROUP := &"cage_escape"

enum Route { CLIMB, DOOR, CHASE }
enum Phase { CLIMB, OVER, DESCEND, DROP, CALL, EXIT, BACK_DOWN, DONE }
const PHASE_NAMES := ["CLIMBING", "OVER THE TOP", "CLIMBING DOWN", "DROPPING DOWN",
		"DOOR OPENING", "THROUGH THE DOOR", "CLIMBING DOWN", "ESCAPED"]

## The climb, phase by phase (60 Hz ticks). Mat to the top rail; the swing
## over, straddling the top; down the outside; the drop to the floor.
const CLIMB_TICKS := 270
## Up onto the top rail (the first 30%), straddling it while he gets a leg
## over (the middle), and down onto the outside (the last 30%): 2K's
## "two escape mini-games" on top, as time the other man has to get there.
const OVER_TICKS := 240
## Past this much of the swing over he is on the outside: out of reach.
const OVER_SAFE := 0.65
const DESCEND_TICKS := 100
const DROP_TICKS := 32
## The door: the official outside unlocks it, then swings it open; he goes
## through on DOOR_OPEN_TICKS. A player who lets go of the push this long
## gives up, and the door is shut again.
const DOOR_UNLOCK_TICKS := 180
const DOOR_OPEN_TICKS := 360
const DOOR_LET_GO_TICKS := 24
const DOOR_CLOSE_RATE := 1.0 / 40.0
## A man climbing after a climber goes up faster than a man trying to get
## out (he is not careful), and climbs back down faster still.
const CHASE_TICKS := 120
const BACK_DOWN_TICKS := 70
## Climbing back down (a player pushing away from the wall): this many times
## the climb's rate.
const CLIMB_DOWN_RATE := 2

## His body against the steel. From his root (between his feet): his hands
## reach the top rail with his root this far under it; his root hangs this far
## off the wall's plane while he climbs it; it stands this far under the top
## rail while he straddles it.
const HANDS_ABOVE_ROOT := 1.95
const WALL_GAP := 0.40
const PEAK_BELOW_TOP := 0.95
## Down the outside to this height over the wall's foot (his boots on the
## bottom rail's level), then drop, this much further out, to the floor:
## 1.4 m, free fall's 0.53 s.
const LOW_ABOVE_BASE := 0.45
const DROP_OUT := 0.15
## Climbs are kept this far from the corner posts, and this far either side
## of the door's jambs.
const CORNER_KEEP := 0.65
const DOOR_KEEP := 0.45
## He starts from the ropes: within this of RING_KEEP_IN (his clamp).
const START_SLACK := 0.35
## A man pushing into the wall within this of a climber along it climbs after
## him, beside him, this far along.
const CHASE_START_REACH := 1.6
const CHASE_LANE_GAP := 0.75
## The chaser's hands this far above the climber's boots: he has him.
const PULL_REACH := 0.20
## A man down while the other man escapes rallies: his down timer runs this
## many times as fast, and off anything short of a finisher he has at most
## RALLY_CAP_TICKS of it left -- then up on the quick rise. So an escape off a
## signature is a near-escape, and one off a finisher gets out.
const RALLY_RATE := 2
const RALLY_CAP_TICKS := 300
## Off the wall into the ring: the shove he falls with. From this high (his
## root) it is a fall from the top of the cage, and keeps him down as a
## signature does.
const FALL_SHOVE := 1.1
const HIGH_FALL := 1.5

const CAGE_FALL_MOVE := preload("res://resources/moves/cage_fall.tres")


class Climb:
	extends RefCounted
	var w: WrestlerController
	var route := Route.CLIMB
	var phase := Phase.CLIMB
	var ticks := 0
	var axis := Vector3.RIGHT
	var lane := 0.0
	var start := Vector3.ZERO
	## CHASE: the man he goes after; CHASE and BACK_DOWN: his root's height.
	var target: WrestlerController
	var height := 0.0
	var let_go := 0
	## EXIT: where the step through the ropes starts.
	var exit_from := Vector3.ZERO


var cage: CageBuilder
var _climbs := {}
var _door := 0.0
## Escapes completed, attempts started, men pulled off (probes, tests).
var escapes := 0
var attempts := 0
var pull_offs := 0


static func of(node: Node) -> CageEscape:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as CageEscape


func _ready() -> void:
	add_to_group(GROUP)
	if cage == null:
		cage = CageBuilder.of(self)


func _spec() -> CageBuilder.Spec:
	return cage.spec if cage else CageBuilder.Spec.steel_cage()


## The rail-to-root height of the climb: his root when his hands are on the
## top rail.
func climb_top_y() -> float:
	return _spec().top_y - HANDS_ABOVE_ROOT


# --------------------------------------------------------------------------
# Queries

func climb_of(w: WrestlerController) -> Climb:
	return _climbs.get(w) as Climb


## Whether `w` is on his way out (not a chaser, not done).
func is_escaping(w: WrestlerController) -> bool:
	var c := climb_of(w)
	return c != null and c.route != Route.CHASE and c.phase != Phase.DONE


## Whether he can still be stopped.
func is_stoppable(w: WrestlerController) -> bool:
	var c := climb_of(w)
	if c == null:
		return false
	match c.phase:
		Phase.CLIMB:
			return true
		Phase.OVER:
			return float(c.ticks) / OVER_TICKS < OVER_SAFE
		Phase.CALL:
			return true
	return false


## How far through his escape he is, 0..1, over the whole route.
func progress(w: WrestlerController) -> float:
	var c := climb_of(w)
	if c == null or c.route == Route.CHASE:
		return 0.0
	if c.route == Route.DOOR:
		var total := float(DOOR_OPEN_TICKS + WrestlerController.RING_EXIT_TICKS)
		var done := float(c.ticks) if c.phase == Phase.CALL else float(DOOR_OPEN_TICKS + c.ticks)
		return clampf(done / total, 0.0, 1.0) if c.phase != Phase.DONE else 1.0
	var spans := [CLIMB_TICKS, OVER_TICKS, DESCEND_TICKS, DROP_TICKS]
	var sum := 0.0
	for s: int in spans:
		sum += s
	var before := 0.0
	for i in mini(int(c.phase), spans.size()):
		before += spans[i]
	if c.phase == Phase.DONE:
		return 1.0
	return clampf((before + float(c.ticks)) / sum, 0.0, 1.0)


func phase_name(w: WrestlerController) -> String:
	var c := climb_of(w)
	return "" if c == null else PHASE_NAMES[int(c.phase)]


## Whether `w`, where he stands, is at a wall he could start up (or at the
## door). The HUD's prompt.
func at_wall(w: WrestlerController) -> bool:
	if cage == null or w.outside_ring:
		return false
	var p := Vector3(w.global_position.x, 0.0, w.global_position.z)
	return p.dot(CageBuilder.wall_axis(p)) >= WrestlerController.RING_KEEP_IN - START_SLACK


func at_door(w: WrestlerController) -> bool:
	return at_wall(w) and cage.in_door_lane(w.global_position, 0.15)


## Where a man stands to climb after `climber`: at the ropes, beside his lane,
## on the side `from` is on (or the other if that is past a corner).
func chase_spot(climber: WrestlerController, from: Vector3) -> Vector3:
	var c := climb_of(climber)
	if c == null:
		return Vector3.INF
	if c.route == Route.DOOR:
		return c.start - c.axis * 0.75
	var lat := CageBuilder.lateral_of(c.axis)
	var keep := _spec().half - CORNER_KEEP
	var side := signf(from.dot(lat) - c.lane)
	if side == 0.0:
		side = 1.0
	var lane := c.lane + side * CHASE_LANE_GAP
	if absf(lane) > keep:
		lane = c.lane - side * CHASE_LANE_GAP
	return c.axis * WrestlerController.RING_KEEP_IN + lat * lane


# --------------------------------------------------------------------------
# Starting

## `w` goes for it from where he stands: up the wall after a climber already
## on it, through the door when he is at it (unless `climb_only`), else up
## the wall. Returns whether he started.
func begin(w: WrestlerController, climb_only := false) -> bool:
	if cage == null or w.outside_ring or _climbs.has(w) or not w.fsm.is_in([
			WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN]):
		return false
	if not at_wall(w):
		return false
	var p := Vector3(w.global_position.x, 0.0, w.global_position.z)
	var axis := CageBuilder.wall_axis(p)
	var lat := CageBuilder.lateral_of(axis)
	var along := p.dot(lat)
	var spec := _spec()
	var c := Climb.new()
	c.w = w
	c.axis = axis
	c.start = Vector3(p.x, w.global_position.y, p.z)
	# A climber on this wall within reach: after him.
	for other: WrestlerController in _climbs:
		var oc: Climb = _climbs[other]
		if other != w and oc.route == Route.CLIMB and oc.axis == axis and is_stoppable(other) \
				and absf(oc.lane - along) <= CHASE_START_REACH:
			c.route = Route.CHASE
			c.phase = Phase.CLIMB
			c.target = other
			var side := signf(along - oc.lane)
			if side == 0.0:
				side = 1.0
			c.lane = oc.lane + side * CHASE_LANE_GAP
			if absf(c.lane) > spec.half - CORNER_KEEP:
				c.lane = oc.lane - side * CHASE_LANE_GAP
			break
	if c.route != Route.CHASE:
		if not climb_only and cage.in_door_lane(p, 0.15):
			c.route = Route.DOOR
			c.phase = Phase.CALL
			c.lane = clampf(along, -spec.door_width * 0.5 + 0.25, spec.door_width * 0.5 - 0.25)
		else:
			c.route = Route.CLIMB
			c.phase = Phase.CLIMB
			var keep := spec.half - CORNER_KEEP
			c.lane = clampf(along, -keep, keep)
			if axis == spec.door_axis:
				var jamb := spec.door_width * 0.5 + DOOR_KEEP
				if absf(c.lane) < jamb:
					c.lane = jamb * (signf(c.lane) if c.lane != 0.0 else 1.0)
	_climbs[w] = c
	var clip := "strikes/whoa_arms" if c.route == Route.DOOR else "strikes/ladder_climb"
	w.begin_cage_escape(clip)
	if c.route != Route.CHASE:
		attempts += 1
	attempt_started.emit(w, c.route)
	_tick_climb(c, {})
	return true


## Stops whatever he was doing on the cage without a fall (a hit at the door,
## the match ending): forgets him. His state is the caller's.
func forget(w: WrestlerController) -> void:
	var c := climb_of(w)
	if c == null:
		return
	if c.phase == Phase.EXIT:
		w._release_ropes_out()
	_climbs.erase(w)


# --------------------------------------------------------------------------
# Each tick (from his own CAGE_ESCAPE tick)

func tick(w: WrestlerController, input: Dictionary) -> void:
	var c := climb_of(w)
	if c == null:
		# In CAGE_ESCAPE with nothing to do (forgotten): back to his feet.
		w.end_cage_escape(false)
		return
	_tick_climb(c, input)


func _tick_climb(c: Climb, input: Dictionary) -> void:
	match c.phase:
		Phase.CLIMB:
			if c.route == Route.CHASE:
				_tick_chase(c)
			else:
				_tick_up(c, input)
		Phase.OVER:
			_tick_over(c)
		Phase.DESCEND:
			_tick_descend(c)
		Phase.DROP:
			_tick_drop(c)
		Phase.CALL:
			_tick_call(c, input)
		Phase.EXIT:
			_tick_exit(c)
		Phase.BACK_DOWN:
			_tick_back_down(c)
		Phase.DONE:
			c.w.velocity = Vector3.ZERO


func _at(c: Climb, out: float, y: float) -> Vector3:
	return c.axis * out + CageBuilder.lateral_of(c.axis) * c.lane + Vector3.UP * y


func _face(w: WrestlerController, dir: Vector3) -> void:
	w.rotation.y = atan2(-dir.x, -dir.z)


func _pushing_away(c: Climb, input: Dictionary) -> bool:
	if c.w.is_ai:
		return false
	var move: Vector2 = input.get("move", Vector2.ZERO)
	if move.length() < 0.5:
		return false
	return Vector3(move.x, 0.0, move.y).normalized().dot(c.axis) < -0.5


func _pushing_in(c: Climb, input: Dictionary) -> bool:
	if c.w.is_ai:
		return input.get("cage_door", true)
	var move: Vector2 = input.get("move", Vector2.ZERO)
	if move.length() < 0.5:
		return false
	return Vector3(move.x, 0.0, move.y).normalized().dot(c.axis) > 0.5


func _tick_up(c: Climb, input: Dictionary) -> void:
	var w := c.w
	w.velocity = Vector3.ZERO
	if _pushing_away(c, input):
		c.ticks -= CLIMB_DOWN_RATE
		if c.ticks <= 0:
			w.global_position = Vector3(c.start.x, 0.0, c.start.z)
			_climbs.erase(w)
			w.end_cage_escape(false)
			return
	else:
		c.ticks += 1
	var u := clampf(float(c.ticks) / CLIMB_TICKS, 0.0, 1.0)
	var start_out := c.start.dot(c.axis)
	var wall_in := _spec().half - WALL_GAP
	var out := lerpf(start_out, wall_in, smoothstep(0.0, 1.0, minf(u * 2.5, 1.0)))
	w.global_position = _at(c, out, climb_top_y() * u)
	_face(w, c.axis)
	if c.ticks >= CLIMB_TICKS:
		c.phase = Phase.OVER
		c.ticks = 0


func _tick_over(c: Climb) -> void:
	var w := c.w
	w.velocity = Vector3.ZERO
	c.ticks += 1
	var v := clampf(float(c.ticks) / OVER_TICKS, 0.0, 1.0)
	var spec := _spec()
	var out := lerpf(spec.half - WALL_GAP, spec.half + WALL_GAP, smoothstep(0.3, 0.7, v))
	var top := climb_top_y()
	var peak := spec.top_y - PEAK_BELOW_TOP
	var up := smoothstep(0.0, 0.3, v) * (1.0 - smoothstep(0.7, 1.0, v))
	w.global_position = _at(c, out, top + (peak - top) * up)
	# Facing the wall going up; turned round as he swings his legs over, to
	# face it again from the outside on the way down.
	var turn := smoothstep(0.35, 0.65, v)
	var yaw_out := atan2(-c.axis.x, -c.axis.z)
	w.rotation.y = yaw_out + PI * turn
	if c.ticks == 1:
		w.cage_clip("strikes/ladder_climb")
	if c.ticks >= OVER_TICKS:
		c.phase = Phase.DESCEND
		c.ticks = 0


func _tick_descend(c: Climb) -> void:
	var w := c.w
	w.velocity = Vector3.ZERO
	c.ticks += 1
	var t := clampf(float(c.ticks) / DESCEND_TICKS, 0.0, 1.0)
	var spec := _spec()
	var low := spec.base_y + LOW_ABOVE_BASE
	w.global_position = _at(c, spec.half + WALL_GAP, lerpf(climb_top_y(), low, t))
	_face(w, -c.axis)
	if c.ticks >= DESCEND_TICKS:
		c.phase = Phase.DROP
		c.ticks = 0
		w.cage_clip("strikes/idle_ready")


func _tick_drop(c: Climb) -> void:
	var w := c.w
	w.velocity = Vector3.ZERO
	c.ticks += 1
	var t := clampf(float(c.ticks) / DROP_TICKS, 0.0, 1.0)
	var spec := _spec()
	var low := spec.base_y + LOW_ABOVE_BASE
	var floor_y := WrestlerController.FLOOR_LEVEL
	var out := lerpf(spec.half + WALL_GAP, spec.half + WALL_GAP + DROP_OUT, t)
	w.global_position = _at(c, out, low - (low - floor_y) * t * t)
	_face(w, -c.axis)
	if c.ticks >= DROP_TICKS:
		_land(c)


func _tick_call(c: Climb, input: Dictionary) -> void:
	var w := c.w
	w.velocity = Vector3.ZERO
	if _pushing_in(c, input):
		c.let_go = 0
	else:
		c.let_go += 1
		if c.let_go >= DOOR_LET_GO_TICKS:
			_climbs.erase(w)
			w.end_cage_escape(false)
			return
	c.ticks += 1
	var at := _at(c, WrestlerController.RING_KEEP_IN, c.start.y)
	var from := Vector3(w.global_position.x, at.y, w.global_position.z)
	w.global_position = from.move_toward(at, 0.03)
	_face(w, c.axis)
	if c.ticks >= DOOR_OPEN_TICKS:
		c.phase = Phase.EXIT
		c.ticks = 0
		c.exit_from = w.global_position
		w._cross_facing = c.axis
		w.cage_clip("strikes/ring_exit")


func _tick_exit(c: Climb) -> void:
	var w := c.w
	w.velocity = Vector3.ZERO
	c.ticks += 1
	var total := WrestlerController.RING_EXIT_TICKS
	var t := clampf(float(c.ticks) / total, 0.0, 1.0)
	w.global_position = WrestlerController.ring_exit_point(c.exit_from, c.axis, t,
			WrestlerController.FLOOR_LEVEL,
			WrestlerController.RING_EXIT_FROM - c.exit_from.dot(c.axis))
	w._part_ropes_out(t * WrestlerController.RING_EXIT_FRAMES)
	_face(w, c.axis)
	if c.ticks >= total:
		w._release_ropes_out()
		_land(c)


func _tick_chase(c: Climb) -> void:
	var w := c.w
	w.velocity = Vector3.ZERO
	var tc := climb_of(c.target) if is_instance_valid(c.target) else null
	if tc == null or tc.route != Route.CLIMB or not is_stoppable(c.target):
		c.phase = Phase.BACK_DOWN
		_tick_back_down(c)
		return
	var top := climb_top_y()
	c.height = minf(top, c.height + top / CHASE_TICKS)
	c.ticks += 1
	var out := lerpf(c.start.dot(c.axis), _spec().half - WALL_GAP,
			smoothstep(0.0, 1.0, minf(float(c.ticks) / (CHASE_TICKS * 0.4), 1.0)))
	w.global_position = _at(c, out, c.height)
	_face(w, c.axis)
	if c.height + HANDS_ABOVE_ROOT >= c.target.global_position.y + PULL_REACH:
		pull_off(c.target, w)
		c.phase = Phase.BACK_DOWN


func _tick_back_down(c: Climb) -> void:
	var w := c.w
	w.velocity = Vector3.ZERO
	c.height = maxf(0.0, c.height - climb_top_y() / BACK_DOWN_TICKS)
	var p := w.global_position
	var flat := Vector3(p.x, 0.0, p.z)
	var inside := flat.move_toward(_at(c, WrestlerController.RING_KEEP_IN, 0.0), 0.02)
	w.global_position = Vector3(inside.x, c.height, inside.z)
	_face(w, c.axis)
	if c.height <= 0.0:
		_climbs.erase(w)
		w.end_cage_escape(false)


## Feet on the floor outside the cage.
func _land(c: Climb) -> void:
	var w := c.w
	w.outside_ring = true
	c.phase = Phase.DONE
	c.ticks = 0
	w.global_position.y = WrestlerController.FLOOR_LEVEL
	if MatchRules.escape_wins(w):
		escapes += 1
		escaped.emit(w)
	else:
		# Out of a cage that escaping does not win: on the floor, fighting on.
		_climbs.erase(w)
		w.end_cage_escape(false)


# --------------------------------------------------------------------------
# Being stopped

## `climber` is pulled off the wall by `by` (or knocked off by a blow when `by`
## is null): down into the ring, hurt by the fall, the steel rattling.
func pull_off(climber: WrestlerController, by: WrestlerController) -> void:
	var c := climb_of(climber)
	if c == null:
		return
	_climbs.erase(climber)
	pull_offs += 1
	var height := maxf(0.0, climber.global_position.y)
	climber.combat.apply_damage(CAGE_FALL_MOVE, clampf(0.5 + height / 3.0, 0.5, 1.5))
	if cage:
		cage.rattle(climber.global_position + c.axis * WALL_GAP, 1.0 + height * 0.3)
	climber.begin_cage_fall(-c.axis * FALL_SHOVE, height >= HIGH_FALL)
	pulled_off.emit(climber, by)


## A blow landed on him on the cage (WrestlerController's hit path). Returns
## whether this handled it -- knocked off the wall, or (at the door, through
## the ropes) untouchable -- so the hit reaction is skipped. At the door,
## before the exit, the hit stops him: the door shuts and the hit plays out.
func on_hit(w: WrestlerController) -> bool:
	var c := climb_of(w)
	if c == null:
		return false
	match c.phase:
		Phase.CLIMB, Phase.OVER, Phase.BACK_DOWN:
			pull_off(w, null)
			return true
		Phase.CALL:
			_climbs.erase(w)
			return false
	# Over, down the outside, through the door: out of reach.
	return true


## The door follows whoever is calling for it; nobody, and it swings shut.
func _physics_process(_delta: float) -> void:
	var want := 0.0
	for w: WrestlerController in _climbs.keys():
		if not is_instance_valid(w) or w.fsm.current_state != WrestlerFSM.State.CAGE_ESCAPE \
				and w.fsm.current_state != WrestlerFSM.State.VICTORY:
			_climbs.erase(w)
			continue
		var c: Climb = _climbs[w]
		if c.route != Route.DOOR:
			continue
		if c.phase == Phase.CALL:
			want = maxf(want, clampf(float(c.ticks - DOOR_UNLOCK_TICKS)
					/ float(DOOR_OPEN_TICKS - DOOR_UNLOCK_TICKS), 0.0, 1.0))
		else:
			want = 1.0
	if want >= _door:
		_door = want
	else:
		_door = maxf(want, _door - DOOR_CLOSE_RATE)
	if cage:
		cage.set_door_open(_door)
