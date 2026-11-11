class_name CageBuilder
extends Node3D
## The steel cage, modelled in code the way the ring's posts, ropes and
## turnbuckles are (RingBuilder): a dark steel frame -- posts, rails, the door's
## jambs -- with chain-link mesh panels between, a door that swings outward,
## and thin collision walls. One builder for every caged match: the Steel Cage
## stands on the apron edge around the ring (Spec.steel_cage()); Hell in a
## Cell is the same parts from a bigger spec. The escape that goes up, over
## and out of it is CageEscape. Research and numbers:
## gauntlet/refs/steel_cage.md.
##
## An original design: no downloaded asset, no branding. Deterministic -- no
## RNG anywhere, and the mesh texture is a fixed formula.
##
## Gameplay reads only its geometry (Spec, the queries below), never the
## nodes, so the frames it draws cannot change what a match does. The door's
## swing and the rattle of a panel a man is thrown into are presentation.

const GROUP := &"cage"

## The cage's shape. Positions are world metres around the ring's centre
## (the ring stands at the origin, the canvas at y = 0).
class Spec:
	extends RefCounted
	## Its walls stand this far out from the centre, on X and on Z.
	var half := 3.26
	## The walls' foot (the apron's top for the Steel Cage) and their top.
	var base_y := -0.12
	var top_y := 4.0
	## Rails across each wall, as fractions of its height (0 foot, 1 top).
	var rails: Array[float] = [0.0, 0.36, 0.70, 1.0]
	## Upright posts per wall between the corners (each wall is cut into
	## bays by them).
	var bays := 3
	## The door: in the wall facing `door_axis`, centred, this wide and tall.
	var door_axis := Vector3(-1.0, 0.0, 0.0)
	var door_width := 1.1
	var door_height := 2.05
	## A roof over the whole of it (Hell in a Cell).
	var roof := false
	## The frame's members, as a multiple of the Steel Cage's tubes: Hell in
	## a Cell is built of box truss, several times as deep.
	var frame_scale := 1.0

	## The owner's reference (a cage from below): four panels across each
	## wall, two rows, and a lip of ladder truss round the top.
	static func steel_cage() -> Spec:
		var s := Spec.new()
		s.rails = [0.0, 0.5, 1.0]
		s.bays = 4
		return s

	## Hell in a Cell (gauntlet/refs/hell_in_a_cell.md): a roofed cell on the
	## arena floor round the ring and the ringside mats, inside the barricade,
	## about twenty feet tall, its door on the entrance side.
	static func hell_in_a_cell() -> Spec:
		var s := Spec.new()
		# In from the barricade (6.0) far enough that a man knocked off the
		# roof's side lands in the gap, not inside the wall.
		s.half = 4.7
		s.base_y = ArenaBuilder.FLOOR_Y
		s.top_y = ArenaBuilder.FLOOR_Y + 6.1
		# The owner's references (Hell in a Cell from the hard camera, the
		# roof from the stands): three rows of panels up each wall, four
		# across, and a four-by-four roof whose middle four are the ones that
		# give way.
		s.rails = [0.0, 0.33, 0.66, 1.0]
		s.bays = 4
		s.door_axis = Vector3(0.0, 0.0, -1.0)
		s.door_width = 1.4
		s.door_height = 2.3
		s.roof = true
		s.frame_scale = 2.4
		return s

	## The spec for a caged match type (MatchRules.Mode).
	static func for_mode(mode: int) -> Spec:
		if mode == MatchRules.Mode.HELL_IN_A_CELL:
			return hell_in_a_cell()
		return steel_cage()


