class_name CellRoof
extends Node
## Hell in a Cell's door, outside wall and roof (gauntlet/refs/hell_in_a_cell.md
## "The roof", after WWE 2K22-24):
##
##   - the door, locked: forced open (DOOR_FORCE_TICKS), then walked through
##     out of the cell and back in;
##   - the outside of the front wall (the ramp side, the one with room before
##     the barricade), climbed, and over onto the roof; and back down;
##   - the roof: fought on like the floor, at its height, the camera up with
##     them (MatchCamera); a man walked to its edge teeters there; one hurt
##     enough, or struck hard facing out, near it goes over -- off it to the
##     floor, the ramp, a table set up below or the announce desk;
##   - the four centre panels: dented by every slam on them (DENT_*), they
##     give way at PANEL_BREAKS and the man on the panel drops through into
##     the ring.
##
## Every path is in ticks or closed-form ballistics, so a match replays the
## same. A weapon in his hand goes up and comes down with him.

const GROUP := &"cell_roof"
## Forcing the locked door: shaking it, then shouldering it open.
const DOOR_FORCE_TICKS := 90
const DOOR_WALK_TICKS := 48
## Up the outside of the wall, then over the top onto the roof.
const CLIMB_TICKS := 210
const OVER_TICKS := 70
## Down: back over the edge, then down the wall.
const OVER_BACK_TICKS := 60
const DESCEND_TICKS := 150
## Climbed this far below the top before he goes over it.
const OVER_FROM := 1.15
## His boots this far out from the wall's face while he climbs it.
const WALL_OFF := 0.42
## On the roof he is kept this far in from its edge; a walk to it is a teeter.
const EDGE_KEEP := 0.32
## Within this of the edge, a hard blow (or any knockdown, when he is spent)
## sends him over it.
const EDGE_DANGER := 0.95
## Spent: under this share of his health a knockdown near the edge is a fall.
const SPENT_SHARE := 0.38
## A move on the roof is played this far in from the edge (GrappleRig).
const MOVE_KEEP_IN := 1.0
## How long the teeter plays.
const TEETER_TICKS := 46
## The centre panels: a slam's dent, by the tier of what landed.
const DENT_POWER := 1.0
const DENT_SIGNATURE := 1.5
const DENT_FINISHER := 2.0
const PANEL_BREAKS := 4.0
## How far a dented panel sags, per point of damage.
const SAG_PER_DENT := 0.035
## Off the edge: thrown out this fast (m/s), the most from the side walls,
## where the barricade is 0.45 m out, and more off the front and back.
const FALL_OUT_SIDE := 0.7
const FALL_OUT_END := 2.4
const FALL_UP := 1.4
## Damage from the fall, as a multiple of CageEscape's cage_fall move.
const FALL_DAMAGE := 2.6
const THROUGH_DAMAGE := 2.2

var cage: CageBuilder
## Padlocked by the referee once both men are in (gauntlet/refs/
## hell_in_a_cell.md): only the wire cutters open it.
var door_locked := false
var door_forced := false
## Snipping the chain, with the cutters in his hands at the door.
const CUT_TICKS := 90
var damage := {}            # Vector2i bay -> dents
var broken := {}            # Vector2i bay -> true
var falls := 0
var climbs := 0
var _routes := {}           # WrestlerController -> Dictionary
var _breaking := {}         # Vector2i -> ticks since it gave way

signal panel_broke(bay: Vector2i)
signal door_cut(by: WrestlerController)
signal fell_off(wrestler: WrestlerController, through_roof: bool)


static func of(node: Node) -> CellRoof:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as CellRoof


func _ready() -> void:
	add_to_group(GROUP)


func half() -> float:
	return cage.spec.half


func top_y() -> float:
	return cage.spec.top_y


## What a man stands on up there: the top of the roof's mesh.
func surface_y() -> float:
	return cage.spec.top_y + 0.03


func door_axis() -> Vector3:
	return cage.spec.door_axis


## How far `p` is in from the roof's edge (negative past it).
func edge_gap(p: Vector3) -> float:
	return half() - maxf(absf(p.x), absf(p.z))


## The outward normal of the roof edge nearest `p`.
func edge_out(p: Vector3) -> Vector3:
	if absf(p.x) >= absf(p.z):
		return Vector3(signf(p.x) if p.x != 0.0 else 1.0, 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(p.z) if p.z != 0.0 else 1.0)


