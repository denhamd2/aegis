class_name BreakDebris
extends Node3D
## The flying wreckage of a table, a pane of glass or the announce desk going
## (the owner, Nov: "table breaks ... should spectacularly break, look
## realistic"): splinters and chunks of board, micro-shards of glass, the
## monitors and the papers off the desk, and the one-shot bursts that go with
## them -- sawdust, chips, glints, dust and sparks.
##
## Every piece flies on a seeded launch and is integrated on the physics
## tick, like WeaponActor's own pieces: gravity, an optional drag (paper),
## spin, a bounce off the floor that takes most of the fall and some of the
## slide, and once it is slow, a short settle onto its flattest side. The
## floor is met by the piece's lowest corner, not its origin, so a board
## tipped on edge does not sink into the mat.
##
## It stays (LINGER seconds, or for the match), then goes with whatever made
## it. Presentation only: nothing in a match reads it, and it never touches
## the simulation or the replay's hash.

const GRAVITY := 9.8
## Of a landing's fall, kept as bounce; of its slide, kept along the floor.
const BOUNCE := 0.22
const SLIDE := 0.5
## Slower than this on the floor, it settles; settling takes this long.
const REST_SPEED := 0.75
const SETTLE := 0.1
## Spin lost per second while touching the floor.
const FLOOR_SPIN_DRAG := 5.0

## How long it all stays, in seconds (INF: the rest of the match).
var linger := 75.0
## The floor under a point: func(Vector3) -> float (WeaponActor.ground_under
## unless set).
var ground := Callable()
var _age := 0.0
## {node, box, v, spin, drag, fall, rest, settle_t, from, to, on_land, landed}
var _pieces: Array[Dictionary] = []


static func make(debris_name: String, life := 75.0) -> BreakDebris:
	var d := BreakDebris.new()
	d.name = debris_name
	d.linger = life
	return d


## How many pieces it has, and how many have come to rest (tests, probes).
func piece_count() -> int:
	return _pieces.size()


func resting_count() -> int:
	return _pieces.filter(func(p: Dictionary) -> bool: return p.rest).size()


func pieces() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for p: Dictionary in _pieces:
		out.append(p.node)
	return out


## A piece: `node` (already in the tree, placed in the world), `box` its local
## bounds, launched at `v` m/s spinning `spin` rad/s about that axis. `drag`
## slows it in the air (a sheet of paper floats down); `fall` scales gravity.
## `on_land` is called once, the first time it touches the floor.
func add_piece(node: Node3D, box: AABB, v: Vector3, spin: Vector3, drag := 0.0, fall := 1.0,
		on_land := Callable()) -> void:
	_pieces.append({"node": node, "box": box, "v": v, "spin": spin, "drag": drag, "fall": fall,
			"rest": false, "settle_t": -1.0, "from": Transform3D(), "to": Transform3D(),
			"on_land": on_land, "landed": false})