## The frame's tube sizes.
const POST_SIZE := 0.10
const RAIL_SIZE := 0.065
const JAMB_SIZE := 0.075
## The chain link: one texture tile covers this many metres of panel, and
## holds MESH_CELLS diamonds each way.
const MESH_TILE_M := 0.5
const MESH_CELLS := 8
const MESH_TEXTURE_SIZE := 256
## The wire, as a fraction of a cell, and the colours (galvanised wire on a
## dark painted frame).
const WIRE_WIDTH := 0.24
## Galvanised steel, frame and wire alike (the owner, 11 Nov: "should not be
## black. They should be a steel colour", with Hell in a Cell and Steel Cage
## references): a light, bright zinc grey that reads silver under the arena
## lights. Not too metallic: a fully metallic surface takes its colour from
## what it reflects, and in a dark arena that is black.
const WIRE_COLOR := Color(0.84, 0.86, 0.88)
const FRAME_COLOR := Color(0.74, 0.76, 0.79)
## The door swings this far open (radians) when fully open.
const DOOR_OPEN_ANGLE := deg_to_rad(105.0)
## A panel a man is driven into shakes this far, and settles this fast.
const RATTLE_AMPLITUDE := 0.035
const RATTLE_DECAY := 6.0
const RATTLE_HZ := 11.0

var spec: Spec = Spec.steel_cage()
var _door_pivot: Node3D
var _door_open := 0.0
## The four walls' visual roots, by the outward axis they face.
var _walls := {}
var _rattle := {}
var _clock := 0.0
static var _mesh_texture: ImageTexture


## Builds it under `parent` from `with` (a Spec), and returns it.
static func build(parent: Node, with: Spec = null) -> CageBuilder:
	var cage := CageBuilder.new()
	cage.name = "Cage"
	if with:
		cage.spec = with
	parent.add_child(cage)
	return cage


## The cage in the scene `node` is in, or null.
static func of(node: Node) -> CageBuilder:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as CageBuilder


func _ready() -> void:
	add_to_group(GROUP)
	_build()


# --------------------------------------------------------------------------
# Queries (gameplay reads these)

static func axes() -> Array[Vector3]:
	return [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]


## The wall nearest `p`, as its outward unit axis.
static func wall_axis(p: Vector3) -> Vector3:
	if absf(p.x) >= absf(p.z):
		return Vector3(signf(p.x) if p.x != 0.0 else 1.0, 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(p.z))


## The axis along a wall (left to right as you face out of it).
static func lateral_of(axis: Vector3) -> Vector3:
	return Vector3(absf(axis.z), 0.0, absf(axis.x))


## Whether `p` stands in front of the door, inside (within `margin` of its
## jambs, along the wall).
func in_door_lane(p: Vector3, margin := 0.0) -> bool:
	if wall_axis(p) != spec.door_axis:
		return false
	var along := p.dot(lateral_of(spec.door_axis))
	return absf(along) <= spec.door_width * 0.5 + margin


## Where the door is: its centre on the wall, at the foot.
func door_centre() -> Vector3:
	return spec.door_axis * spec.half + Vector3.UP * spec.base_y


## Whether `p` is outside the walls.
func is_outside(p: Vector3) -> bool:
	return absf(p.x) > spec.half or absf(p.z) > spec.half


func door_open_amount() -> float:
	return _door_open


# --------------------------------------------------------------------------
# Presentation

## Hell in a Cell's door, padlocked shut by the referee once both men are in:
## a loop of heavy chain through the door frame and the jamb, and a padlock on
## it. Off when the chain is cut (CellRoof): the lock and chain fall to the
## floor in front of the door.
var _padlock: Node3D


func set_padlock(on: bool) -> void:
	if not on:
		if _padlock:
			_padlock.queue_free()
			_padlock = null
		return
	if _padlock or _door_pivot == null:
		return
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.56, 0.58)
	steel.metallic = 0.8
	steel.roughness = 0.35
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.6, 0.28)
	brass.metallic = 0.9
	brass.roughness = 0.3
	_padlock = Node3D.new()
	_padlock.name = "Padlock"
	add_child(_padlock)
	var axis := spec.door_axis
	var lat := lateral_of(axis)
	var latch := axis * (spec.half + 0.06) + lat * (spec.door_width * 0.5) \
			+ Vector3.UP * (spec.base_y + 1.05)
	# The chain: links wound round the door's edge and the jamb.
	for k in 9:
		var a := TAU * float(k) / 9.0
		var link := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.012
		torus.outer_radius = 0.026
		link.mesh = torus
		link.material_override = steel
		link.position = latch + lat * (cos(a) * 0.09) + Vector3.UP * (sin(a) * 0.11)
		link.rotation = Vector3(PI * 0.5 * float(k % 2), a, 0.0)
		_padlock.add_child(link)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.08, 0.035)
	body.mesh = bm
	body.material_override = brass
	body.position = latch + Vector3.DOWN * 0.15 + axis * 0.02
	_padlock.add_child(body)
	var shackle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.022
	ring.outer_radius = 0.03
	shackle.mesh = ring
	shackle.material_override = steel
	shackle.position = latch + Vector3.DOWN * 0.1 + axis * 0.02
	shackle.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_padlock.add_child(shackle)


