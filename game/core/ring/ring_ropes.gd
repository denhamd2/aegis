class_name RingRopes
extends Node3D
## The twelve ropes as live strings: they give when a body goes into them,
## wrap round it, spring back and ring out -- instead of the static tubes
## ring.glb ships, which a man could lean his whole weight on without a
## millimetre of give.
##
## THE NUMBERS ARE gauntlet/refs/ropes.md's, and the model is the textbook
## one for a taut cable: each span is a string fixed at both turnbuckles,
## integrated as the discrete wave equation
##
##     a_i = c^2 (d[i-1] - 2 d[i] + d[i+1]) / h^2  -  b v_i
##
## on a displacement d = (out, up) from the rest shape, so a rope can be
## pushed out of the ring, pressed down under a foot, or lifted by a shoulder
## coming through underneath it. The wave speed c sets the fundamental,
## f1 = c / 2L; b sets how fast it rings down.
##
## BODIES ARE SPHERES, and the ropes are pushed out of them. Each wrestler is
## sampled into spheres along his bones every physics frame (hips, spine,
## chest, head, arms, legs), and any rope node inside one is put back on its
## surface in the plane across the rope -- so a back going into the ropes
## pushes a V into the top two, a foot on the middle rope presses it down,
## and a body going out between two ropes parts them. Because the neighbours
## are pulled along by the string term, the rope wraps round the body rather
## than denting at one point.
##
## COSMETIC, ONE WAY. The ropes read the bodies; nothing here pushes back.
## The rope colliders in scenes/ring.tscn and every gameplay number stay
## where they were, so this cannot move the replay hash. What the BODY does
## at the ropes -- carrying on into them for a quarter second before coming
## back -- is wrestler_controller.gd's rope load, which is gameplay and is
## documented there.
##
## Asleep when nothing is touching and nothing is moving: no simulation and
## no mesh rebuilds, so a ring nobody is near costs nothing.

const SEGMENTS := 48
## Fundamental of an undisturbed span. refs/ropes.md: a tensioned 1" cable
## over 6 m comes out at 7-10 Hz; the low end, because the rope ties and
## the hose sleeve damp the top of that range out and the footage shows a
## slow, heavy wobble rather than a buzz.
const FUNDAMENTAL_HZ := 7.0
## Fraction of critical damping on the fundamental. 0.08 rings a hard rope
## run down to a third in ~0.35 s -- two or three visible swings, which is
## what the 619 and rebound footage shows.
const DAMPING_RATIO := 0.08
## Extra damping on the short wavelengths only (a Laplacian of velocity, in
## m^2/s), so a kink where a knee left the rope smooths out instead of
## chattering. Mode k is damped at KINK_DAMPING * (k pi / L)^2 per second:
## nothing on the fundamental, ~40/s by the twentieth.
const KINK_DAMPING := 0.4
## A rope does not go further than this from its line, however hard it is
## pushed: past it the body is going through the ropes, not stretching them.
const MAX_DEFLECTION := 0.75
## Contact is looked for this far either side of a rope's line only.
const REACH_IN := 0.9
const REACH_OUT := 1.1
const SLEEP_DISPLACEMENT := 0.0004
const SLEEP_SPEED := 0.004

## Body sampling: (bone, bone, radius). A sphere every SPHERE_STEP along
## each segment. Radii are the base rig's; a bigger man's scale with his
## shoulder span, the same yardstick EntranceProps uses.
const BODY := [
	["pelvis", "spine_02", 0.15],
	["spine_02", "neck_01", 0.155],
	["neck_01", "Head", 0.075],
	["Head", "Head", 0.11],
	["upperarm_l", "lowerarm_l", 0.06], ["lowerarm_l", "hand_l", 0.048],
	["hand_l", "hand_l", 0.05],
	["upperarm_r", "lowerarm_r", 0.06], ["lowerarm_r", "hand_r", 0.048],
	["hand_r", "hand_r", 0.05],
	["thigh_l", "calf_l", 0.085], ["calf_l", "foot_l", 0.06],
	["foot_l", "foot_l", 0.055],
	["thigh_r", "calf_r", 0.085], ["calf_r", "foot_r", 0.06],
	["foot_r", "foot_r", 0.055],
]
const SPHERE_STEP := 0.07
const BASE_SHOULDER_SPAN := 0.384