## A mesh piece at `at` (world), its basis `basis`.
func add_mesh(mesh: Mesh, material: Material, at: Vector3, basis: Basis, v: Vector3, spin: Vector3,
		drag := 0.0, fall := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.name = "Debris%03d" % _pieces.size()
	add_child(mi)
	mi.global_transform = Transform3D(basis, at)
	add_piece(mi, mesh.get_aabb(), v, spin, drag, fall)
	return mi


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= linger:
		queue_free()
		return
	for p: Dictionary in _pieces:
		if p.rest:
			continue
		var n: Node3D = p.node
		if not is_instance_valid(n):
			p.rest = true
			continue
		if p.settle_t >= 0.0:
			p.settle_t += delta
			var k := clampf(p.settle_t / SETTLE, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var a: Transform3D = p.from
			var b: Transform3D = p.to
			n.global_transform = Transform3D(a.basis.slerp(b.basis, k), a.origin.lerp(b.origin, k))
			if k >= 1.0:
				p.rest = true
			continue
		var v: Vector3 = p.v
		v.y -= GRAVITY * float(p.fall) * delta
		if p.drag > 0.0:
			v *= exp(-float(p.drag) * delta)
		var s: Vector3 = p.spin
		if s.length() > 0.0:
			n.global_rotate(s.normalized(), s.length() * delta)
		n.global_position += v * delta
		var floor_y := floor_under(n.global_position) + 0.004
		var low := lowest(n, p.box)
		if low <= floor_y:
			n.global_position.y += floor_y - low
			if not p.landed:
				p.landed = true
				if p.on_land.is_valid():
					p.on_land.call(n, v)
			if v.y < 0.0:
				v = Vector3(v.x * SLIDE, -v.y * BOUNCE, v.z * SLIDE)
				s *= 0.55
			s *= exp(-FLOOR_SPIN_DRAG * delta)
			v.x *= exp(-3.0 * delta)
			v.z *= exp(-3.0 * delta)
			if v.length() < REST_SPEED and s.length() < 2.5:
				p.from = n.global_transform
				p.to = flat_on(n.global_transform, p.box, floor_y)
				p.settle_t = 0.0
		p.v = v
		p.spin = s


func floor_under(p: Vector3) -> float:
	return float(ground.call(p)) if ground.is_valid() else WeaponActor.ground_under(p)


## The lowest point of `n`'s box in the world.
static func lowest(n: Node3D, box: AABB) -> float:
	return (n.global_transform * box).position.y


## `at` turned by quarter turns about its own axes to whichever way up puts
## the box lowest -- a board flat, a monitor on its back or its face -- the
## nearest such way to how it landed, its underside on `floor_y`.
static func flat_on(at: Transform3D, box: AABB, floor_y: float) -> Transform3D:
	var yaw := Basis(Vector3.UP, at.basis.get_euler().y)
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(box.get_endpoint(i))
	var best := at.basis.orthonormalized()
	var best_score := INF
	var best_low := 0.0
	var landed := at.basis.orthonormalized()
	for ix in 4:
		for iz in 4:
			var b := yaw * Basis(Vector3.RIGHT, ix * PI / 2.0) * Basis(Vector3.BACK, iz * PI / 2.0)
			var low := INF
			var high := -INF
			for c in corners:
				var y := (b * c).y
				low = minf(low, y)
				high = maxf(high, y)
			var score := (high - low) + 0.01 * (b.x.distance_to(landed.x) + b.y.distance_to(landed.y))
			if score < best_score:
				best_score = score
				best = b
				best_low = low
	return Transform3D(best, Vector3(at.origin.x, floor_y - best_low, at.origin.z))


# --- meshes ------------------------------------------------------------------------

## A splinter: a long thin board sliver along X, tapering to a point at +X
## (`taper` of its width left at the tip), `ln` x `w` x `h` metres.
static func sliver(ln: float, w: float, h: float, taper := 0.15) -> ArrayMesh:
	var a := ln * 0.5
	var t := taper
	var c := [Vector3(-a, -h / 2, -w / 2), Vector3(a, -h * t / 2, -w * t / 2), Vector3(a, -h * t / 2, w * t / 2),
			Vector3(-a, -h / 2, w / 2), Vector3(-a, h / 2, -w / 2), Vector3(a, h * t / 2, -w * t / 2),
			Vector3(a, h * t / 2, w * t / 2), Vector3(-a, h / 2, w / 2)]
	return _hull(c, [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]], 2.0)


## A glass shard: an irregular flat triangle or quad `size` across, `thick`
## thick, in XZ, from `rng`.
static func shard(rng: RandomNumberGenerator, size: float, thick := 0.006) -> ArrayMesh:
	var sides := 3 if rng.randf() < 0.6 else 4
	var pts: Array[Vector3] = []
	var start := rng.randf() * TAU
	for i in sides:
		var ang := start + TAU * i / sides + rng.randf_range(-0.35, 0.35)
		var r := size * rng.randf_range(0.35, 0.75) * (1.6 if i == 0 else 1.0)
		pts.append(Vector3(cos(ang) * r, 0.0, sin(ang) * r))
	var c: Array = []
	for p in pts:
		c.append(p + Vector3(0, -thick / 2, 0))
	for p in pts:
		c.append(p + Vector3(0, thick / 2, 0))
	var faces: Array = []
	var bottom: Array = []
	var top: Array = []
	for i in sides:
		bottom.append(i)
		top.append(sides + (sides - 1 - i))
		var j := (i + 1) % sides
		faces.append([i, sides + i, sides + j, j])
	faces.append(bottom)
	faces.append(top)
	return _hull(c, faces, 3.0)


## A flat-shaded solid from corner points and faces (each a loop of corner
## indices), planar UVs at `uv_scale` per metre. Each face's normal is the
## one pointing away from the middle, and its triangles are wound for Godot
## (clockwise seen from the front), whichever way the loop runs.
static func _hull(corners: Array, faces: Array, uv_scale: float) -> ArrayMesh:
	var mid := Vector3.ZERO
	for c: Vector3 in corners:
		mid += c
	mid /= corners.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Array in faces:
		var centre := Vector3.ZERO
		for idx: int in f:
			centre += corners[idx]
		centre /= f.size()
		var p0: Vector3 = corners[f[0]]
		var normal := Vector3.ZERO
		for k in range(1, f.size() - 1):
			normal += (corners[f[k]] - p0).cross(corners[f[k + 1]] - p0)
		normal = normal.normalized()
		if normal.dot(centre - mid) < 0.0:
			normal = -normal
		for k in range(1, f.size() - 1):
			var tri: Array[Vector3] = [p0, corners[f[k]], corners[f[k + 1]]]
			if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(normal) > 0.0:
				tri = [tri[0], tri[2], tri[1]]
			for q in tri:
				st.set_normal(normal)
				st.set_uv(Vector2(q.x + q.y, q.z + q.y) * uv_scale)
				st.add_vertex(q)
	return st.commit()


# --- materials -----------------------------------------------------------------------

static var _glass_mat: StandardMaterial3D


## Broken glass as it lies in the hall: near-clear, a mirror finish so it
## catches the ring lights and the screens, and a trace of its own light so a
## shard on the dark floor still reads.
static func glass_material() -> StandardMaterial3D:
	if _glass_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.80, 0.92, 0.95, 0.42)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.03
		m.metallic = 0.3
		m.metallic_specular = 1.0
		m.rim_enabled = true
		m.rim = 0.6
		m.rim_tint = 0.2
		m.emission_enabled = true
		m.emission = Color(0.55, 0.68, 0.75)
		m.emission_energy_multiplier = 0.18
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glass_mat = m
	return _glass_mat


