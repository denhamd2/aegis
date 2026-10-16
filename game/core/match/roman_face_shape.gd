class_name RomanFaceShape
extends RefCounted
## Fits the supplied head to the owner's October 16 ramp portrait, at load.
## The previous 2K26 pass narrowed the jaw/cheeks, lengthened the chin/nose
## and lowered the brow heavily. Against the new target it looked pinched
## and sleepy. Keep a defined brow and cheekbone, restore jaw width and
## soften the cheek hollow. Reference/evidence: visual_target_2026_10_16.
##
## Each move is a smooth bump in the model's own rest space (metres; x across
## him, y up, z forward; nose tip at (0, 1.674, 0.163), eyes at x +-0.033,
## y 1.720, mouth at y 1.646): every vertex within the bump's ellipsoid moves
## by its displacement, faded to nothing at the edge by a smoothstep. The
## field is applied to every mesh of the model at once -- skin, lashes,
## teeth, mouth, beard cards, hair -- so whatever sits together stays
## together: the beard follows the jaw it grows on. Except the eyeballs and
## caruncles (FIXED): they turn about their bones, and the lids (EyeLids) are
## placed off those bones, so they stay put and the eyes are set deeper by
## the brow coming forward over them and the lids lowering
## (RomanModel.LID_OPEN), not by moving the eyes. Normals and tangents are carried through the field's own
## Jacobian, so the lighting sees the new shape (the brow's shadow over the
## eyes is most of the look).
##
## Rest-pose geometry only, nothing below the neck moves (every bump is clear
## of y 1.55), and the supplied .glb is never edited (CREDITS.md). Runs in
## RomanModel._ready before anything reads the head's vertices (the beard
## trim, the eyelids, the hair volume).

## [centre, radii, displacement, mirrored]. A mirrored bump is applied on both
## sides, its centre's and displacement's x flipped for the left side.
const MOVES := [
	# A firm orbital ridge without folding down onto the upper lids.
	[Vector3(0.031, 1.738, 0.125), Vector3(0.032, 0.014, 0.035), Vector3(0.0, -0.0025, 0.0045), true],
	[Vector3(0.0, 1.735, 0.140), Vector3(0.016, 0.012, 0.030), Vector3(0.0, -0.0015, 0.0030), false],
	# High cheekbones, out and up a little...
	[Vector3(0.056, 1.699, 0.095), Vector3(0.022, 0.015, 0.032), Vector3(0.0030, 0.0015, 0.0020), true],
	# ...and the hollow under them.
	[Vector3(0.054, 1.662, 0.095), Vector3(0.024, 0.020, 0.036), Vector3(-0.0025, 0.0, -0.0015), true],
	# Broader lower face, retaining the source rig and facial attachments.
	[Vector3(0.072, 1.675, 0.060), Vector3(0.032, 0.045, 0.065), Vector3(0.0010, 0.0, 0.0), true],
	[Vector3(0.062, 1.625, 0.060), Vector3(0.030, 0.035, 0.065), Vector3(0.0020, 0.0, 0.0), true],
	# The nose: a higher, narrower bridge...
	[Vector3(0.0, 1.700, 0.150), Vector3(0.012, 0.024, 0.030), Vector3(0.0, 0.0, 0.0018), false],
	[Vector3(0.013, 1.692, 0.140), Vector3(0.010, 0.030, 0.030), Vector3(-0.0010, 0.0, 0.0), true],
	# ...narrower wings...
	[Vector3(0.018, 1.674, 0.138), Vector3(0.012, 0.013, 0.030), Vector3(-0.0005, 0.0, 0.0), true],
	# ...and longer, the tip lower and further out.
	[Vector3(0.0, 1.672, 0.160), Vector3(0.022, 0.012, 0.030), Vector3(0.0, -0.0010, 0.0010), false],
	# Less chin extension; a little lip volume, including the mouth parts.
	[Vector3(0.0, 1.600, 0.080), Vector3(0.090, 0.050, 0.120), Vector3(0.0, -0.0040, 0.0020), false],
	[Vector3(0.0, 1.643, 0.120), Vector3(0.026, 0.010, 0.025), Vector3(0.0, 0.0, 0.0015), false],
]
## Contour, painted as vertex colour on the face (CONTOUR_MATERIAL) the way a
## game face texture carries it -- the shape alone did not read at match
## distance (stage 8 review): darker eye sockets under the brow, the hollow
## under the cheekbones, the sides of the nose, the temples. [centre, radii,
## darkness 0-1, mirrored], in the same rest space as MOVES (centres before
## the sculpt moves them -- the field is applied to the rest positions).
const CONTOUR := [
	[Vector3(0.033, 1.722, 0.118), Vector3(0.022, 0.014, 0.030), 0.10, true],
	[Vector3(0.033, 1.733, 0.124), Vector3(0.024, 0.008, 0.030), 0.06, true],
	[Vector3(0.054, 1.662, 0.095), Vector3(0.024, 0.022, 0.040), 0.05, true],
	[Vector3(0.016, 1.690, 0.140), Vector3(0.008, 0.025, 0.030), 0.04, true],
	[Vector3(0.068, 1.735, 0.070), Vector3(0.020, 0.030, 0.040), 0.04, true],
]
## The face material the contour is written onto, and RomanModel turns
## vertex colour on for.
const CONTOUR_MATERIAL := "Material.001"


