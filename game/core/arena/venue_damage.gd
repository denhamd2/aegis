class_name VenueDamage
extends Node3D
## What the rocket launcher does to the building, and it stays done (the
## owner, 19 Oct: "The rocket launcher should cause permanent damage to
## whatever it hits, eg parts of the ring, the LED screens, the barriers,
## announce table ... If rockets land in the crowd or hit the screens, it
## should cause a fire which does not go out").
##
## The pieces a rocket can wreck are registered as boxes (`Target`): every
## barricade panel, the announce desk, the ring's four posts, four apron sides
## and two sets of steps, the three LED walls, and the crowd round the floor.
## A rocket's flight asks `ray()` what it runs into; where it goes off,
## `blast()` damages every piece within BLAST_RADIUS:
##
## * a solid piece -- a panel, the desk, a post, the steps -- has its section
##   CUT out of the merged venue mesh it is part of (the triangles inside its
##   box) and the damaged model from tools/blender/venue_damage.py put in its
##   place. Once: a wrecked panel stays the wreck it became.
## * a skin -- the apron's skirt, an LED wall's face -- is too big a quad to
##   cut, so the damage is laid over it where the rocket went in: a blown
##   hole in the skirt, a patch of smashed tiles with a fire burning in it.
## * the crowd catches fire.
##
## Every blast leaves a scorch mark and, at the floor, rubble. Fires burn till
## the match scene goes: MAX_FIRES of them, and a new one beside a burning one
## feeds it instead. Presentation only -- nothing here touches the simulation
## or the replay's hash.

const MODEL := "res://assets/environment/venue_damage.glb"
const GROUP := &"venue_damage"
## The venue roots the builders put in groups for this to find: the ringside
## model (barricades, desk), the entrance set (the LED walls), and the ring's
## model holder (posts, apron, steps).
const RINGSIDE_GROUP := &"venue_ringside"
const ENTRANCE_GROUP := &"venue_entrance"
const RING_GROUP := &"venue_ring"

## A blast damages every piece whose box comes within this of it.
const BLAST_RADIUS := 1.4
## Every hit's own fire and everything it spreads to.
const MAX_FIRES := 60
const FIRE_MERGE := 2.2
## Overlays (a hole in the apron, a smashed patch of LED wall) nearer than
## this to one already there add to it rather than stack.
const OVERLAY_MERGE := 1.1
## The smashed LED patch (2.24 m as modelled) drawn this much bigger.
const SCREEN_PATCH_SCALE := 1.6
## Scorch marks: how wide, and at most how many before the oldest goes.
const SCORCH_SIZE := 2.6
const MAX_SCORCHES := 40

enum Kind { BARRICADE, DESK, RING_POST, RING_APRON, RING_STEPS, SCREEN }

## Which damaged model each solid kind is replaced by, and which overlay a skin
## takes. (venue_damage.glb's root names.)
const KIND_MODEL := {
	Kind.BARRICADE: "BarricadePanel_Damaged", Kind.DESK: "CommentaryDesk_Damaged",
	Kind.RING_POST: "RingPost_Damaged", Kind.RING_APRON: "RingApron_Damaged",
	Kind.RING_STEPS: "RingSteps_Damaged", Kind.SCREEN: "LedWall_Smashed",
}
const SOLID: Array[int] = [Kind.BARRICADE, Kind.DESK, Kind.RING_POST, Kind.RING_STEPS]

## Ringside parts the barricade and desk boxes cut from. Not the riser or the
## floor: a blast on the desk does not take the carpet with it.
const RINGSIDE_CUT := ["Barricades", "CommentaryDesk", "CommentaryDeskTop", "CommentaryDeskLed",
		"CommentaryScreens", "CommentaryKit"]


class Target:
	var name := ""
	var kind := 0
	## The box, in the world: centre and axes (+Z out of the piece's face).
	var box := Transform3D.IDENTITY
	var half := Vector3.ONE
	## Where its damaged model stands (solid kinds): origin on the floor.
	var place := Transform3D.IDENTITY
	var damaged := false
	var hits := 0
	var overlays: Array[Vector3] = []
	## The video wall is curved, concave to the crowd: its face is this much
	## nearer at the ends than at the middle (ArenaBuilder.SCREEN_SAGITTA),
	## and a rocket finds it by that curve rather than by the box.
	var sagitta := 0.0

	## Where the face is, at `x` across it (box-local), and which way it
	## faces there.
	func face_z(x: float) -> float:
		if sagitta <= 0.0:
			return half.z
		var u := x / half.x
		return half.z + sagitta * (u * u - 1.0)

	func face_normal(x: float) -> Vector3:
		if sagitta <= 0.0:
			return Vector3.BACK
		return Vector3(-2.0 * sagitta * x / (half.x * half.x), 0.0, 1.0).normalized()