# --- getting out, up and down -----------------------------------------------

## The door's lane, inside the cell and out of it, at `w`'s height.
func _door_inside() -> Vector3:
	var a := door_axis()
	return a * (half() - 0.75) + Vector3.UP * WrestlerController.FLOOR_LEVEL


func _door_outside() -> Vector3:
	var a := door_axis()
	var p := a * (half() + 0.95)
	p.y = ArenaBuilder.match_surface_y(p)
	return p


func in_door_lane_inside(p: Vector3) -> bool:
	var a := door_axis()
	var lat := Vector3(absf(a.z), 0.0, absf(a.x))
	return absf(p.dot(lat)) <= cage.spec.door_width * 0.5 + 0.2 \
			and p.dot(a) > half() - 1.5 and p.dot(a) < half()


func in_door_lane_outside(p: Vector3) -> bool:
	var a := door_axis()
	var lat := Vector3(absf(a.z), 0.0, absf(a.x))
	return absf(p.dot(lat)) <= cage.spec.door_width * 0.5 + 0.2 \
			and p.dot(a) > half() and p.dot(a) < half() + 1.8


## Outside the front wall, off the door, close enough to climb it.
func at_climbable_wall(p: Vector3) -> bool:
	var a := door_axis()
	var lat := Vector3(absf(a.z), 0.0, absf(a.x))
	var along := p.dot(lat)
	var out := p.dot(a)
	# Off the door, and on the ramp side, where the barricade is not in the
	# way (ArenaBuilder.RAMP_BARRICADE_OFFSET).
	return out > half() and out < half() + 1.1 \
			and absf(along) > cage.spec.door_width * 0.5 + 0.2 \
			and absf(along) < ArenaBuilder.RAMP_BARRICADE_OFFSET - 0.4


## On the roof over the front wall, close enough to its edge to go down it.
func at_roof_front_edge(p: Vector3) -> bool:
	var a := door_axis()
	var lat := Vector3(absf(a.z), 0.0, absf(a.x))
	return p.dot(a) > half() - 1.1 \
			and absf(p.dot(lat)) < ArenaBuilder.RAMP_BARRICADE_OFFSET - 0.4 \
			and absf(p.dot(lat)) > cage.spec.door_width * 0.5 + 0.2


func lock_door() -> void:
	door_locked = true
	door_forced = false
	cage.set_door_open(0.0)
	cage.set_padlock(true)


func _holds_cutters(w: WrestlerController) -> bool:
	return w.has_weapon() and w.held_weapon.def.id == &"wire_cutters"


## Which side of the cell's walls each man is on the floor: inside, unless
## he went out through the door, down off the roof or over its edge.
var _outside := {}
const DOOR_PASSED := 0.45


func is_outside_cell(w: WrestlerController) -> bool:
	return bool(_outside.get(w, false))


func set_outside_cell(w: WrestlerController, out: bool) -> void:
	_outside[w] = out


## Holds `p` (a man on the floor) on his side of the walls.
func keep_cell_side(w: WrestlerController, p: Vector3) -> Vector3:
	if not cage.is_lowered():
		return p     # still hanging over the ring: nothing to keep him off
	# Through the open door (its collision is a real opening now): whichever
	# side of the wall he steps onto is his side.
	if cage.door_open_amount() > 0.6 and cage.in_door_lane(p, -WrestlerController.BODY_RADIUS):
		# Only once he is clearly through: standing in the doorway he stays
		# on the side he came from (flipping there sent the other man back
		# and forth through it after him -- flow_probe seed 1, 11 Nov).
		var past := p.dot(cage.spec.door_axis) - half()
		if past > DOOR_PASSED:
			_outside[w] = true
		elif past < -DOOR_PASSED:
			_outside[w] = false
		return p
	var r := WrestlerController.BODY_RADIUS + 0.05
	if is_outside_cell(w):
		# His capsule clear of the walls -- round the corner posts, not
		# square: past a corner the barricade's chamfer leaves him a metre,
		# and a square keep-out would wedge him between the two.
		var h := half()
		var near := Vector3(clampf(p.x, -h, h), p.y, clampf(p.z, -h, h))
		var off := Vector3(p.x - near.x, 0.0, p.z - near.z)
		if absf(p.x) < h and absf(p.z) < h:
			if absf(p.x) > absf(p.z):
				p.x = signf(p.x) * (h + r)
			else:
				p.z = signf(p.z if p.z != 0.0 else 1.0) * (h + r)
		elif off.length() < r:
			var corner_r := r if (absf(off.x) < 0.001 or absf(off.z) < 0.001) \
					else WrestlerController.BODY_RADIUS + 0.02
			if off.length() < corner_r:
				var n := off.normalized() if off.length() > 0.0001 else Vector3(signf(p.x), 0, 0)
				p.x = near.x + n.x * corner_r
				p.z = near.z + n.z * corner_r
		return p
	var keep := half() - r
	p.x = clampf(p.x, -keep, keep)
	p.z = clampf(p.z, -keep, keep)
	return p