func has_padlock() -> bool:
	return _padlock != null


## Opens the door to `t` (0 shut, 1 wide open).
func set_door_open(t: float) -> void:
	_door_open = clampf(t, 0.0, 1.0)
	if _door_pivot:
		# Hinged on the -lateral jamb, swinging out.
		var swing := _door_open * DOOR_OPEN_ANGLE
		_door_pivot.rotation.y = _door_hinge_sign() * swing


# --------------------------------------------------------------------------
# The hoist (Hell in a Cell): up in the rafters for the entrances, lowered on
# its four chains once both men are in the ring (the owner, 11 Nov: "the cell
# should lower after the entrances"). Presentation only -- gameplay reads the
# Spec, and CellRoof ignores the walls until the cell is down.

signal landed
## Raised: the foot of its walls clear above the ring truss (ArenaBuilder.
## TRUSS_Y 9.2, fixtures to 8.5), so no entrance shot looks through it.
const HOIST_LIFT := 10.6
## Its chains run up to the roof steel.
const CHAIN_TOP_Y := ArenaBuilder.ROOF_Y
const CHAIN_RADIUS := 0.035
var lift := 0.0
var _chains: Array[MeshInstance3D] = []
var _lowering_from := 0.0
var _lowering_ticks := 0
var _lowering_t := -1


func is_lowered() -> bool:
	return lift <= 0.0005 and _lowering_t < 0


## Hangs it `h` metres above where it stands, chains showing while it hangs.
func set_lift(h: float) -> void:
	lift = maxf(h, 0.0)
	position.y = lift
	if lift > 0.0 and _chains.is_empty():
		_build_chains()
	for c in _chains:
		c.visible = lift > 0.0005
		if c.visible:
			var length := CHAIN_TOP_Y - (spec.top_y + lift)
			(c.mesh as CylinderMesh).height = maxf(length, 0.01)
			c.position.y = spec.top_y + length * 0.5


## Brings it down over `seconds`, eased in and out (a hoist starts and stops
## gently), then `landed`.
func lower(seconds: float) -> void:
	_lowering_from = lift
	_lowering_ticks = maxi(1, int(round(seconds * Engine.physics_ticks_per_second)))
	_lowering_t = 0


## Where the descent is, 0..1 (1 once down).
func lowering_progress() -> float:
	if _lowering_t < 0:
		return 1.0 if lift <= 0.0005 else 0.0
	return float(_lowering_t) / float(_lowering_ticks)


func _physics_process(_delta: float) -> void:
	if _lowering_t < 0:
		return
	_lowering_t += 1
	var e := smoothstep(0.0, 1.0, float(_lowering_t) / float(_lowering_ticks))
	set_lift(_lowering_from * (1.0 - e))
	if _lowering_t >= _lowering_ticks:
		_lowering_t = -1
		set_lift(0.0)
		for axis: Vector3 in axes():
			rattle(axis * spec.half + Vector3.UP * spec.base_y, 1.6)
		landed.emit()


## Down at once (the entrances skipped).
func land_now() -> void:
	if is_lowered():
		return
	_lowering_t = -1
	set_lift(0.0)
	landed.emit()


func _build_chains() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.33, 0.35)
	mat.metallic = 0.7
	mat.roughness = 0.4
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			mi.name = "HoistChain"
			var m := CylinderMesh.new()
			m.top_radius = CHAIN_RADIUS
			m.bottom_radius = CHAIN_RADIUS
			m.radial_segments = 8
			m.rings = 1
			mi.mesh = m
			mi.material_override = mat
			mi.position = Vector3(sx * spec.half, spec.top_y, sz * spec.half)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_chains.append(mi)