## The damage done this match, in order: [kind name, piece, where] (tests,
## probes, the post-match rating).
signal damaged(kind: int, target_name: String, at: Vector3)
signal fire_started(at: Vector3)

var targets: Array = []
var fires: Array[Node3D] = []
var history: Array = []
var _cuttable: Array[MeshInstance3D] = []
var _models: Node3D
var _scorches: Array[Decal] = []
var _ready_targets := false
var _flicker_t := 0.0


## The one in this match, made the first time anything asks.
static func of(node: Node) -> VenueDamage:
	if node == null or not node.is_inside_tree():
		return null
	var existing := node.get_tree().get_first_node_in_group(GROUP)
	if existing:
		return existing as VenueDamage
	var host := node
	while host.get_parent() != null and host.get_node_or_null("WeaponStock") == null \
			and host.get_node_or_null("MatchFlow") == null:
		host = host.get_parent()
	if host.get_parent() == null:
		host = node.get_parent() if node.get_parent() else node
	var d := VenueDamage.new()
	d.name = "VenueDamage"
	host.add_child(d)
	return d


func _enter_tree() -> void:
	add_to_group(GROUP)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_models):
		_models.free()                  # the templates were never in the tree


# --- the pieces ---------------------------------------------------------------

func add_target(target_name: String, kind: int, box: Transform3D, half: Vector3,
		place := Transform3D.IDENTITY) -> Target:
	var t := Target.new()
	t.name = target_name
	t.kind = kind
	t.box = box
	t.half = half
	t.place = place
	targets.append(t)
	return t


func add_cuttable(mi: MeshInstance3D) -> void:
	if mi and not _cuttable.has(mi):
		_cuttable.append(mi)


## Reads the venue the builders grouped -- the first time a rocket flies, so
## it costs nothing in a match where none does.
func ensure_targets() -> void:
	if _ready_targets or not is_inside_tree():
		return
	_ready_targets = true
	var ringside := get_tree().get_first_node_in_group(RINGSIDE_GROUP) as Node3D
	if ringside:
		for part: String in RINGSIDE_CUT:
			add_cuttable(ringside.find_child(part, true, false) as MeshInstance3D)
		_register_barricades()
		_register_desk()
	var entrance := get_tree().get_first_node_in_group(ENTRANCE_GROUP) as Node3D
	if entrance:
		_register_screens(entrance)
	var ring := get_tree().get_first_node_in_group(RING_GROUP) as Node3D
	if ring:
		for mi: MeshInstance3D in ring.find_children("", "MeshInstance3D", true, false):
			if mi.name != "RopeMesh":
				add_cuttable(mi)
		_register_ring(ring)


func _register_barricades() -> void:
	var h := ArenaBuilder.BARRICADE_HEIGHT
	var panels := ArenaBuilder.barricade_panels()
	for i in panels.size():
		var panel: Array = panels[i]
		var at: Vector3 = panel[0]
		var along: Vector3 = panel[1]
		var out: Vector3 = panel[2]
		var width: float = panel[3]
		var basis := Basis(along.normalized(), Vector3.UP, out.normalized())
		# the box reaches out over the brace behind the panel
		var centre := Vector3(at.x, ArenaBuilder.FLOOR_Y + h * 0.5 + 0.02, at.z) + out.normalized() * 0.2
		add_target("Barricade%02d" % i, Kind.BARRICADE, Transform3D(basis, centre),
				Vector3(width * 0.5, h * 0.5 + 0.04, 0.34),
				Transform3D(basis, Vector3(at.x, ArenaBuilder.FLOOR_Y, at.z)))


func _register_desk() -> void:
	var tall := ArenaBuilder.DESK_HEIGHT + 0.5          # the monitors over the worktop
	add_target("CommentaryDesk", Kind.DESK,
			Transform3D(Basis(), Vector3(ArenaBuilder.DESK_X,
					ArenaBuilder.FLOOR_Y + ArenaBuilder.DESK_RISER + tall * 0.5, ArenaBuilder.DESK_Z)),
			Vector3(ArenaBuilder.DESK_LENGTH * 0.5 + 0.12, tall * 0.5,
					ArenaBuilder.DESK_DEPTH * 0.5 + 0.12),
			Transform3D(Basis(), Vector3(ArenaBuilder.DESK_X, ArenaBuilder.FLOOR_Y, ArenaBuilder.DESK_Z)))


