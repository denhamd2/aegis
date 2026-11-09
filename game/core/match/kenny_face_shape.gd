class_name KennyFaceShape
extends RefCounted
## Kenny's face on Cody's head, at load (gauntlet/refs/characters/review/
## kenny_face_judge.md).
##
## First his head SHAPE, photo-fitted from the owner's sheet (the owner, 28
## Oct: Kenny's head shape from the character sheet). tools/assets/
## build_kenny_head.py solves his landmarks from the sheet's front head shot
## and true profile and carries them over Cody's head with a thin-plate
## spline: his narrower mouth, jaw and nose, his nose's projection, his chin.
## (Not his brow: marked at the top of the brow hair on the photo and
## mid-brow on Cody, it only places the cameras.)
## It bakes each moved vertex's rest position, offset and normal change
## (SHAPE); this applies them, matching vertices by rest position within
## MATCH (the import compresses positions, by tens of microns).
##
## Then the few hand moves the photos cannot give (loops 2 and 3): bumps in
## the model's rest space (metres; x across him, y up, z forward), applied by
## RomanFaceShape's sculpt so normals follow. The fit holds the eyes where
## Cody's are -- the eyeballs turn about their bones -- so his squint, the
## upper lids down and the lower lids up, is a pair of moves; and neither
## photo sees his cheeks in depth. Cody's head is
## not centred on x = 0: his eyes sit at x 0.0359 and -0.0281, so the moves
## mirror about MIDLINE_X. Everything here is clear of y 1.62 and of the
## scalp, so the neck seam and the curls' cap (built on the unshaped scalp)
## are untouched.

const SHAPE := "res://resources/characters/kenny_head_shape.tres"
## How near an imported vertex must be to a baked rest position to take its
## move (m), and the lookup grid's cell.
const MATCH := 0.0002
const CELL := 0.001
const MIDLINE_X := 0.004
## [centre (x from the midline), radii, displacement (x outward), mirrored].
const TABLE := [
	# The upper lid down over the eye, and out with it so the margin stays on
	# the eyeball's curve: hooded, the sheet's squint.
	[Vector3(0.032, 1.7235, -0.012), Vector3(0.017, 0.007, 0.012), Vector3(0.0, -0.0028, 0.0014), true],
	# And the lower lid up over the bottom of the iris, forward with it to
	# stay on the eyeball: the other half of his squint. Cody's margin sits
	# at y 1.709, under the iris; the eye read as a stare (loop 3, run 11).
	# Full under the pupil, little at the corners.
	# 8 Nov: 1.2 mm still left a band of white under the iris under match
	# light -- a stare. 2.2 mm.
	[Vector3(0.032, 1.7085, -0.015), Vector3(0.015, 0.006, 0.010), Vector3(0.0, 0.0022, 0.0011), true],
	# Fuller under the eyes...
	[Vector3(0.045, 1.680, -0.020), Vector3(0.022, 0.020, 0.030), Vector3(0.0025, 0.0, 0.0035), true],
	# ...and the cheek hollow filled.
	[Vector3(0.055, 1.655, -0.030), Vector3(0.024, 0.022, 0.035), Vector3(0.0030, 0.0, 0.0030), true],
	# And the deep crease at Cody's mouth corners filled: its shadow carried
	# the line of the lips on past them (loop 2, run 7).
	[Vector3(0.032, 1.639, -0.012), Vector3(0.008, 0.007, 0.010), Vector3(0.0, 0.0, 0.0015), true],
	# 8 Nov (the owner: "matching exactly"): his face reads broad where the
	# fit left it long and narrow -- the jaw and lower cheeks out 6.5 mm a
	# side, at the front half of the jaw...
	[Vector3(0.058, 1.622, -0.045), Vector3(0.026, 0.026, 0.045), Vector3(0.0065, 0.0, 0.0015), true],
	# ...the cheekbones out with it, under the eyes...
	[Vector3(0.058, 1.668, -0.035), Vector3(0.022, 0.020, 0.035), Vector3(0.0040, 0.0, 0.0010), true],
	# ...his brow ridge set back: Cody's stands 3-5 mm proud over the inner
	# brows (1.74 m), where the sheet's profile runs smooth from forehead to
	# bridge (loop 3's "what holds it at about 7")...
	[Vector3(0.012, 1.741, 0.0), Vector3(0.022, 0.010, 0.016), Vector3(0.0, 0.0, -0.0025), true],
	# 9 Nov, the owner: "What's the crease above his eyes? It's not there in
	# our head texture." Cody's brow ridge peaks at y 1.730 and the forehead
	# falls 6-8 mm behind it by 1.750 before its own gentle slope: a concave
	# step that renders as a dark furrow across his brow (ambient occlusion
	# under the truss key; it is there with no reshape at all). Filled
	# forward, so ridge runs into forehead.
	[Vector3(0.022, 1.756, -0.004), Vector3(0.036, 0.013, 0.030), Vector3(0.0, 0.0, 0.0035), true],
	# The ridge itself set back along its whole width, not just the inner
	# brow: under the truss its underside shadow and his brows merged into
	# one dark band ("is Kenny missing his eyebrows?").
	[Vector3(0.030, 1.733, -0.004), Vector3(0.040, 0.010, 0.030), Vector3(0.0, 0.0, -0.0030), true],
	# ...and his chin carried forward, as his profile has it.
	[Vector3(0.0, 1.600, -0.006), Vector3(0.024, 0.013, 0.020), Vector3(0.0, -0.0005, 0.0030), false],
]
## The head's skin, shaped by both; the mouth's inside, by the photo-fit, so
## the lips and what is behind them move together.
const SKIN_MATERIAL := "xmaterial_c3d4d9e78b44a79"
const MOUTH_MATERIAL := "head_shared_inside_mouth_iw9"