func busy(w: WrestlerController) -> bool:
	return _routes.has(w)


## Starts whichever route `w` stands at: the door (either way), up the wall,
## or down off the roof. False if there is none from where he is.
func begin(w: WrestlerController) -> bool:
	if busy(w) or not cage.is_lowered():
		return false
	var p := w.global_position
	var r := {}
	if w.on_roof:
		if not at_roof_front_edge(p):
			return false
		r = {"kind": "down", "phase": 0, "t": 0, "from": p}
	elif not w.outside_ring:
		return false
	elif in_door_lane_inside(p):
		r = {"kind": "door_out", "phase": 0 if door_forced else 1, "t": 0, "from": p}
	elif in_door_lane_outside(p):
		r = {"kind": "door_in", "phase": 0 if door_forced else 1, "t": 0, "from": p}
	elif at_climbable_wall(p):
		r = {"kind": "up", "phase": 0, "t": 0, "from": p}
		climbs += 1
	else:
		return false
	# The door: padlocked, it needs the cutters (phase 0 cuts the chain);
	# open, straight through.
	if r["kind"] in ["door_out", "door_in"]:
		if door_locked and not _holds_cutters(w):
			return false
		r["phase"] = 1 if not door_locked else 0
	_routes[w] = r
	w.begin_cell_route(_clip_for(r))
	return true


func _clip_for(r: Dictionary) -> String:
	match r["kind"]:
		"door_out", "door_in":
			return "strikes/weapon_set_up" if int(r["phase"]) == 0 else "strikes/walk_crowd"
		"up":
			return "strikes/ladder_climb" if int(r["phase"]) == 0 else "strikes/apron_climb"
		"down":
			return "strikes/apron_climb" if int(r["phase"]) == 0 else "strikes/ladder_climb"
	return "strikes/idle_ready"


func _wall_point(along: float, y: float, outside: bool) -> Vector3:
	var a := door_axis()
	var lat := Vector3(absf(a.z), 0.0, absf(a.x))
	return lat * along + a * (half() + (WALL_OFF if outside else -0.8)) + Vector3.UP * y