func _register_screens(entrance: Node3D) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var y0 := deck + ArenaBuilder.SIDE_SCREEN_BOTTOM
	var y1 := deck + ArenaBuilder.SIDE_SCREEN_TOP
	var z_in := ArenaBuilder.side_screen_inner_z()
	var z_out := ArenaBuilder.side_screen_outer_z()
	for side: float in [-1.0, 1.0]:
		var inner := Vector3(side * ArenaBuilder.SIDE_SCREEN_INNER_X, 0.0, z_in)
		var outer := Vector3(side * ArenaBuilder.SIDE_SCREEN_OUTER_X, 0.0, z_out)
		var along := (outer - inner).normalized()
		var face := Vector3(-along.z, 0.0, along.x) * side          # toward the ring
		if face.z < 0.0:
			face = -face
		var basis := Basis(face.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, face)
		var centre := (inner + outer) * 0.5 + Vector3.UP * (y0 + y1) * 0.5
		add_target("SideScreen%s" % ("L" if side < 0.0 else "R"), Kind.SCREEN,
				Transform3D(basis, centre - face * ArenaBuilder.SIDE_SCREEN_DEPTH * 0.5),
				Vector3((outer - inner).length() * 0.5, (y1 - y0) * 0.5, ArenaBuilder.SIDE_SCREEN_DEPTH * 0.5))
	var screen := entrance.find_child("StageScreen", true, false) as MeshInstance3D
	if screen and screen.mesh:
		var box := screen.global_transform * screen.mesh.get_aabb()
		var c := box.get_center()
		# the box spans the curve's depth; its +Z face is the wall's ends
		var wall := add_target("VideoWall", Kind.SCREEN,
				Transform3D(Basis(), Vector3(c.x, c.y, box.end.z - ArenaBuilder.SCREEN_SAGITTA * 0.5)),
				Vector3(box.size.x * 0.5, box.size.y * 0.5, ArenaBuilder.SCREEN_SAGITTA * 0.5))
		wall.sagitta = ArenaBuilder.SCREEN_SAGITTA


func _register_ring(ring: Node3D) -> void:
	var rx := ring.global_transform
	var post_h := RingBuilder.POST_TOP - RingBuilder.POST_BOTTOM
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var out := Vector3(cx, 0.0, cz).normalized()
			var basis := Basis(Vector3.UP.cross(out), Vector3.UP, out)
			var foot := rx * Vector3(cx * RingBuilder.POST_XZ, RingBuilder.POST_BOTTOM, cz * RingBuilder.POST_XZ)
			# in along the diagonal over the pads, a little out past the post
			add_target("Post%s%s" % ["W" if cx < 0.0 else "E", "N" if cz < 0.0 else "S"], Kind.RING_POST,
					Transform3D(basis, foot + Vector3.UP * post_h * 0.5 - out * 0.22),
					Vector3(0.42, post_h * 0.5, 0.5), Transform3D(basis, foot))
	var skirt_h := RingBuilder.APRON_TOP - RingBuilder.APRON_BOTTOM
	for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var basis := Basis(Vector3.UP.cross(axis), Vector3.UP, axis)
		var c := rx * (axis * RingBuilder.APRON_OUT + Vector3.UP * (RingBuilder.APRON_TOP - skirt_h * 0.5))
		add_target("Apron%s" % _axis_name(axis), Kind.RING_APRON, Transform3D(basis, c - axis * 0.2),
				Vector3(RingBuilder.APRON_OUT, skirt_h * 0.5, 0.25))
	var length := RingBuilder.STEP_PLATFORM + RingBuilder.STEP_RUN * RingBuilder.STEP_TREADS
	var height := RingBuilder.STEP_TOP_Y - RingBuilder.STEP_FLOOR_Y
	for corner: Vector2 in RingBuilder.STEP_CORNERS:
		var out := RingBuilder.step_out_dir(corner)
		var basis := Basis(Vector3.UP.cross(out), Vector3.UP, out)
		var apron_corner := Vector3(corner.x * RingBuilder.APRON_OUT, RingBuilder.STEP_FLOOR_Y,
				corner.y * RingBuilder.APRON_OUT)
		var foot := rx * (apron_corner + out * (length * 0.5 + RingBuilder.STEP_APRON_GAP))
		add_target("Steps%d" % targets.size(), Kind.RING_STEPS,
				Transform3D(basis, foot + Vector3.UP * height * 0.5),
				Vector3(RingBuilder.STEP_WIDTH * 0.5 + 0.06, height * 0.5 + 0.06, length * 0.5 + 0.06),
				Transform3D(basis, foot))


static func _axis_name(axis: Vector3) -> String:
	if axis.x > 0.5:
		return "E"
	if axis.x < -0.5:
		return "W"
	return "S" if axis.z > 0.0 else "N"


# --- what a rocket runs into -----------------------------------------------------