## One rope: its rest line and its state. Arrays, not Packed*, so writing
## through the dictionary writes the rope (a Packed array in a Dictionary is
## a copy on every access).
class Rope:
	var side := 0          ## 0 +Z, 1 -Z, 2 +X, 3 -X
	var height := 0.0
	var along := Vector3.ZERO
	var out := Vector3.ZERO
	var rest: Array[Vector3] = []
	var s: Array[float] = []   ## along-rope coordinate of each node
	var d: Array[Vector2] = []  ## (out, up) displacement from rest
	var v: Array[Vector2] = []
	var awake := false
	var mesh: MeshInstance3D

	func pos(i: int) -> Vector3:
		return rest[i] + out * d[i].x + Vector3.UP * d[i].y


var material: Material
var _ropes: Array[Rope] = []
var _h := 0.0
var _c2 := 0.0
var _b := 0.0
var _half := 0.0
var _span := 0.0
var _radius := 0.018
## Spheres this frame, in this node's space: (centre, radius) per side.
var _spheres: Array = [[], [], [], []]


## Built from RingBuilder's constants, so the rest shape is the same
## parabola ring.py sweeps and a ring at rest looks exactly as it did.
func setup(span: float, half_length: float, heights: Array, sags: Dictionary,
		radius: float, mat: Material) -> void:
	_span = span
	_half = half_length
	_radius = radius
	material = mat
	var length := 2.0 * _half
	_h = length / SEGMENTS
	var c := 2.0 * length * FUNDAMENTAL_HZ
	_c2 = c * c
	_b = 2.0 * DAMPING_RATIO * TAU * FUNDAMENTAL_HZ
	for height: float in heights:
		var sag: float = sags[height]
		for side in 4:
			var r := Rope.new()
			r.side = side
			r.height = height
			r.along = Vector3.RIGHT if side < 2 else Vector3.BACK
			var sign_out := 1.0 if side % 2 == 0 else -1.0
			r.out = (Vector3.BACK if side < 2 else Vector3.RIGHT) * sign_out
			var base := r.out * _span + Vector3.UP * height
			for i in SEGMENTS + 1:
				var t := float(i) / SEGMENTS
				var s := -_half + length * t
				r.s.append(s)
				r.rest.append(base + r.along * s - Vector3.UP * (sag * 4.0 * t * (1.0 - t)))
				r.d.append(Vector2.ZERO)
				r.v.append(Vector2.ZERO)
			r.mesh = MeshInstance3D.new()
			r.mesh.name = "Rope%d_%d" % [side, int(height * 100)]
			r.mesh.material_override = material
			add_child(r.mesh)
			_ropes.append(r)
			_rebuild_mesh(r)


func _physics_process(delta: float) -> void:
	_gather_spheres()
	for r in _ropes:
		var touching := _touches(r)
		if not r.awake and not touching:
			continue
		r.awake = true
		_step(r, delta)
		_rebuild_mesh(r)
		if not touching and _settled(r):
			for i in r.d.size():
				r.d[i] = Vector2.ZERO
				r.v[i] = Vector2.ZERO
			r.awake = false
			_rebuild_mesh(r)


# ================================================================ bodies ===

## Physics frames a wrestler is ignored for after he first appears. For his
## first ~6 the AnimationTree is still blending him in from the unposed bind
## pose -- arms straight out at shoulder height -- and a man spawned or placed
## near the ropes in that window pushed the middle rope 18 cm down with a pose
## nobody ever sees, and it was still bouncing half a second later (found on a
## probe render; the owner asked what was wrong with the ropes).
const WARMUP_FRAMES := 10
var _first_seen := {}   # instance id -> physics frame


