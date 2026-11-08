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
			moved += n
			any = any or n > 0
			surfaces.append(arrays)
		if any:
			mi.mesh = BodyBulk.rebuilt(source, surfaces)
	return moved


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