## A man driven into the steel at `at`: the panel he hit shakes and settles.
func rattle(at: Vector3, strength := 1.0) -> void:
	var axis := wall_axis(at)
	_rattle[axis] = maxf(float(_rattle.get(axis, 0.0)), clampf(strength, 0.0, 2.0))


func _process(delta: float) -> void:
	_clock += delta
	for axis: Vector3 in _rattle.keys():
		var amount: float = _rattle[axis]
		var wall: Node3D = _walls.get(axis)
		if wall == null:
			continue
		amount = maxf(0.0, amount - amount * RATTLE_DECAY * delta - delta * 0.05)
		_rattle[axis] = amount
		wall.position = axis * sin(_clock * TAU * RATTLE_HZ) * RATTLE_AMPLITUDE * amount
		if amount <= 0.0:
			wall.position = Vector3.ZERO
			_rattle.erase(axis)


# --------------------------------------------------------------------------
# The model

func _build() -> void:
	var frame := _frame_material()
	var wire := _mesh_material()
	for axis: Vector3 in axes():
		var wall := Node3D.new()
		wall.name = "Wall_%s" % _axis_name(axis)
		add_child(wall)
		_walls[axis] = wall
		_build_wall(wall, axis, frame, wire)
	_build_posts(frame)
	if spec.roof:
		_build_roof(frame, wire)
	else:
		_build_top_lip(frame, wire)
	_build_collision()


## The Steel Cage's top: a flat lip of ladder truss, LIP_WIDTH deep, running
## in from the top rail all the way round -- a second rail inside the first,
## rungs across between them, chain link on it -- as the reference's cage
## has it seen from below.
const LIP_WIDTH := 0.32
const LIP_RUNG_EVERY := 0.42


func _build_top_lip(frame: Material, wire: Material) -> void:
	var y := spec.top_y
	var r := RAIL_SIZE * spec.frame_scale
	var inner := spec.half - LIP_WIDTH
	for axis: Vector3 in axes():
		var lat := lateral_of(axis)
		# The inner rail.
		_box(self, axis * inner + Vector3.UP * y, _size_along(lat, inner * 2.0, r), frame)
		# Rungs from the top rail in to it.
		var n := int(floor(spec.half * 2.0 / LIP_RUNG_EVERY))
		for k in range(1, n):
			var along := -spec.half + spec.half * 2.0 * float(k) / float(n)
			if absf(along) > inner:
				continue
			var at := axis * (spec.half - LIP_WIDTH * 0.5) + lat * along + Vector3.UP * y
			_box(self, at, axis.abs() * LIP_WIDTH + lat.abs() * r * 0.7 + Vector3.UP * r * 0.7, frame)
		# The chain link across the lip.
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(1, 1)
		mi.mesh = plane
		mi.material_override = wire
		mi.position = axis * (spec.half - LIP_WIDTH * 0.5) + Vector3.UP * (y - 0.005)
		mi.scale = axis.abs() * LIP_WIDTH + lat.abs() * inner * 2.0 + Vector3.UP
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _axis_name(axis: Vector3) -> String:
	if axis.x > 0.5:
		return "PX"
	if axis.x < -0.5:
		return "NX"
	return "PZ" if axis.z > 0.5 else "NZ"


func _height() -> float:
	return spec.top_y - spec.base_y