static var _moves: Array = []


## TABLE in RomanFaceShape's form: absolute centres, each side its own move.
static func moves() -> Array:
	if _moves.is_empty():
		for row: Array in TABLE:
			var c: Vector3 = row[0]
			var d: Vector3 = row[2]
			for side in ([1.0, -1.0] if row[3] else [1.0]):
				_moves.append([Vector3(MIDLINE_X + c.x * side, c.y, c.z), row[1],
						Vector3(d.x * side, d.y, d.z), false])
	return _moves


## Shapes the head of every mesh under `root`. Returns how many vertices moved.
static func apply(root: Node) -> int:
	var shape := load(SHAPE) as KennyHeadShapeData
	var index := _index(shape) if shape else {}
	var moved := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var source := mi.mesh as ArrayMesh
		if source == null or source.get_blend_shape_count() > 0:
			continue
		var surfaces: Array = []
		var any := false
		for s in source.get_surface_count():
			var arrays := source.surface_get_arrays(s)
			var material := source.surface_get_material(s)
			var mat_name := material.resource_name if material else ""
			var n := 0
			if shape and (mat_name == SKIN_MATERIAL or mat_name == MOUTH_MATERIAL):
				n += fit(arrays, shape, index)
			if mat_name == SKIN_MATERIAL:
				n += RomanFaceShape.sculpt(arrays, moves())
				relax(arrays)
				soften(arrays)
			moved += n
			any = any or n > 0
			surfaces.append(arrays)
		if any:
			mi.mesh = BodyBulk.rebuilt(source, surfaces)
	return moved


## The owner, 9 Nov: "Same with that dark shadows. The cheeks, is this from
## Cody? I don't see it on our face texture image." It is: his photo's cheeks
## are an even peach (unshaded, the atlas renders clean), but Cody's head
## carries bags under the eyes and hollows under the cheekbones, and under
## the truss key they fill with shadow -- with Kenny's shaping off as well.
## Inside these regions the surface is relaxed (each welded vertex drawn
## toward its neighbours' mean, RELAX_PASSES times, by the region's weight)
## and its normals are rebuilt from the relaxed faces, so the hollows ease
## out and shade smooth. [centre, radii, strength], mirrored about MIDLINE_X;
## clear of the lid margins (y 1.709) and the mouth.
const RELAX := [
	# Under the eyes: the bags.
	[Vector3(0.034, 1.692, -0.016), Vector3(0.022, 0.011, 0.022), 1.0],
	# The cheek below the cheekbone, out to the side plane.
	[Vector3(0.052, 1.664, -0.030), Vector3(0.028, 0.026, 0.034), 1.0],
]
const RELAX_PASSES := 14
## And the side planes of his cheeks, where Cody's narrow, flat-fronted face
## turns sharply away from the light (SSAO off, the band stayed: it is the
## shape): their shading normals bent part-way to face front, so the shade
## rolls off as round over a broader face, the silhouette untouched.
## [centre, radii, bend], mirrored.
const SOFTEN := [
	[Vector3(0.060, 1.662, -0.040), Vector3(0.030, 0.050, 0.045), 0.45],
	# ...down the side of the face toward the jaw, below the cheekbone.
	[Vector3(0.064, 1.640, -0.048), Vector3(0.030, 0.040, 0.050), 0.5],
	[Vector3(0.036, 1.694, -0.018), Vector3(0.022, 0.012, 0.022), 0.35],
]


