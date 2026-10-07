class_name RomanFaceShape
extends RefCounted
## Sculpts Roman's face toward 2K26's, at load (the owner: "fix Roman's face
## shape"; gauntlet/refs/characters/review/roman_face_shape_2k26.jpg).
##
## Against the 2K26 close-ups (cody_roman_2k26.mp4, 214-218 s) ours read wide
## and round: puffy cheeks, a short broad nose, eyes sitting flush under a
## flat brow, a short jaw. His is long and lean -- a heavy low brow ridge
## with the eyes deep-set and narrowed under it, high cheekbones with a
## hollow beneath, a long straight nose and a long chin under the beard.
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
	# The brow ridge: forward and down over each eye, and at the glabella --
	# the heavy, low brow, hooding the eyes under it.
	[Vector3(0.031, 1.738, 0.125), Vector3(0.032, 0.014, 0.035), Vector3(0.0, -0.0045, 0.0070), true],
	[Vector3(0.0, 1.735, 0.140), Vector3(0.016, 0.012, 0.030), Vector3(0.0, -0.002, 0.0045), false],
	# High cheekbones, out and up a little...
	[Vector3(0.056, 1.699, 0.095), Vector3(0.022, 0.015, 0.032), Vector3(0.0030, 0.0015, 0.0020), true],
	# ...and the hollow under them.
	[Vector3(0.054, 1.662, 0.095), Vector3(0.024, 0.020, 0.036), Vector3(-0.0070, 0.0, -0.0040), true],
	# Less width at the side of the face and the jaw: long and lean, not round.
	[Vector3(0.072, 1.675, 0.060), Vector3(0.032, 0.045, 0.065), Vector3(-0.0080, 0.0, 0.0), true],
	[Vector3(0.062, 1.625, 0.060), Vector3(0.030, 0.035, 0.065), Vector3(-0.0060, 0.0, 0.0), true],
	# The nose: a higher, narrower bridge...
	[Vector3(0.0, 1.700, 0.150), Vector3(0.012, 0.024, 0.030), Vector3(0.0, 0.0, 0.0035), false],
	[Vector3(0.013, 1.692, 0.140), Vector3(0.010, 0.030, 0.030), Vector3(-0.0030, 0.0, 0.0), true],
	# ...narrower wings...
	[Vector3(0.018, 1.674, 0.138), Vector3(0.012, 0.013, 0.030), Vector3(-0.0035, 0.0, 0.0), true],
	# ...and longer, the tip lower and further out.
	[Vector3(0.0, 1.672, 0.160), Vector3(0.022, 0.012, 0.030), Vector3(0.0, -0.0035, 0.0025), false],
	# The long jaw and chin, beard and all.
	[Vector3(0.0, 1.600, 0.080), Vector3(0.090, 0.050, 0.120), Vector3(0.0, -0.0120, 0.0040), false],
]
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
			var n := sculpt(arrays)
			moved += n
			any = any or n > 0
			surfaces.append(arrays)
		if any:
			mi.mesh = BodyBulk.rebuilt(source, surfaces)
	return moved


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