## How much darker the face is at rest-space `p`, 0-1.
static func contour_at(p: Vector3) -> float:
	var dark := 0.0
	for spot: Array in CONTOUR:
		var c: Vector3 = spot[0]
		var r: Vector3 = spot[1]
		for side in ([1.0, -1.0] if spot[3] else [1.0]):
			var q := (p - Vector3(c.x * side, c.y, c.z)) / r
			var k := 1.0 - q.length()
			if k <= 0.0:
				continue
			dark += float(spot[2]) * k * k * (3.0 - 2.0 * k)
	return clampf(dark, 0.0, 0.6)


## Meshes the field leaves alone (see above).
const FIXED := ["M_EYE", "M_Head_Caruncle", "eye_l", "eye_caruncle"]
## Finite-difference step for the Jacobian, metres.
const STEP := 0.0005


## The displacement at `p`.
static func offset(p: Vector3) -> Vector3:
	var d := Vector3.ZERO
	for move: Array in MOVES:
		var c: Vector3 = move[0]
		var r: Vector3 = move[1]
		var v: Vector3 = move[2]
		for side in ([1.0, -1.0] if move[3] else [1.0]):
			var cs := Vector3(c.x * side, c.y, c.z)
			var q := (p - cs) / r
			var k := 1.0 - q.length()
			if k <= 0.0:
				continue
			k = k * k * (3.0 - 2.0 * k)
			d += Vector3(v.x * side, v.y, v.z) * k
	return d


## Sculpts every mesh under `root`. Returns how many vertices moved.
static func apply(root: Node) -> int:
	var moved := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var source := mi.mesh as ArrayMesh
		if source == null or source.get_blend_shape_count() > 0 or _fixed(mi):
			continue
		var surfaces: Array = []
		var any := false
		for s in source.get_surface_count():
			var arrays := source.surface_get_arrays(s)
			var material := source.surface_get_material(s)
			if material and material.resource_name == CONTOUR_MATERIAL:
				paint_contour(arrays)
				any = true
			var n := sculpt(arrays)
			moved += n
			any = any or n > 0
			surfaces.append(arrays)
		if any:
			mi.mesh = BodyBulk.rebuilt(source, surfaces)
	return moved


## The contour as vertex colour (white elsewhere), off the rest positions.
static func paint_contour(arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		var v := 1.0 - contour_at(verts[i])
		colors[i] = Color(v, v, v, 1.0)
	arrays[Mesh.ARRAY_COLOR] = colors


static func _fixed(mi: MeshInstance3D) -> bool:
	for name: String in FIXED:
		if String(mi.name).contains(name) or String(mi.mesh.resource_name).contains(name):
			return true
	return false


## Moves one surface's vertices, normals and tangents through the field.
static func sculpt(arrays: Array) -> int:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	var tangents = arrays[Mesh.ARRAY_TANGENT]
	var moved := 0
	for i in verts.size():
		var p := verts[i]
		var d := offset(p)
		if d.length_squared() < 1e-12:
			continue
		# The field's Jacobian, by central differences.
		var j := Basis(
				Vector3.RIGHT + (offset(p + Vector3.RIGHT * STEP) - offset(p - Vector3.RIGHT * STEP)) / (2.0 * STEP),
				Vector3.UP + (offset(p + Vector3.UP * STEP) - offset(p - Vector3.UP * STEP)) / (2.0 * STEP),
				Vector3.BACK + (offset(p + Vector3.BACK * STEP) - offset(p - Vector3.BACK * STEP)) / (2.0 * STEP))
		verts[i] = p + d
		if normals != null and i < (normals as PackedVector3Array).size():
			normals[i] = (j.inverse().transposed() * (normals[i] as Vector3)).normalized()
		if tangents != null and (tangents as PackedFloat32Array).size() >= (i + 1) * 4:
			var t := j * Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])
			t = t.normalized()
			tangents[i * 4] = t.x
			tangents[i * 4 + 1] = t.y
			tangents[i * 4 + 2] = t.z
		moved += 1
	arrays[Mesh.ARRAY_VERTEX] = verts
	if normals != null:
		arrays[Mesh.ARRAY_NORMAL] = normals
	if tangents != null:
		arrays[Mesh.ARRAY_TANGENT] = tangents
	return moved