const SOFTEN_TOWARD := Vector3(0.0, 0.6, 0.8)


static func _soften_weight(p: Vector3) -> float:
	var w := 0.0
	for r: Array in SOFTEN:
		var c: Vector3 = r[0]
		var rad: Vector3 = r[1]
		for side: float in [1.0, -1.0]:
			var d := (p - Vector3(MIDLINE_X + side * c.x, c.y, c.z)) / rad
			var t := clampf(1.0 - d.length(), 0.0, 1.0)
			w = maxf(w, float(r[2]) * t * t * (3.0 - 2.0 * t))
	return w


## Bends the SOFTEN regions' normals toward the face's front (+Z).
static func soften(arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	if normals == null:
		return
	var tangents = arrays[Mesh.ARRAY_TANGENT]
	for v in verts.size():
		var w := _soften_weight(verts[v])
		if w <= 0.0:
			continue
		var old: Vector3 = normals[v]
		if old.z < -0.2:
			continue  # facing back: not his face
		# Up and to the front: the truss keys are overhead, not at the
		# camera -- bent only to the front, the cheeks stayed as dark.
		var n := (old + SOFTEN_TOWARD * w * 1.8).normalized()
		normals[v] = n
		if tangents != null and (tangents as PackedFloat32Array).size() >= (v + 1) * 4:
			var t := Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2])
			t = (t - n * n.dot(t)).normalized()
			tangents[v * 4] = t.x
			tangents[v * 4 + 1] = t.y
			tangents[v * 4 + 2] = t.z
	arrays[Mesh.ARRAY_NORMAL] = normals
	if tangents != null:
		arrays[Mesh.ARRAY_TANGENT] = tangents
const RELAX_RATE := 0.5


static func _relax_weight(p: Vector3) -> float:
	var w := 0.0
	for r: Array in RELAX:
		var c: Vector3 = r[0]
		var rad: Vector3 = r[1]
		for side: float in [1.0, -1.0]:
			var centre := Vector3(MIDLINE_X + side * c.x, c.y, c.z)
			var d := (p - centre) / rad
			var t := clampf(1.0 - d.length(), 0.0, 1.0)
			w = maxf(w, float(r[2]) * t * t * (3.0 - 2.0 * t))
	return w