func tick(w: WrestlerController) -> void:
	var r: Dictionary = _routes.get(w, {})
	if r.is_empty():
		w.end_cell_route()
		return
	r["t"] = int(r["t"]) + 1
	var t := int(r["t"])
	var a := door_axis()
	var lat := Vector3(absf(a.z), 0.0, absf(a.x))
	var from: Vector3 = r["from"]
	var along := from.dot(lat)
	match r["kind"]:
		"door_out", "door_in":
			var inside: bool = r["kind"] == "door_out"
			var start := _door_inside() if inside else _door_outside()
			var goal := _door_outside() if inside else _door_inside()
			if int(r["phase"]) == 0:
				# Snipping the chain with the cutters, then the door swings.
				w.face(a if inside else -a)
				w.global_position = w.global_position.lerp(start, 0.15)
				if t == CUT_TICKS - 20:
					cage.rattle(a * half() + Vector3.UP * (cage.spec.base_y + 1.1), 0.4)
				if t >= CUT_TICKS:
					door_locked = false
					door_forced = true
					cage.set_padlock(false)
					door_cut.emit(w)
					_next(w, r)
				return
			var s := clampf(float(t) / DOOR_WALK_TICKS, 0.0, 1.0)
			cage.set_door_open(maxf(cage.door_open_amount(), smoothstep(0.0, 0.4, s)))
			w.global_position = start.lerp(goal, s)
			w.face(a if inside else -a)
			if t >= DOOR_WALK_TICKS:
				_finish(w, false)
		"up":
			var foot := _wall_point(along, ArenaBuilder.match_surface_y(_wall_point(along, 0.0, true)), true)
			var high := _wall_point(along, top_y() - OVER_FROM, true)
			var roof_at := _wall_point(along, surface_y(), false)
			w.face(-a)
			if int(r["phase"]) == 0:
				w.global_position = foot.lerp(high, clampf(float(t) / CLIMB_TICKS, 0.0, 1.0))
				if t >= CLIMB_TICKS:
					_next(w, r)
				return
			var s := clampf(float(t) / OVER_TICKS, 0.0, 1.0)
			# Up and over the top rail: rise to it, then in over it.
			var top := Vector3(high.x, surface_y() + 0.35, high.z).lerp(roof_at, 0.25)
			w.global_position = high.lerp(top, smoothstep(0.0, 1.0, s * 2.0)) if s < 0.5 \
					else top.lerp(roof_at, smoothstep(0.0, 1.0, (s - 0.5) * 2.0))
			if t >= OVER_TICKS:
				_finish(w, true)
		"down":
			var roof_at := _wall_point(along, surface_y(), false)
			var high := _wall_point(along, top_y() - OVER_FROM, true)
			var foot := _wall_point(along, ArenaBuilder.match_surface_y(_wall_point(along, 0.0, true)), true)
			w.face(-a)
			if int(r["phase"]) == 0:
				var s := clampf(float(t) / OVER_BACK_TICKS, 0.0, 1.0)
				var top := Vector3(high.x, surface_y() + 0.35, high.z).lerp(roof_at, 0.25)
				w.global_position = from.lerp(top, smoothstep(0.0, 1.0, s * 2.0)) if s < 0.5 \
						else top.lerp(high, smoothstep(0.0, 1.0, (s - 0.5) * 2.0))
				if t >= OVER_BACK_TICKS:
					w.on_roof = false
					_next(w, r)
				return
			w.global_position = high.lerp(foot, clampf(float(t) / DESCEND_TICKS, 0.0, 1.0))
			if t >= DESCEND_TICKS:
				_finish(w, false)


func _next(w: WrestlerController, r: Dictionary) -> void:
	r["phase"] = int(r["phase"]) + 1
	r["t"] = 0
	w.cell_route_clip(_clip_for(r))


func _finish(w: WrestlerController, onto_roof: bool) -> void:
	var r: Dictionary = _routes.get(w, {})
	match r.get("kind", ""):
		"door_out", "down":
			_outside[w] = true
		"door_in":
			_outside[w] = false
	_routes.erase(w)
	w.on_roof = onto_roof
	w.outside_ring = true
	w.end_cell_route()


## Knocked off the wall or the edge of the roof on the way: the route is over.
func abandon(w: WrestlerController) -> void:
	_routes.erase(w)


## How high up the outside of the wall he is now, metres off the floor; 0 off it.
func height_on_wall(w: WrestlerController) -> float:
	if not busy(w):
		return 0.0
	return w.global_position.y - WrestlerController.FLOOR_LEVEL


# --- the roof -----------------------------------------------------------------

## Kept on it: in from the edge, at its height -- unless a panel under him has
## given way. Returns whether he walked into the edge (a teeter).
func keep_on(w: WrestlerController) -> bool:
	var p := w.global_position
	var bay := cage.bay_of(p)
	if broken.has(bay):
		return false
	var keep := half() - EDGE_KEEP
	var at_edge := absf(p.x) > keep or absf(p.z) > keep
	p.x = clampf(p.x, -keep, keep)
	p.z = clampf(p.z, -keep, keep)
	var floor_y := surface_y() - sag(bay)
	if p.y < floor_y:
		p.y = floor_y
		if w.velocity.y < 0.0:
			w.velocity.y = 0.0
	w.global_position = p
	return at_edge


func sag(bay: Vector2i) -> float:
	return minf(float(damage.get(bay, 0.0)), PANEL_BREAKS) * SAG_PER_DENT