## One wall: its rails, its intermediate posts, and its mesh, bay by bay; the
## door wall leaves the doorway open and hangs the door in it.
func _build_wall(wall: Node3D, axis: Vector3, frame: Material, wire: Material) -> void:
	var lat := lateral_of(axis)
	var span := spec.half * 2.0
	var h := _height()
	var is_door := axis == spec.door_axis
	var door_l := -spec.door_width * 0.5
	var door_r := spec.door_width * 0.5
	var door_top := spec.base_y + spec.door_height
	# Rails, full length; on the door wall, cut where they cross the doorway.
	for f: float in spec.rails:
		var y := spec.base_y + f * h
		if is_door and y < door_top - 0.01 and f > 0.0:
			_rail(wall, axis, lat, -spec.half, door_l, y, frame)
			_rail(wall, axis, lat, door_r, spec.half, y, frame)
		elif is_door and f == 0.0:
			_rail(wall, axis, lat, -spec.half, door_l, y, frame)
			_rail(wall, axis, lat, door_r, spec.half, y, frame)
		else:
			_rail(wall, axis, lat, -spec.half, spec.half, y, frame)
	# Intermediate posts between bays.
	for i in range(1, spec.bays):
		var s := -spec.half + span * float(i) / float(spec.bays)
		if is_door and s > door_l - 0.15 and s < door_r + 0.15:
			continue
		_post(wall, axis * spec.half + lat * s, (POST_SIZE * spec.frame_scale) * 0.8, frame)
	# The mesh: the wall's whole face, less the doorway.
	if is_door:
		_panel(wall, axis, lat, -spec.half, door_l, spec.base_y, spec.top_y, wire)
		_panel(wall, axis, lat, door_r, spec.half, spec.base_y, spec.top_y, wire)
		_panel(wall, axis, lat, door_l, door_r, door_top, spec.top_y, wire)
		_build_door(wall, axis, lat, frame, wire)
	else:
		_panel(wall, axis, lat, -spec.half, spec.half, spec.base_y, spec.top_y, wire)


func _build_posts(frame: Material) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_post(self, Vector3(sx * spec.half, 0.0, sz * spec.half), (POST_SIZE * spec.frame_scale), frame)


func _door_hinge_sign() -> float:
	# Swing out of the cage, about the hinge on the wall's -lateral jamb.
	var lat := lateral_of(spec.door_axis)
	var out := spec.door_axis
	# Rotating +angle about Y turns lateral toward... pick the sign that moves
	# the leaf's free end outward.
	var probe := lat.rotated(Vector3.UP, 0.3)
	return 1.0 if probe.dot(out) > 0.0 else -1.0


func _build_door(wall: Node3D, axis: Vector3, lat: Vector3, frame: Material,
		wire: Material) -> void:
	var l := -spec.door_width * 0.5
	var r := spec.door_width * 0.5
	var top := spec.base_y + spec.door_height
	# The jambs and the header, fixed to the wall.
	_post_span(wall, axis * spec.half + lat * l, spec.base_y, spec.top_y, (JAMB_SIZE * spec.frame_scale), frame)
	_post_span(wall, axis * spec.half + lat * r, spec.base_y, spec.top_y, (JAMB_SIZE * spec.frame_scale), frame)
	_rail(wall, axis, lat, l, r, top, frame)
	# The leaf, on a pivot at the hinge jamb.
	_door_pivot = Node3D.new()
	_door_pivot.name = "DoorPivot"
	_door_pivot.position = axis * spec.half + lat * l
	wall.add_child(_door_pivot)
	var leaf_w := spec.door_width - (JAMB_SIZE * spec.frame_scale)
	var inset := (JAMB_SIZE * spec.frame_scale) * 0.5
	for y: float in [spec.base_y + 0.06, spec.base_y + spec.door_height * 0.5, top - 0.06]:
		_box(_door_pivot, Vector3(0, y, 0) + lat * (inset + leaf_w * 0.5),
				_size_along(lat, leaf_w, (RAIL_SIZE * spec.frame_scale) * 0.8), frame)
	_box(_door_pivot, Vector3(0, (spec.base_y + top) * 0.5, 0) + lat * (inset + 0.02),
			Vector3((RAIL_SIZE * spec.frame_scale) * 0.8, top - spec.base_y, (RAIL_SIZE * spec.frame_scale) * 0.8), frame)
	_box(_door_pivot, Vector3(0, (spec.base_y + top) * 0.5, 0) + lat * (inset + leaf_w - 0.02),
			Vector3((RAIL_SIZE * spec.frame_scale) * 0.8, top - spec.base_y, (RAIL_SIZE * spec.frame_scale) * 0.8), frame)
	# Its mesh, in the pivot's frame (the wall's plane passes through it).
	var quad := _quad_mesh(lat, inset, inset + leaf_w, spec.base_y, top, 0.0)
	var mi := MeshInstance3D.new()
	mi.name = "DoorMesh"
	mi.mesh = quad
	mi.material_override = wire
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_door_pivot.add_child(mi)
	# The latch on the free side: a short bar and a padlock-sized block.
	_box(_door_pivot, Vector3(0, spec.base_y + 1.05, 0) + lat * (inset + leaf_w - 0.08)
			+ axis * 0.05, Vector3(0.06, 0.12, 0.06), frame)