## The first thing on the segment `from` -> `to`: {"point", "normal",
## "target"} (target null for the floor, the ring or the crowd -- "crowd" true
## for the crowd), or {} for nothing.
func ray(from: Vector3, to: Vector3) -> Dictionary:
	ensure_targets()
	var best := {}
	var best_t := INF
	for t: Target in targets:
		if t.sagitta > 0.0:
			continue                    # found by its curve, below
		var hit := _ray_box(t, from, to)
		if not hit.is_empty() and float(hit["t"]) < best_t:
			best_t = float(hit["t"])
			best = hit
			best["target"] = t
	# the floor, the ring, the crowd: walked in short steps
	var length := from.distance_to(to)
	var steps := maxi(1, int(ceil(length / 0.25)))
	for i in range(1, steps + 1):
		var f := float(i) / steps
		if f >= best_t:
			break
		var p := from.lerp(to, f)
		for t: Target in targets:
			if t.sagitta > 0.0:
				var q := t.box.affine_inverse() * p
				if absf(q.x) <= t.half.x and absf(q.y) <= t.half.y and q.z <= t.face_z(q.x) \
						and q.z >= -t.half.z - 0.5:
					return {"t": f, "point": p, "normal": t.box.basis * t.face_normal(q.x),
							"target": t, "crowd": false}
		if in_crowd(p):
			return {"t": f, "point": p, "normal": (from - to).normalized(), "target": null, "crowd": true}
		if p.y <= surface_under(p):
			p.y = surface_under(p)
			return {"t": f, "point": p, "normal": Vector3.UP, "target": null, "crowd": false}
	return best


## What a rocket lands on at `p`: the canvas and apron inside the ring, the
## deck and the ramp, the floor.
static func surface_under(p: Vector3) -> float:
	if absf(p.x) < RingBuilder.APRON_OUT and absf(p.z) < RingBuilder.APRON_OUT:
		return 0.0
	return ArenaBuilder.match_surface_y(p)


## The crowd: past the barricade on the floor and up the bowl, anywhere but up
## the entrance way and on the set, below the heads of the people sitting there
## (the bowl's rake rising from FLOOR_SEAT_START out).
static func in_crowd(p: Vector3) -> bool:
	var beyond := maxf(absf(p.x), absf(p.z)) - ArenaBuilder.BARRICADE_RADIUS
	if beyond < ArenaBuilder.FLOOR_SEAT_START - 0.2:
		return false
	if p.z < 0.0 and absf(p.x) < ArenaBuilder.RAMP_BARRICADE_OFFSET + 0.3:
		return false                    # the ramp's corridor
	if p.z < ArenaBuilder.STAGE_FRONT + 1.0 and absf(p.x) < ArenaBuilder.STAGE_HALF_WIDTH + 1.5:
		return false                    # the set
	if ArenaBuilder.in_desk_bay(p):
		return false                    # the announce team's bay
	var heads := ArenaBuilder.FLOOR_Y + 1.5 + maxf(0.0, beyond - 4.0) \
			* ArenaBuilder.ROW_RISE / ArenaBuilder.ROW_RUN
	return p.y < heads


func _ray_box(t: Target, from: Vector3, to: Vector3) -> Dictionary:
	var inv := t.box.affine_inverse()
	var a := inv * from
	var b := inv * to
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var normal := Vector3.ZERO
	for k in 3:
		if absf(d[k]) < 1e-9:
			if absf(a[k]) > t.half[k]:
				return {}
			continue
		var n0 := (-t.half[k] - a[k]) / d[k]
		var n1 := (t.half[k] - a[k]) / d[k]
		var axis_n := Vector3.ZERO
		axis_n[k] = -signf(d[k])
		if n0 > n1:
			var s := n0
			n0 = n1
			n1 = s
		if n0 > t0:
			t0 = n0
			normal = axis_n
		t1 = minf(t1, n1)
		if t0 > t1:
			return {}
	if normal == Vector3.ZERO:
		normal = Vector3.BACK               # started inside: out of its face
	return {"t": t0, "point": from.lerp(to, t0), "normal": (t.box.basis * normal).normalized()}


# --- the blast ---------------------------------------------------------------------

## A rocket going off at `at` (`normal` the face it hit): every piece within
## reach damaged, a scorch mark, rubble at the floor, and fire in the crowd
## or on a screen. `hit` is the piece it struck, if it struck one.
func blast(at: Vector3, normal := Vector3.UP, hit: Target = null, crowd := false) -> void:
	ensure_targets()
	var struck: Array = []
	for t: Target in targets:
		if t == hit or _distance_to_box(t, at) <= BLAST_RADIUS:
			struck.append(t)
	for t: Target in struck:
		_damage(t, at)
	if crowd or in_crowd(at):
		start_fire(at, 1.0)
		var spread := {"target": null, "origin": at, "n": 0, "t": 0.0, "age": 0.0}
		_spreads.append(spread)
		_shape_sheet(spread)
		history.append(["crowd", "Crowd", at])
		damaged.emit(-1, "Crowd", at)
	_scorch(at, normal)
	if at.y <= surface_under(at) + 0.6 and not crowd:
		_rubble(Vector3(at.x, surface_under(at), at.z))


