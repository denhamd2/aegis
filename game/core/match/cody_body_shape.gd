class_name CodyBodyShape
extends RefCounted
## Cody's yoke at rest (the owner, 10 Nov: "Review Cody's body shape around
## his arms neck and shoulders, still doesn't look like right proportions").
##
## Measured off the supplied mesh: the top of the shoulder is a shelf. From
## the side of the neck (x 0.06) out past the shoulder joint (x 0.24) the skin
## stays at 1.55-1.59 m, 11-14 cm above the joint (1.44 m), and it is higher
## 10 cm out than on the centre line. On a man the trapezius falls from the
## neck to the point of the shoulder, which sits about 5 cm above the joint.
## That shelf is what read as no neck and a hanger for shoulders, and what
## stood up as horns when he leaned forward on the top rope.
##
## The same smooth ellipsoid field RomanFaceShape sculpts with, in the body's
## rest space: [centre, radii, move, mirrored]. Rest geometry only -- bones,
## weights and every clip are untouched.
const MOVES := [
	# The whole shelf from the side of the neck to the point of the shoulder,
	# down: one broad field, so the deltoid keeps its cap and no step is left
	# where a narrower one ended.
	[Vector3(0.190, 1.590, -0.150), Vector3(0.200, 0.130, 0.230), Vector3(0.0, -0.034, 0.0), true],
	# The side of the neck in, so it stands clear of the trapezius.
	[Vector3(0.078, 1.615, -0.120), Vector3(0.045, 0.055, 0.100), Vector3(-0.007, 0.0, 0.0), true],
]


## Sculpts every skinned mesh under `root`. Returns how many vertices moved.
static func apply(root: Node) -> int:
	var moved := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var source := mi.mesh as ArrayMesh
		if source == null or source.get_blend_shape_count() > 0 or mi.skin == null:
			continue
		var surfaces: Array = []
		var any := false
		for s in source.get_surface_count():
			var arrays := source.surface_get_arrays(s)
			var n := RomanFaceShape.sculpt(arrays, MOVES)
			moved += n
			any = any or n > 0
			surfaces.append(arrays)
		if any:
			mi.mesh = BodyBulk.rebuilt(source, surfaces)
	return moved