func _gather_spheres() -> void:
	for side in 4:
		(_spheres[side] as Array).clear()
	var inv := global_transform.affine_inverse()
	var frame := Engine.get_physics_frames()
	for node in get_tree().get_nodes_in_group("wrestlers"):
		var w := node as WrestlerController
		if w == null or not w.is_inside_tree() or not w.visible:
			continue
		var id := w.get_instance_id()
		if not _first_seen.has(id):
			_first_seen[id] = frame
		if frame - int(_first_seen[id]) < WARMUP_FRAMES:
			continue
		var p := inv * w.global_position
		# Nowhere near any rope: skip the bone walk entirely.
		if maxf(absf(p.x), absf(p.z)) < _span - REACH_IN - 0.6:
			continue
		_sample(w, inv)


func _sample(w: WrestlerController, inv: Transform3D) -> void:
	var sk := w.skeleton
	if sk == null:
		return
	var to_here := inv * sk.global_transform
	var scale := 1.0
	var l := _bone(w, sk, to_here, "upperarm_l")
	var rr := _bone(w, sk, to_here, "upperarm_r")
	if l != Vector3.INF and rr != Vector3.INF:
		scale = clampf(l.distance_to(rr) / BASE_SHOULDER_SPAN, 0.8, 1.5)
	for part: Array in BODY:
		var a := _bone(w, sk, to_here, part[0])
		var b := _bone(w, sk, to_here, part[1])
		if a == Vector3.INF or b == Vector3.INF:
			continue
		var radius: float = part[2] * scale
		var n := maxi(1, ceili(a.distance_to(b) / SPHERE_STEP))
		for k in n + 1:
			_add_sphere(a.lerp(b, float(k) / n), radius)


func _bone(w: WrestlerController, sk: Skeleton3D, to_here: Transform3D,
		canonical: String) -> Vector3:
	var i := sk.find_bone(w._skeleton_bone_name(canonical))
	if i < 0 and canonical == "Head":
		i = sk.find_bone(w._skeleton_bone_name("head"))
	if i < 0:
		return Vector3.INF
	return to_here * sk.get_bone_global_pose(i).origin


## Files a sphere under every side whose ropes it could reach.
func _add_sphere(c: Vector3, radius: float) -> void:
	for side in 4:
		var perp := c.z if side < 2 else c.x
		if side % 2 == 1:
			perp = -perp
		var off := perp - _span
		if off > -REACH_IN - radius and off < REACH_OUT + radius:
			(_spheres[side] as Array).append(Vector4(c.x, c.y, c.z, radius))


func _touches(r: Rope) -> bool:
	var list: Array = _spheres[r.side]
	if list.is_empty():
		return false
	for sp: Vector4 in list:
		var c := Vector3(sp.x, sp.y, sp.z)
		var along := c.dot(r.along)
		if absf(along) > _half + sp.w:
			continue
		var i := clampi(roundi((along + _half) / _h), 0, SEGMENTS)
		if r.pos(i).distance_to(c) < sp.w + _radius + MAX_DEFLECTION:
			return true
	return false


# ============================================================ simulation ===