func _distance_to_box(t: Target, p: Vector3) -> float:
	var q := t.box.affine_inverse() * p
	var outside := Vector3(maxf(absf(q.x) - t.half.x, 0.0), maxf(absf(q.y) - t.half.y, 0.0),
			maxf(absf(q.z) - t.half.z, 0.0))
	return outside.length()


func _damage(t: Target, at: Vector3) -> void:
	t.hits += 1
	if t.kind in SOLID:
		if not t.damaged:
			t.damaged = true
			for mi in _cuttable:
				if is_instance_valid(mi):
					cut_box(mi, t.box, t.half + Vector3.ONE * 0.04)
			_place(KIND_MODEL[t.kind], t.place, t.name)
	else:
		# a skin: the damage laid over it where the blast is, on its face
		var local := t.box.affine_inverse() * at
		local.x = clampf(local.x, -t.half.x + 0.9, t.half.x - 0.9) if t.half.x > 0.9 else 0.0
		local.y = clampf(local.y, -t.half.y + 0.9, t.half.y - 0.9) if t.half.y > 0.9 else 0.0
		var on_face := t.box * Vector3(local.x, local.y, t.face_z(local.x) + 0.012)
		for o: Vector3 in t.overlays:
			if o.distance_to(on_face) < OVERLAY_MERGE:
				if t.kind == Kind.SCREEN:
					start_fire(o, 0.8)
				history.append([Kind.keys()[t.kind], t.name, at])
				return
		_smash_skin(t, local)
		if t.kind == Kind.SCREEN:
			var spread := {"target": t, "origin": local, "n": 0, "t": 0.0, "age": 0.0}
			_spreads.append(spread)
			_shape_sheet(spread)
	history.append([Kind.keys()[t.kind], t.name, at])
	damaged.emit(t.kind, t.name, at)


## The damage laid over a skin at `local` (box-local, x and y on its face):
## a blown hole in the apron, a smashed patch of LED wall with a fire in it.
func _smash_skin(t: Target, local: Vector3, lit := true, fire := true) -> void:
	var on_face := t.box * Vector3(local.x, local.y, t.face_z(local.x) + 0.012)
	t.overlays.append(on_face)
	t.damaged = true
	var facing := t.box.basis * t.face_normal(local.x)
	var place := Transform3D(Basis(Vector3.UP.cross(facing).normalized(), Vector3.UP, facing), on_face)
	if t.kind == Kind.RING_APRON:
		# the skirt's section stands on the floor
		place.origin = t.box * Vector3(local.x, -t.half.y, t.half.z + 0.012)
	var overlay := _place(KIND_MODEL[t.kind], place, "%s_%d" % [t.name, t.overlays.size()])
	if overlay and t.kind == Kind.SCREEN:
		# an LED wall is metres across: a smashed patch the size of a man's
		# reach read as a scuff from the hard camera
		overlay.scale = Vector3.ONE * SCREEN_PATCH_SCALE
	if t.kind == Kind.SCREEN and fire:
		start_fire(on_face + facing * 0.15, 0.8, false, lit)


# --- the fire spreading -----------------------------------------------------------

## A fire does not stay where the rocket went in (the owner, 19 Oct: "spread
## the fire in that area as the match goes on ... it shouldn't just stay
## localised to the hot spot"), and it spreads as ONE fire, not a row of
## campfires: each hit's fire is a sheet of flame and smoke (a box emitter)
## whose edges creep outward -- across the LED wall it is on, or along the row
## and up the rows of seats -- getting denser and brighter as it widens. On a
## wall the tiles go as the fire reaches them: every SPREAD_EVERY seconds
## another smashed patch in the burning area, out to SPREAD_MAX.
const SPREAD_EVERY := 14.0
const SPREAD_MAX := 10
## Patch to patch, along the wall or the row.
const SPREAD_STEP := 2.3
## [along, up] in steps, in the order the tiles go.
const SPREAD_PATTERN := [[1, 0], [-1, 0], [0, 1], [2, 0], [-2, 0], [1, 1], [-1, 1],
		[0, -1], [3, 0], [-3, 0]]
## Up the bowl, a step is two rows: out ROW_RUN and up ROW_RISE each.
const ROWS_PER_STEP := 2.0
## The sheet's half-size: where it starts, how fast each edge moves (m/s), and
## how far it gets -- [along, up].
const SHEET_START := Vector2(0.6, 0.5)
const SHEET_RATE := Vector2(0.05, 0.022)
const SHEET_MAX := Vector2(6.9, 3.0)
## Flames and smoke at full size; a small sheet runs a share of them.
const SHEET_FLAMES := 420
const SHEET_SMOKE := 150