## A blow landing on him up here: whether it sends him over the edge. Hard
## blows (a signature and up, or anything that puts him down when he is
## spent) near the edge, struck toward it.
func knocked_off(w: WrestlerController, tier: int, from: Vector3, knockdown: bool) -> bool:
	var p := w.global_position
	var gap := edge_gap(p)
	if gap > EDGE_DANGER:
		return false
	var out := edge_out(p)
	var push := Vector3(p.x - from.x, 0.0, p.z - from.z)
	var toward_edge := push.length() < 0.05 or push.normalized().dot(out) > 0.2
	var spent := w.combat != null and w.combat.health() < SPENT_SHARE
	if not toward_edge:
		return false
	if tier >= CombatSystem.Tier.SIGNATURE or (knockdown and (spent or gap < 0.55)):
		go_over(w, out)
		return true
	return false


## Over the edge: thrown out from it, falling to whatever is below.
func go_over(w: WrestlerController, out: Vector3) -> void:
	falls += 1
	var end := absf(out.dot(door_axis())) > 0.5
	var speed := FALL_OUT_END if end else FALL_OUT_SIDE
	# Over the announce desk's side, out to the desk.
	if out.z > 0.5 and absf(w.global_position.x) < ArenaBuilder.DESK_LENGTH * 0.5:
		speed = (ArenaBuilder.DESK_Z - half()) / 1.05
	w.begin_roof_fall(out * speed + Vector3.UP * FALL_UP, false)
	fell_off.emit(w, false)


## A man put down on the roof (WrestlerController._go_down): a centre panel
## under him is dented; one that gives way drops him through into the ring.
## Returns whether it did.
func landed(w: WrestlerController, tier: int) -> bool:
	var bay := cage.bay_of(w.global_position)
	if bay.x < 0 or broken.has(bay) or not cage.is_centre_bay(bay):
		return false
	var dent := DENT_FINISHER if tier >= CombatSystem.Tier.FINISHER \
			else (DENT_SIGNATURE if tier >= CombatSystem.Tier.SIGNATURE \
			else (DENT_POWER if tier >= CombatSystem.Tier.POWER else 0.0))
	if dent <= 0.0:
		return false
	damage[bay] = float(damage.get(bay, 0.0)) + dent
	cage.rattle(cage.bay_centre(bay.x, bay.y), 1.0)
	_show_sag(bay)
	if float(damage[bay]) < PANEL_BREAKS:
		return false
	_break(bay)
	w.begin_roof_fall(Vector3.DOWN * 0.5, true)
	fell_off.emit(w, true)
	return true


func _show_sag(bay: Vector2i) -> void:
	var panel := cage.roof_panel(bay)
	if panel:
		var c := cage.bay_centre(bay.x, bay.y)
		panel.position = c + Vector3.DOWN * sag(bay)
		# Dented: the middle lower than the edges reads as a tilt this cheap.
		panel.rotation.x = sag(bay) * 0.25
	var shape := cage.roof_shape(bay)
	if shape:
		shape.position = cage.bay_centre(bay.x, bay.y) + Vector3.DOWN * sag(bay)


func is_broken(bay: Vector2i) -> bool:
	return broken.has(bay)


func _break(bay: Vector2i) -> void:
	broken[bay] = true
	_breaking[bay] = 0
	var shape := cage.roof_shape(bay)
	if shape:
		shape.disabled = true
	panel_broke.emit(bay)


func _physics_process(_delta: float) -> void:
	for w: WrestlerController in _routes.keys():
		if not is_instance_valid(w):
			_routes.erase(w)
	# A panel that gave way swings down on the edge still holding it.
	for bay: Vector2i in _breaking.keys():
		var t := int(_breaking[bay]) + 1
		_breaking[bay] = t
		var panel := cage.roof_panel(bay)
		if panel == null:
			_breaking.erase(bay)
			continue
		var c := cage.bay_centre(bay.x, bay.y)
		var b := cage.bay_size() * 0.5
		var ang := minf(1.0, float(t) / 18.0)
		ang = ang * ang * deg_to_rad(110.0)
		# Hinged on its -X edge: the panel's centre swings round that edge.
		var hinge := c + Vector3(-b, 0.0, 0.0)
		panel.rotation = Vector3(0.0, 0.0, -ang)
		panel.position = hinge + Vector3(cos(ang) * b, -sin(ang) * b, 0.0)
		if t >= 18:
			_breaking.erase(bay)