func _build_roof(frame: Material, wire: Material) -> void:
	var y := spec.top_y
	var span := spec.half * 2.0
	for i in range(0, spec.bays + 1):
		var s := -spec.half + span * float(i) / float(spec.bays)
		_box(self, Vector3(s, y, 0), Vector3((RAIL_SIZE * spec.frame_scale), (RAIL_SIZE * spec.frame_scale), span), frame)
		_box(self, Vector3(0, y, s), Vector3(span, (RAIL_SIZE * spec.frame_scale), (RAIL_SIZE * spec.frame_scale)), frame)
	# One chain-link panel a bay, each its own node, so a bay can be dented
	# and give way under a man (CellRoof): the four in the middle do.
	var bay := span / float(spec.bays)
	for i in spec.bays:
		for j in spec.bays:
			var centre := bay_centre(i, j)
			var mesh := ArrayMesh.new()
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var b := bay * 0.5
			var corners := [Vector3(-b, 0, -b), Vector3(b, 0, -b), Vector3(b, 0, b), Vector3(-b, 0, b)]
			for idx: int in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = corners[idx]
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(p.x + centre.x, p.z + centre.z) / MESH_TILE_M)
				st.add_vertex(p)
			st.commit(mesh)
			var mi := MeshInstance3D.new()
			mi.name = "RoofPanel_%d_%d" % [i, j]
			mi.mesh = mesh
			mi.material_override = wire
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = centre
			add_child(mi)
			_roof_panels[Vector2i(i, j)] = mi


## The roof's bays: their centre at the top (i along X, j along Z).
func bay_centre(i: int, j: int) -> Vector3:
	var bay := spec.half * 2.0 / float(spec.bays)
	return Vector3(-spec.half + bay * (i + 0.5), spec.top_y, -spec.half + bay * (j + 0.5))


func bay_size() -> float:
	return spec.half * 2.0 / float(spec.bays)


## The bay over `p`, or (-1, -1) off the roof.
func bay_of(p: Vector3) -> Vector2i:
	var bay := bay_size()
	var i := int(floor((p.x + spec.half) / bay))
	var j := int(floor((p.z + spec.half) / bay))
	if i < 0 or j < 0 or i >= spec.bays or j >= spec.bays:
		return Vector2i(-1, -1)
	return Vector2i(i, j)


## The four in the middle of the roof (an even count of bays a side).
func is_centre_bay(b: Vector2i) -> bool:
	var lo := spec.bays / 2 - 1
	return b.x in [lo, lo + 1] and b.y in [lo, lo + 1]


func roof_panel(b: Vector2i) -> MeshInstance3D:
	return _roof_panels.get(b) as MeshInstance3D


func roof_shape(b: Vector2i) -> CollisionShape3D:
	return _roof_shapes.get(b) as CollisionShape3D


var _roof_panels := {}
var _roof_shapes := {}


## Thin walls of collision on the cage's faces (and its roof): nothing walks
## or is knocked through the steel. The escape is a scripted path that goes
## round them.
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "CageCollision"
	add_child(body)
	var h := _height()
	var span := spec.half * 2.0
	for axis: Vector3 in axes():
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var lat := lateral_of(axis)
		box.size = lat * span + axis.abs() * 0.04 + Vector3.UP * h
		shape.shape = box
		shape.position = axis * spec.half + Vector3.UP * (spec.base_y + h * 0.5)
		body.add_child(shape)
	if spec.roof:
		# A bay of the roof each, so one can give way (CellRoof).
		for i in spec.bays:
			for j in spec.bays:
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(bay_size(), 0.06, bay_size())
				shape.shape = box
				shape.position = bay_centre(i, j)
				shape.name = "RoofShape_%d_%d" % [i, j]
				body.add_child(shape)
				_roof_shapes[Vector2i(i, j)] = shape


# --------------------------------------------------------------------------
# Parts