var _spreads: Array = []    # {"target", "origin", "n", "t", "age", "sheet"}


## How many tiles each hit's fire has taken (tests, probes).
func spread_counts() -> Array[int]:
	var out: Array[int] = []
	for s: Dictionary in _spreads:
		out.append(int(s["n"]))
	return out


## Each hit's fire sheet's half-size now, [along, up] (tests, probes).
func sheet_sizes() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s: Dictionary in _spreads:
		out.append(_sheet_half(s))
	return out


func _sheet_half(s: Dictionary) -> Vector2:
	var age := float(s.get("age", 0.0))
	return Vector2(minf(SHEET_START.x + SHEET_RATE.x * age, SHEET_MAX.x),
			minf(SHEET_START.y + SHEET_RATE.y * age, SHEET_MAX.y))


func _spread(delta: float) -> void:
	for s: Dictionary in _spreads:
		s["t"] = float(s["t"]) + delta
		s["age"] = float(s.get("age", 0.0)) + delta
		_shape_sheet(s)
		while float(s["t"]) >= SPREAD_EVERY and int(s["n"]) < SPREAD_MAX:
			s["t"] = float(s["t"]) - SPREAD_EVERY
			var step: Array = SPREAD_PATTERN[int(s["n"])]
			s["n"] = int(s["n"]) + 1
			var t: Target = s["target"]
			if t:
				var local: Vector3 = s["origin"] + Vector3(float(step[0]) * SPREAD_STEP,
						float(step[1]) * SPREAD_STEP * 0.7, 0.0)
				if absf(local.x) <= t.half.x - 0.5 and absf(local.y) <= t.half.y - 0.5:
					_smash_skin(t, local, false, false)


## The sheet's frame and its extent along/up: on a wall, the wall's face,
## clamped to the wall; in the crowd, along the row and up the rake.
func _shape_sheet(s: Dictionary) -> void:
	var half := _sheet_half(s)
	var t: Target = s["target"]
	var origin: Vector3 = s["origin"]
	var frame: Transform3D
	var extents: Vector3
	if t:
		var x0 := maxf(origin.x - half.x, -t.half.x + 0.3)
		var x1 := minf(origin.x + half.x, t.half.x - 0.3)
		var y0 := maxf(origin.y - half.y, -t.half.y + 0.3)
		var y1 := minf(origin.y + half.y, t.half.y - 0.3)
		var cx := (x0 + x1) * 0.5
		var facing := t.box.basis * t.face_normal(cx)
		var centre := t.box * Vector3(cx, (y0 + y1) * 0.5, t.face_z(cx)) + facing * 0.2
		frame = Transform3D(Basis(Vector3.UP.cross(facing).normalized(), Vector3.UP, facing), centre)
		extents = Vector3((x1 - x0) * 0.5, (y1 - y0) * 0.5, 0.15)
	else:
		var out := Vector3(signf(origin.x), 0.0, 0.0) if absf(origin.x) >= absf(origin.z) \
				else Vector3(0.0, 0.0, signf(origin.z))
		var along := Vector3(out.z, 0.0, -out.x)
		var rows := half.y / ArenaBuilder.ROW_RISE * ArenaBuilder.ROW_RUN
		# the sheet leans back up the rake: half its depth out, and its height
		# the rise over that depth
		var centre := origin + out * rows * 0.5 + Vector3.UP * half.y * 0.5
		frame = Transform3D(Basis(along, Vector3.UP, out), centre)
		extents = Vector3(half.x, maxf(half.y * 0.5, 0.3), maxf(rows * 0.5, 0.4))
	var sheet: Node3D = s.get("sheet")
	if sheet == null or not is_instance_valid(sheet):
		sheet = _sheet()
		s["sheet"] = sheet
	sheet.global_transform = frame
	var area := clampf(extents.x * maxf(extents.y, extents.z) / (SHEET_MAX.x * SHEET_MAX.y), 0.0, 1.0)
	for p: GPUParticles3D in [sheet.get_node("Flames"), sheet.get_node("Smoke")]:
		(p.process_material as ParticleProcessMaterial).emission_box_extents = extents
		p.amount_ratio = clampf(0.12 + area, 0.12, 1.0)
	var light := sheet.get_node("Glow") as OmniLight3D
	light.omni_range = 6.0 + maxf(extents.x, extents.y) * 1.6
	sheet.set_meta("glow", 3.0 + 6.0 * area)