func _step(r: Rope, delta: float) -> void:
	var c := sqrt(_c2)
	var n_sub := maxi(1, ceili(delta * c / (0.8 * _h)))
	var dt := delta / n_sub
	var inv_h2 := 1.0 / (_h * _h)
	var list: Array = _spheres[r.side]
	var acc: Array[Vector2] = []
	acc.resize(SEGMENTS + 1)
	for _sub in n_sub:
		acc[0] = Vector2.ZERO
		acc[SEGMENTS] = Vector2.ZERO
		for i in range(1, SEGMENTS):
			var lap := r.d[i - 1] - 2.0 * r.d[i] + r.d[i + 1]
			var lap_v := r.v[i - 1] - 2.0 * r.v[i] + r.v[i + 1]
			acc[i] = (_c2 * lap + KINK_DAMPING * lap_v) * inv_h2 - _b * r.v[i]
		for i in range(1, SEGMENTS):
			r.v[i] += acc[i] * dt
			r.d[i] += r.v[i] * dt
		for sp: Vector4 in list:
			_push_out(r, sp)
		for i in range(1, SEGMENTS):
			if r.d[i].length() > MAX_DEFLECTION:
				r.d[i] = r.d[i].normalized() * MAX_DEFLECTION
				var rad := r.d[i].normalized()
				var vr := r.v[i].dot(rad)
				if vr > 0.0:
					r.v[i] -= rad * vr


## Puts every node inside the sphere back on its surface, in the plane
## across the rope, and takes away the part of its velocity heading in.
func _push_out(r: Rope, sp: Vector4) -> void:
	var c := Vector3(sp.x, sp.y, sp.z)
	var reach := sp.w + _radius
	var along := c.dot(r.along)
	var i0 := maxi(1, ceili((along - reach + _half) / _h))
	var i1 := mini(SEGMENTS - 1, floori((along + reach + _half) / _h))
	for i in range(i0, i1 + 1):
		var ds := r.s[i] - along
		var ring2 := reach * reach - ds * ds
		if ring2 <= 0.0:
			continue
		var ring := sqrt(ring2)
		# The node and the sphere centre in the rope's (out, up) plane.
		var p := r.pos(i)
		var rel := Vector2((p - c).dot(r.out), p.y - c.y)
		var dist := rel.length()
		if dist >= ring:
			continue
		var n := rel / dist if dist > 1e-5 else Vector2(1.0, 0.0)
		r.d[i] += n * (ring - dist)
		var vn := r.v[i].dot(n)
		if vn < 0.0:
			r.v[i] -= n * vn


func _settled(r: Rope) -> bool:
	for i in r.d.size():
		if r.d[i].length() > SLEEP_DISPLACEMENT or r.v[i].length() > SLEEP_SPEED:
			return false
	return true


## Largest deflection on any rope right now, in metres -- for probes/tests.
func max_deflection() -> float:
	var m := 0.0
	for r in _ropes:
		for dd in r.d:
			m = maxf(m, dd.length())
	return m


## Deflection of the rope at `side`/`height` nearest `along`, (out, up).
func deflection_at(side: int, height: float, along: float) -> Vector2:
	for r in _ropes:
		if r.side == side and is_equal_approx(r.height, height):
			return r.d[clampi(roundi((along + _half) / _h), 0, SEGMENTS)]
	return Vector2.ZERO


func rope_count() -> int:
	return _ropes.size()


# ================================================================== mesh ===

const SIDES := 8

func _rebuild_mesh(r: Rope) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := SEGMENTS + 1
	for i in n:
		var p := r.pos(i)
		var t := (r.pos(mini(i + 1, SEGMENTS)) - r.pos(maxi(i - 1, 0))).normalized()
		var n1 := (Vector3.UP - t * t.dot(Vector3.UP)).normalized()
		var n2 := t.cross(n1)
		for k in SIDES + 1:
			var a := TAU * k / SIDES
			var nn := n1 * cos(a) + n2 * sin(a)
			verts.append(p + nn * _radius)
			normals.append(nn)
			uvs.append(Vector2(float(k) / SIDES, r.s[i]))
	var row := SIDES + 1
	for i in n - 1:
		for k in SIDES:
			var a := i * row + k
			var b := a + row
			# Godot's front faces wind clockwise seen from outside (see
			# RingBuilder._quad): (a+1 - a) x (b - a) points out, so reversed.
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := r.mesh.mesh as ArrayMesh
	if mesh == null:
		mesh = ArrayMesh.new()
		r.mesh.mesh = mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