# --- bursts --------------------------------------------------------------------------

## A one-shot burst of particles at `at`, then gone. `kind`:
##   "sawdust"  a brown puff hanging where the board split
##   "chips"    wood chips sprayed out and falling
##   "glints"   pin-points of light thrown out with the glass, flickering
##   "dust"     a grey cloud rolling out low (the desk going down)
##   "sparks"   a short of hot sparks and the flash of it (a monitor)
func burst(at: Vector3, kind: String, scale := 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Burst_" + kind
	p.one_shot = true
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = ManFire._soft_dot()
	var colors := PackedColorArray()
	var offsets := PackedFloat32Array()
	match kind:
		"sawdust":
			p.amount = int(70 * scale)
			p.lifetime = 2.2
			p.explosiveness = 0.95
			m.emission_sphere_radius = 0.25 * scale
			m.direction = Vector3.UP
			m.spread = 80.0
			m.initial_velocity_min = 0.6
			m.initial_velocity_max = 2.4
			m.gravity = Vector3(0, -0.6, 0)
			m.damping_min = 1.6
			m.damping_max = 2.6
			m.scale_min = 0.6
			m.scale_max = 1.6
			quad.size = Vector2(0.28, 0.28)
			offsets = PackedFloat32Array([0.0, 0.15, 1.0])
			colors = PackedColorArray([Color(0.62, 0.50, 0.36, 0.0), Color(0.55, 0.44, 0.31, 0.55),
					Color(0.45, 0.38, 0.30, 0.0)])
		"chips":
			p.amount = int(90 * scale)
			p.lifetime = 0.8
			p.explosiveness = 1.0
			m.emission_sphere_radius = 0.2 * scale
			m.direction = Vector3.UP
			m.spread = 70.0
			m.initial_velocity_min = 2.5
			m.initial_velocity_max = 6.5
			m.gravity = Vector3(0, -GRAVITY, 0)
			m.scale_min = 0.4
			m.scale_max = 1.0
			quad.size = Vector2(0.035, 0.035)
			mat.albedo_texture = null
			offsets = PackedFloat32Array([0.0, 0.8, 1.0])
			colors = PackedColorArray([Color(0.70, 0.55, 0.38, 1.0), Color(0.60, 0.46, 0.30, 1.0),
					Color(0.55, 0.42, 0.28, 0.0)])
		"glints":
			p.amount = int(180 * scale)
			p.lifetime = 1.1
			p.explosiveness = 1.0
			p.randomness = 0.5
			m.emission_sphere_radius = 0.35 * scale
			m.direction = Vector3.UP
			m.spread = 85.0
			m.initial_velocity_min = 1.5
			m.initial_velocity_max = 5.5
			m.gravity = Vector3(0, -GRAVITY, 0)
			m.scale_min = 0.5
			m.scale_max = 1.3
			quad.size = Vector2(0.05, 0.05)
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			# a flicker as each one turns in the light
			for i in 9:
				offsets.append(i / 8.0)
				var on := 1.0 - i / 9.0
				colors.append(Color(2.4, 2.6, 2.8, on) if i % 2 == 0 else Color(0.6, 0.7, 0.8, on * 0.4))
		"dust":
			p.amount = int(90 * scale)
			p.lifetime = 3.2
			p.explosiveness = 0.9
			m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			m.emission_box_extents = Vector3(1.8, 0.2, 0.4) * scale
			m.direction = Vector3(0, 0.4, -1)
			m.spread = 75.0
			m.initial_velocity_min = 0.6
			m.initial_velocity_max = 2.2
			m.gravity = Vector3(0, 0.15, 0)
			m.damping_min = 0.8
			m.damping_max = 1.4
			m.scale_min = 1.0
			m.scale_max = 2.4
			quad.size = Vector2(0.55, 0.55)
			offsets = PackedFloat32Array([0.0, 0.12, 1.0])
			colors = PackedColorArray([Color(0.55, 0.53, 0.50, 0.0), Color(0.50, 0.48, 0.46, 0.5),
					Color(0.40, 0.39, 0.38, 0.0)])
		"sparks":
			p.amount = int(70 * scale)
			p.lifetime = 1.0
			p.explosiveness = 0.9
			m.emission_sphere_radius = 0.12
			m.direction = Vector3.UP
			m.spread = 75.0
			m.initial_velocity_min = 1.5
			m.initial_velocity_max = 4.5
			m.gravity = Vector3(0, -GRAVITY, 0)
			m.scale_min = 0.5
			m.scale_max = 1.0
			quad.size = Vector2(0.05, 0.05)
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			offsets = PackedFloat32Array([0.0, 0.4, 1.0])
			colors = PackedColorArray([Color(2.0, 1.9, 1.6, 1.0), Color(1.6, 0.9, 0.35, 0.85),
					Color(1.0, 0.35, 0.08, 0.0)])
			_flash(at, Color(0.85, 0.9, 1.0), 5.0 * scale, 5.0)
	var grad := Gradient.new()
	grad.offsets = offsets
	grad.colors = colors
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	ramp.use_hdr = true
	m.color_ramp = ramp
	p.process_material = m
	quad.material = mat
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 12))
	add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Glints off the shards lying on the floor: pin-points coming and going over
## a patch `half` metres across for `seconds`, as a man moving through the
## light catches them, then stopping.
func twinkle(at: Vector3, half: float, seconds: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Twinkle"
	p.amount = 28
	p.lifetime = 0.35
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(half, 0.01, half)
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 0.0
	m.scale_min = 0.4
	m.scale_max = 1.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(2.0, 2.2, 2.4, 0.0), Color(2.0, 2.2, 2.4, 0.9), Color(2.0, 2.2, 2.4, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	ramp.use_hdr = true
	m.color_ramp = ramp
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.045)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = ManFire._soft_dot()
	quad.material = mat
	p.draw_pass_1 = quad
	p.visibility_aabb = AABB(Vector3(-half - 1, -1, -half - 1), Vector3(half * 2 + 2, 3, half * 2 + 2))
	add_child(p)
	p.global_position = at + Vector3.UP * 0.02
	p.emitting = true
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)
	return p


func _flash(at: Vector3, color: Color, energy: float, reach: float) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = energy
	flash.omni_range = reach
	add_child(flash)
	flash.global_position = at + Vector3.UP * 0.2
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)