## One spreading fire: flames and smoke from a box that grows, one light.
func _sheet() -> Node3D:
	var sheet := Node3D.new()
	sheet.name = "FireSheet%02d" % _spreads.size()
	add_child(sheet)
	var flames := _flames()
	flames.amount = SHEET_FLAMES
	var fm := flames.process_material as ParticleProcessMaterial
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var smoke := _smoke()
	smoke.amount = SHEET_SMOKE
	smoke.position = Vector3.ZERO
	var sm := smoke.process_material as ParticleProcessMaterial
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	for p: GPUParticles3D in [flames, smoke]:
		p.visibility_aabb = AABB(Vector3(-10, -4, -6), Vector3(20, 18, 12))
		sheet.add_child(p)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = FIRE_HOT
	light.light_energy = 3.0
	light.omni_attenuation = 1.2
	light.light_volumetric_fog_energy = 1.5
	light.shadow_enabled = false
	light.position = Vector3.FORWARD * -0.6
	sheet.add_child(light)
	return sheet


## The damaged model `root_name` out of venue_damage.glb, standing at `where`.
func _place(root_name: String, where: Transform3D, as_name: String) -> Node3D:
	if _models == null:
		var packed := load(MODEL) as PackedScene
		if packed == null:
			push_error("VenueDamage: %s failed to load. Run tools/blender/venue_damage.py." % MODEL)
			return null
		_models = packed.instantiate() as Node3D
	var template := _models.get_node_or_null(root_name) as Node3D
	if template == null:
		push_error("VenueDamage: %s has no '%s'." % [MODEL, root_name])
		return null
	var piece := template.duplicate() as Node3D
	piece.name = "Damaged_" + as_name
	add_child(piece)
	piece.global_transform = where
	return piece


## Every triangle of `mi` whose centre lies inside the box (`box` its centre
## and axes in the world, `half` its half-size) taken out of its mesh. The
## mesh is replaced by a copy without them; the rest of it, its materials and
## the instance's override are untouched. Returns how many went.
static func cut_box(mi: MeshInstance3D, box: Transform3D, half: Vector3) -> int:
	var mesh := mi.mesh
	if mesh == null or not mi.is_inside_tree():
		return 0
	var to_box := box.affine_inverse() * mi.global_transform
	var bounds := to_box * mesh.get_aabb()
	if not AABB(-half, half * 2.0).intersects(bounds):
		return 0
	var out := ArrayMesh.new()
	var removed := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			idx = arrays[Mesh.ARRAY_INDEX]
		else:
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var keep := PackedInt32Array()
		var primitive := (mesh as ArrayMesh).surface_get_primitive_type(s) if mesh is ArrayMesh \
				else Mesh.PRIMITIVE_TRIANGLES
		if primitive == Mesh.PRIMITIVE_TRIANGLES:
			for i in range(0, idx.size() - 2, 3):
				var c := to_box * ((verts[idx[i]] + verts[idx[i + 1]] + verts[idx[i + 2]]) / 3.0)
				if absf(c.x) <= half.x and absf(c.y) <= half.y and absf(c.z) <= half.z:
					removed += 1
				else:
					keep.append(idx[i])
					keep.append(idx[i + 1])
					keep.append(idx[i + 2])
		else:
			keep = idx
		if keep.is_empty():
			keep = PackedInt32Array([0, 0, 0])     # a surface cannot be empty
		arrays[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(primitive, arrays)
		out.surface_set_material(s, mesh.surface_get_material(s))
	if removed == 0:
		return 0
	# per-surface overrides belong to the instance; they carry over as long
	# as the surface count does, which it does
	mi.mesh = out
	return removed


# --- fire, scorch, rubble -------------------------------------------------------

const FIRE_HOT := Color(1.0, 0.70, 0.28)
const FIRE_ORANGE := Color(1.0, 0.40, 0.06)
const FIRE_RED := Color(0.80, 0.14, 0.04)


## A fire at `at` that burns for the rest of the match. Beside one already
## burning, that one grows instead.
func start_fire(at: Vector3, size := 1.0, merge := true, lit := true) -> Node3D:
	for f: Node3D in fires:
		if merge and f.global_position.distance_to(at) < FIRE_MERGE:
			f.scale = Vector3.ONE * minf(f.scale.x + 0.25 * size, 2.0)
			return f
	if fires.size() >= MAX_FIRES:
		var nearest: Node3D = fires[0]
		for f: Node3D in fires:
			if f.global_position.distance_to(at) < nearest.global_position.distance_to(at):
				nearest = f
		nearest.scale = Vector3.ONE * minf(nearest.scale.x + 0.2, 2.0)
		return nearest
	var fire := Node3D.new()
	fire.name = "Fire%02d" % fires.size()
	add_child(fire)
	fire.global_position = at
	fire.scale = Vector3.ONE * size
	fire.add_child(_flames())
	fire.add_child(_smoke())
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = FIRE_HOT
	light.light_energy = 3.0
	light.omni_range = 7.0
	light.omni_attenuation = 1.4
	light.light_volumetric_fog_energy = 1.5
	light.shadow_enabled = false
	light.position = Vector3.UP * 0.8
	# a spread fire lights the room only now and then: forty lights at once
	# is no brighter, only slower
	light.visible = lit
	fire.add_child(light)
	fires.append(fire)
	fire_started.emit(at)
	return fire


func _flames() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Flames"
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.45
	m.direction = Vector3.UP
	m.spread = 14.0
	m.initial_velocity_min = 1.6
	m.initial_velocity_max = 2.8
	m.gravity = Vector3(0.0, 1.2, 0.0)          # hot gas rises
	m.damping_min = 0.8
	m.damping_max = 1.4
	m.scale_min = 0.7
	m.scale_max = 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.6))
	shrink.add_point(Vector2(0.3, 1.0))
	shrink.add_point(Vector2(1.0, 0.2))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	m.scale_curve = shrink_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	grad.colors = PackedColorArray([FIRE_HOT, FIRE_ORANGE, FIRE_RED, Color(FIRE_RED, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	m.color_ramp = ramp
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.2, 1.05, 1.0)
	mat.albedo_texture = EntrancePyro._puff()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	p.draw_pass_1 = quad
	p.amount = 64
	p.lifetime = 0.9
	p.fixed_fps = 60
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 7, 6))
	p.emitting = true                           # and never stops
	return p


