class_name KennyFaceShape
extends RefCounted
## Kenny's face on Cody's head, at load (gauntlet/refs/characters/review/
## kenny_face_judge.md, run 5). At matched pupil distance Cody's head already
## lands Kenny's eye line, nose base, mouth, chin and face width within a few
## pixels of the sheet's front head shot; what does not land is the form:
## Kenny's eyes are hooded and narrow under a low, level brow, his cheeks are
## full under the eyes, his nose bridge is broad and its tip hangs, and his
## mouth is narrow. Cody's are open, frowning, hollow-cheeked and wide.
##
## Each move is a smooth bump in the model's rest space (metres; x across him,
## y up, z forward), applied by RomanFaceShape's sculpt so normals follow the
## new shape. Cody's head is not centred on x = 0: his eyes sit at x 0.0359
## and -0.0281, so the moves mirror about MIDLINE_X. Only the head's skin
## surface moves -- the eyeballs turn about their bones and stay put, so the
## eyes are hooded by the lid and brow coming down over them, not by moving
## the eyes. Every bump is clear of y 1.62 and of the scalp, so the neck seam
## and the curls' cap (built on the unshaped scalp) are untouched.

const MIDLINE_X := 0.004
## [centre (x from the midline), radii, displacement (x outward), mirrored].
const TABLE := [
	# The upper lid down over the eye, and out with it so the margin stays on
	# the eyeball's curve: hooded, the sheet's squint. At half this (run 5)
	# the change did not read.
	[Vector3(0.032, 1.7235, -0.012), Vector3(0.017, 0.007, 0.012), Vector3(0.0, -0.0028, 0.0014), true],
	# The brow lower and level at its outer end, a little forward over the
	# lid...
	[Vector3(0.028, 1.738, 0.0), Vector3(0.024, 0.012, 0.030), Vector3(0.0, -0.0015, 0.0012), true],
	# ...and up at its inner end: Cody's resting frown is not Kenny's.
	[Vector3(0.010, 1.737, 0.004), Vector3(0.012, 0.010, 0.020), Vector3(0.0, 0.0012, 0.0), true],
	# Fuller under the eyes...
	[Vector3(0.045, 1.680, -0.020), Vector3(0.022, 0.020, 0.030), Vector3(0.0025, 0.0, 0.0035), true],
	# ...and the cheek hollow filled.
	[Vector3(0.055, 1.655, -0.030), Vector3(0.024, 0.022, 0.035), Vector3(0.0030, 0.0, 0.0030), true],
	# A broader nose bridge.
	[Vector3(0.009, 1.700, 0.008), Vector3(0.008, 0.020, 0.015), Vector3(0.0010, 0.0, 0.0), true],
	# The tip down a little over the nostrils: the sheet's hangs and hides
	# them, Cody's shows two dark holes.
	[Vector3(0.0, 1.668, 0.020), Vector3(0.014, 0.010, 0.014), Vector3(0.0, -0.0015, 0.0), false],
	# A narrower mouth: at matched pupil distance the sheet's is about 0.72
	# of the eyes' spacing, Cody's about 1.0. The corners in.
	[Vector3(0.027, 1.640, -0.008), Vector3(0.014, 0.010, 0.016), Vector3(-0.0040, 0.0, 0.0010), true],
	# A second, gentler pull just inside it, so the corner moves about 6 mm
	# in all while every vertex keeps its order across the lips (one bump
	# twice as strong folded them over each other).
	[Vector3(0.024, 1.640, -0.006), Vector3(0.012, 0.009, 0.014), Vector3(-0.0020, 0.0, 0.0), true],
	# And the deep crease at Cody's mouth corners filled: its shadow carried
	# the line of the lips on past them (run 7).
	[Vector3(0.032, 1.639, -0.012), Vector3(0.008, 0.007, 0.010), Vector3(0.0, 0.0, 0.0015), true],
]
## The head's skin, the only surface shaped.
const SKIN_MATERIAL := "xmaterial_c3d4d9e78b44a79"

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


## Shapes the head's skin surface of every mesh under `root`. Returns how
## many vertices moved.
static func apply(root: Node) -> int:
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
			if material and material.resource_name == SKIN_MATERIAL:
				var n := RomanFaceShape.sculpt(arrays, moves())
				moved += n
				any = any or n > 0
			surfaces.append(arrays)
		if any:
			mi.mesh = BodyBulk.rebuilt(source, surfaces)
	return moved
