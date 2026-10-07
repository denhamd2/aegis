class_name BodyBulk
extends RefCounted
## Builds muscle onto a supplied body, at load (gauntlet/refs/characters/review,
## the owner's 2K26 comparison): Cody's upper arms, shoulders and chest, and
## Roman's, read far slighter than 2K26's -- the owner: "are Cody's arms too
## thin and long?". Measured, the arm bones are not long (shoulder to wrist
## 0.30 of his height, a real man's ~0.33); they read long because they are
## thin, on shoulders 0.38 m (Cody) and 0.36 m (Roman) apart.
##
## Each skinned vertex moves out along its own normal by the sum, over the
## bones it follows, of that bone's weight times the bone's gain in metres. A
## vertex that follows only the upper arm moves its full gain; one blended
## half into the forearm, half that and half the forearm's -- so the bulk
## fades across every joint exactly as the skinning does, with no seam. The
## head, hair, face and feet follow none of these bones and do not move.
##
## Rest-pose geometry only: the bones, their lengths and the animation are
## untouched, so every grip, contact and clearance measured off the skeleton
## still holds. The supplied .glb is never edited (CREDITS.md); this is
## presentation, applied once when the model loads.

## Bone name -> metres outward at full weight.
const CODY := {
	"upperarm_l": 0.016, "upperarm_r": 0.016,
	"lowerarm_l": 0.007, "lowerarm_r": 0.007,
	"clavicle_l": 0.012, "clavicle_r": 0.012,
	"spine_03": 0.007,
}
const ROMAN := {
	# Heavier than Cody's: 2K26's Roman is the bigger, thicker-armed man.
	"J_Shoulder_L": 0.026, "J_Shoulder_R": 0.026,
	"H_Delt_L_OS01": 0.020, "H_Delt_R_OS01": 0.020,
	"J_Elbow_L": 0.011, "J_Elbow_R": 0.011,
	"H_Elbow_L_tw01": 0.011, "H_Elbow_R_tw01": 0.011,
	"H_Elbow_L_tw02": 0.011, "H_Elbow_R_tw02": 0.011,
	"J_Clavicle_L": 0.012, "J_Clavicle_R": 0.012,
	"H_TrapBase_L": 0.010, "H_TrapBase_R": 0.010,
	"J_Chest": 0.008,
}


## Inflates every skinned mesh under `root` bound to `skeleton`. Returns how
## many vertices moved.
static func apply(root: Node, skeleton: Skeleton3D, gains: Dictionary) -> int:
	if skeleton == null:
		return 0
	var gain_of_bone := {}
	for name: String in gains:
		var b := skeleton.find_bone(name)
		if b >= 0:
			gain_of_bone[b] = float(gains[name])
	if gain_of_bone.is_empty():
		return 0
	var moved := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var source := mi.mesh as ArrayMesh
		if source == null or mi.skin == null or source.get_blend_shape_count() > 0:
			continue
		# Skin bind index -> the gain of the bone it binds.
		var bind_gain := {}
		for i in mi.skin.get_bind_count():
			var bone := mi.skin.get_bind_bone(i)
			var name := mi.skin.get_bind_name(i)
			if name != "":
				bone = skeleton.find_bone(name)
			if gain_of_bone.has(bone):
				bind_gain[i] = gain_of_bone[bone]
		if bind_gain.is_empty():
			continue
		var surfaces: Array = []
		var any := false
		for s in source.get_surface_count():
			var arrays := source.surface_get_arrays(s)
			var n := inflate(arrays, bind_gain)
			moved += n
			any = any or n > 0
			surfaces.append(arrays)
		if any:
			mi.mesh = _rebuilt(source, surfaces)
	return moved


## Moves each vertex of one surface's arrays out along its normal; returns how
## many moved. Public for the test.
static func inflate(arrays: Array, bind_gain: Dictionary) -> int:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	if normals == null or bones == null or weights == null or verts.is_empty():
		return 0
	var per: int = (bones as PackedInt32Array).size() / verts.size()
	var moved := 0
	for v in verts.size():
		var d := 0.0
		for j in per:
			var k: int = bones[v * per + j]
			if bind_gain.has(k):
				d += float(weights[v * per + j]) * float(bind_gain[k])
		if d > 1e-5:
			verts[v] += (normals[v] as Vector3) * d
			moved += 1
	arrays[Mesh.ARRAY_VERTEX] = verts
	return moved


static func _rebuilt(source: ArrayMesh, surfaces: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in source.get_surface_count():
		var flags := source.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(s), surfaces[s],
				[], {}, flags)
		mesh.surface_set_material(s, source.surface_get_material(s))
		mesh.surface_set_name(s, source.surface_get_name(s))
	return mesh