func _size_along(lat: Vector3, length: float, thickness: float) -> Vector3:
	return Vector3(length if lat.x > 0.5 else thickness, thickness,
			length if lat.z > 0.5 else thickness)


func _rail(parent: Node3D, axis: Vector3, lat: Vector3, from: float, to: float, y: float,
		mat: Material) -> void:
	if to - from < 0.01:
		return
	var centre := axis * spec.half + lat * ((from + to) * 0.5) + Vector3.UP * y
	_box(parent, centre, _size_along(lat, to - from, (RAIL_SIZE * spec.frame_scale)), mat)


func _post(parent: Node3D, at: Vector3, size: float, mat: Material) -> void:
	_post_span(parent, at, spec.base_y, spec.top_y, size, mat)


func _post_span(parent: Node3D, at: Vector3, from_y: float, to_y: float, size: float,
		mat: Material) -> void:
	_box(parent, Vector3(at.x, (from_y + to_y) * 0.5, at.z), Vector3(size, to_y - from_y, size),
			mat)


func _box(parent: Node3D, centre: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = centre
	parent.add_child(mi)
	return mi


## One mesh panel on a wall, from `from` to `to` along it and `y0` to `y1` up
## it, UV'd in metres so the diamonds stay square whatever its size.
func _panel(parent: Node3D, axis: Vector3, lat: Vector3, from: float, to: float, y0: float,
		y1: float, wire: Material) -> void:
	if to - from < 0.01 or y1 - y0 < 0.01:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = _quad_mesh(lat, from, to, y0, y1, 0.0)
	mi.position = axis * spec.half
	mi.material_override = wire
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _quad_mesh(lat: Vector3, from: float, to: float, y0: float, y1: float,
		offset: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3(lat.z, 0.0, lat.x)
	var a := lat * from + Vector3.UP * y0 + n * offset
	var b := lat * to + Vector3.UP * y0 + n * offset
	var c := lat * to + Vector3.UP * y1 + n * offset
	var d := lat * from + Vector3.UP * y1 + n * offset
	var uv := func(p: Vector3) -> Vector2:
		return Vector2(p.dot(lat), -p.y) / MESH_TILE_M
	for p: Vector3 in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.set_uv(uv.call(p))
		st.add_vertex(p)
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	return mesh


# --------------------------------------------------------------------------
# Materials

func _frame_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = FRAME_COLOR
	m.metallic = 0.45
	m.roughness = 0.34
	m.metallic_specular = 0.7
	return m


func _mesh_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = mesh_texture()
	m.albedo_color = Color.WHITE
	m.metallic = 0.3
	m.roughness = 0.36
	m.metallic_specular = 0.7
	# Alpha-blended with mipmaps: up close, wire; at broadcast distance the
	# mipmaps average it into the grey haze a real cage is on television.
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.texture_repeat = true
	return m


## The chain link: MESH_CELLS diamonds each way per tile, wire on clear,
## the wire shaded round (lighter on its crown) so it reads as a cylinder.
## A fixed formula, so every run draws the same texture.
static func mesh_texture() -> ImageTexture:
	if _mesh_texture:
		return _mesh_texture
	var n := MESH_TEXTURE_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var cell := float(n) / float(MESH_CELLS)
	for y in n:
		for x in n:
			# Distance to the nearest wire of each diagonal family.
			var u := fmod((float(x) + float(y)) / cell, 1.0)
			var v := fmod((float(x) - float(y) + float(n) * 4.0) / cell, 1.0)
			var du := absf(u - 0.5) * 2.0       # 1 on a wire's centre line
			var dv := absf(v - 0.5) * 2.0
			var wu := 1.0 - (1.0 - du) / WIRE_WIDTH
			var wv := 1.0 - (1.0 - dv) / WIRE_WIDTH
			var w := maxf(wu, wv)
			if w <= 0.0:
				img.set_pixel(x, y, Color(WIRE_COLOR, 0.0))
				continue
			var crown := 0.75 + 0.25 * sin(clampf(w, 0.0, 1.0) * PI * 0.5)
			var c := WIRE_COLOR * crown
			c.a = clampf(w * 2.2, 0.0, 1.0)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_mesh_texture = ImageTexture.create_from_image(img)
	return _mesh_texture