func _smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Smoke"
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.5
	m.direction = Vector3.UP
	m.spread = 10.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 1.6
	m.gravity = Vector3(0.0, 0.3, 0.0)
	m.scale_min = 1.0
	m.scale_max = 1.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 3.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	grad.colors = PackedColorArray([Color(0.1, 0.09, 0.08, 0.0), Color(0.08, 0.075, 0.07, 0.55),
			Color(0.05, 0.05, 0.05, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	m.color_ramp = ramp
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = EntrancePyro._puff()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	p.draw_pass_1 = quad
	p.amount = 36
	p.lifetime = 4.0
	p.fixed_fps = 30
	p.position = Vector3.UP * 0.9
	p.visibility_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 14, 10))
	p.emitting = true
	return p


func _process(delta: float) -> void:
	_spread(delta)
	# every fire's light flickers, each on its own phase
	_flicker_t += delta
	for f: Node3D in fires:
		var light := f.get_node_or_null("Glow") as OmniLight3D
		if light and light.visible:
			light.light_energy = 3.0 * f.scale.x * EntrancePyro.flicker(_flicker_t,
					fposmod(f.global_position.x * 12.9898 + f.global_position.z * 78.233, TAU))
	for s: Dictionary in _spreads:
		var sheet: Node3D = s.get("sheet")
		if sheet and is_instance_valid(sheet):
			(sheet.get_node("Glow") as OmniLight3D).light_energy = float(sheet.get_meta("glow", 3.0)) \
					* EntrancePyro.flicker(_flicker_t, float(_spreads.find(s)) * 1.7)


static var _scorch_tex: ImageTexture


## A burn mark: black at the middle, ragged brown at the edge.
static func scorch_texture() -> ImageTexture:
	if _scorch_tex:
		return _scorch_tex
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 1919
	noise.frequency = 0.07
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length() / (size * 0.5)
			var n := noise.get_noise_2d(x, y) * 0.35
			var a := clampf((1.0 - d + n) * 1.6, 0.0, 1.0)
			var core := clampf((0.55 - d + n) * 3.0, 0.0, 1.0)
			var c := Color(0.09, 0.05, 0.03).lerp(Color(0.012, 0.01, 0.01), core)
			img.set_pixel(x, y, Color(c, a * 0.92))
	_scorch_tex = ImageTexture.create_from_image(img)
	return _scorch_tex


func _scorch(at: Vector3, normal: Vector3) -> void:
	var decal := Decal.new()
	decal.name = "Scorch%02d" % _scorches.size()
	decal.texture_albedo = scorch_texture()
	decal.size = Vector3(SCORCH_SIZE, 0.6, SCORCH_SIZE)
	decal.upper_fade = 0.2
	decal.lower_fade = 0.2
	add_child(decal)
	# a decal projects down its -Y: point that into the face it hit
	var up := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	decal.global_transform = Transform3D(Basis(side, up, side.cross(up)), at)
	_scorches.append(decal)
	if _scorches.size() > MAX_SCORCHES:
		_scorches.pop_front().queue_free()


func _rubble(at: Vector3) -> void:
	var yaw := fposmod(at.x * 3.1 + at.z * 1.7, TAU)
	_place("Rubble", Transform3D(Basis(Vector3.UP, yaw), at), "Rubble%02d" % _scorches.size())