## Relaxes the RELAX regions of one surface, in place. Returns how many
## welded points moved.
static func relax(arrays: Array) -> int:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if verts.is_empty() or indices.is_empty():
		return 0
	# Weld: the seams duplicate a point for each UV island.
	var key_to := {}
	var group := PackedInt32Array()
	group.resize(verts.size())
	var pos: Array[Vector3] = []
	for v in verts.size():
		var k := Vector3i((verts[v] * 50000.0).round())
		var g: int = key_to.get(k, -1)
		if g < 0:
			g = pos.size()
			key_to[k] = g
			pos.append(verts[v])
		group[v] = g
	var weight := PackedFloat32Array()
	weight.resize(pos.size())
	var active := {}
	for g in pos.size():
		weight[g] = _relax_weight(pos[g])
		if weight[g] > 0.0:
			active[g] = true
	if active.is_empty():
		return 0
	var nbrs := {}
	for f in range(0, indices.size(), 3):
		var a := group[indices[f]]
		var b := group[indices[f + 1]]
		var c := group[indices[f + 2]]
		for pair: Array in [[a, b], [b, c], [c, a], [b, a], [c, b], [a, c]]:
			if active.has(pair[0]):
				if not nbrs.has(pair[0]):
					nbrs[pair[0]] = {}
				(nbrs[pair[0]] as Dictionary)[pair[1]] = true
	for _pass in RELAX_PASSES:
		var next := {}
		for g: int in active:
			var ns: Dictionary = nbrs.get(g, {})
			if ns.is_empty():
				continue
			var mean := Vector3.ZERO
			for o: int in ns:
				mean += pos[o]
			mean /= float(ns.size())
			next[g] = pos[g].lerp(mean, RELAX_RATE * weight[g])
		for g: int in next:
			pos[g] = next[g]
	for v in verts.size():
		if active.has(group[v]):
			verts[v] = pos[group[v]]
	arrays[Mesh.ARRAY_VERTEX] = verts
	# Normals from the relaxed faces, eased in by the weight.
	var normals = arrays[Mesh.ARRAY_NORMAL]
	if normals != null:
		var acc := {}
		for f in range(0, indices.size(), 3):
			var ga := group[indices[f]]
			var gb := group[indices[f + 1]]
			var gc := group[indices[f + 2]]
			if not (active.has(ga) or active.has(gb) or active.has(gc)):
				continue
			var fn := (pos[gc] - pos[ga]).cross(pos[gb] - pos[ga])
			for g in [ga, gb, gc]:
				acc[g] = (acc.get(g, Vector3.ZERO) as Vector3) + fn
		var tangents = arrays[Mesh.ARRAY_TANGENT]
		for v in verts.size():
			var g := group[v]
			if not active.has(g) or not acc.has(g):
				continue
			var built := (acc[g] as Vector3).normalized()
			var old: Vector3 = normals[v]
			if built.dot(old) < 0.0:
				built = -built
			var n := old.slerp(built, clampf(weight[g] * 1.5, 0.0, 1.0)).normalized()
			normals[v] = n
			if tangents != null and (tangents as PackedFloat32Array).size() >= (v + 1) * 4:
				var t := Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2])
				t = (t - n * n.dot(t)).normalized()
				tangents[v * 4] = t.x
				tangents[v * 4 + 1] = t.y
				tangents[v * 4 + 2] = t.z
		arrays[Mesh.ARRAY_NORMAL] = normals
		if tangents != null:
			arrays[Mesh.ARRAY_TANGENT] = tangents
	return active.size()


## The baked rest positions, by grid cell.
static func _index(shape: KennyHeadShapeData) -> Dictionary:
	var index := {}
	for i in shape.rest.size():
		var key := Vector3i((shape.rest[i] / CELL).floor())
		# A packed array read out of a Dictionary is a copy: appended to in
		# place, every cell stayed empty and the fit matched nothing (loop 3).
		var cell: PackedInt32Array = index.get(key, PackedInt32Array())
		cell.append(i)
		index[key] = cell
	return index


## The baked entry for rest position `p`, or -1.
static func _find(shape: KennyHeadShapeData, index: Dictionary, p: Vector3) -> int:
	var lo := Vector3i(((p - Vector3.ONE * MATCH) / CELL).floor())
	var hi := Vector3i(((p + Vector3.ONE * MATCH) / CELL).floor())
	var best := -1
	var best_d := MATCH * MATCH
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var cell: Variant = index.get(Vector3i(x, y, z))
				if cell == null:
					continue
				for i: int in cell:
					var d := shape.rest[i].distance_squared_to(p)
					if d <= best_d:
						best = i
						best_d = d
	return best


## Moves one surface's vertices to the photo-fitted shape, normals and
## tangents with them. Returns how many moved.
static func fit(arrays: Array, shape: KennyHeadShapeData, index: Dictionary) -> int:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	var tangents = arrays[Mesh.ARRAY_TANGENT]
	var moved := 0
	for v in verts.size():
		var i := _find(shape, index, verts[v])
		if i < 0:
			continue
		verts[v] += shape.offset[i]
		if normals != null and v < (normals as PackedVector3Array).size():
			var n := ((normals[v] as Vector3) + shape.normal_offset[i]).normalized()
			normals[v] = n
			if tangents != null and (tangents as PackedFloat32Array).size() >= (v + 1) * 4:
				var t := Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2])
				t = (t - n * n.dot(t)).normalized()
				tangents[v * 4] = t.x
				tangents[v * 4 + 1] = t.y
				tangents[v * 4 + 2] = t.z
		moved += 1
	arrays[Mesh.ARRAY_VERTEX] = verts
	if normals != null:
		arrays[Mesh.ARRAY_NORMAL] = normals
	if tangents != null:
		arrays[Mesh.ARRAY_TANGENT] = tangents
	return moved
