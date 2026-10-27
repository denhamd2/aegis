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
## Kenny, on Cody's model: leaner than Cody -- the sheet's turnaround is a
## cut, athletic build, not a heavyweight's -- so about half Cody's gains.
const KENNY := {
	"upperarm_l": 0.008, "upperarm_r": 0.008,
	"lowerarm_l": 0.004, "lowerarm_r": 0.004,
	"clavicle_l": 0.006, "clavicle_r": 0.006,
	"spine_03": 0.003,
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
## many vertices moved. `inward` names, per mesh, the surfaces whose normals
## face the body (a garment's lining), which move against their normals so
## they go out with the rest.
static func apply(root: Node, skeleton: Skeleton3D, gains: Dictionary,
		inward: Dictionary = {}) -> int:
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
			var flip: Array = inward.get(String(mi.name), [])
			var n := inflate(arrays, bind_gain, -1.0 if flip.has(s) else 1.0)
			moved += n
			any = any or n > 0
			surfaces.append(arrays)
		if any:
			mi.mesh = rebuilt(source, surfaces)
	return moved


## Mends a mirror seam: vertices that share a position inside one surface but
## carry normals pointing opposite ways (dot below FLIPPED). Cody's head-and-
## torso surface has 208 of them down his centre line (x ~ 0) -- the supplied
## statue was modelled as a half and mirrored, and one side's seam normals
## were left facing in. Lit, the flipped copy drew a bright line down the
## middle of his back; inflated, the two copies went opposite ways and the
## seam opened (the owner, 20 Oct, the celebration close-ups). Each such
## group takes the one normal that faces out from the surface's centre, so it
## shades as one surface and inflates as one. Returns how many vertices were
## mended. Run before apply().
const FLIPPED := 0.0
const WELD_GRID := 2000.0
## Only on the mirror line: a flipped pair anywhere else (inside the mouth,
## round an eyelid) faces in on purpose.
const MIRROR_BAND := 0.03


static func mend_flipped_seams(root: Node) -> int:
	var mended := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var source := mi.mesh as ArrayMesh
		if source == null or source.get_blend_shape_count() > 0:
			continue
		var surfaces: Array = []
		var any := false
		for si in source.get_surface_count():
			var arrays := source.surface_get_arrays(si)
			var n := _mend_surface(arrays)
			mended += n
			any = any or n > 0
			surfaces.append(arrays)
		if any:
			var mesh := rebuilt(source, surfaces)
			mesh.custom_aabb = source.custom_aabb
			mi.mesh = mesh
	return mended


static func _mend_surface(arrays: Array) -> int:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	var tangents = arrays[Mesh.ARRAY_TANGENT]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	if normals == null or verts.is_empty():
		return 0
	var per := 0
	if bones != null and weights != null and (bones as PackedInt32Array).size() % verts.size() == 0:
		per = (bones as PackedInt32Array).size() / verts.size()
	var groups := {}
	var centre := Vector3.ZERO
	for v in verts.size():
		centre += verts[v]
		var key := Vector3i(roundi(verts[v].x * WELD_GRID), roundi(verts[v].y * WELD_GRID),
				roundi(verts[v].z * WELD_GRID))
		if groups.has(key):
			(groups[key] as Array).append(v)
		else:
			groups[key] = [v]
	centre /= float(verts.size())
	var mended := 0
	for key in groups:
		var members: Array = groups[key]
		if members.size() < 2 or absf((verts[members[0]] as Vector3).x) > MIRROR_BAND:
			continue
		# One set of weights for the copies: each half's copy took its weights
		# off its own side of the mannequin, so a raised arm or a turned
		# shoulder pulled the halves apart and the crowd showed through his
		# back. Averaged, the copies move as one vertex.
		if per > 0 and _unify_weights(bones, weights, members, per):
			mended += members.size()
		var flipped := false
		for a in members.size():
			for b in range(a + 1, members.size()):
				if (normals[members[a]] as Vector3).dot(normals[members[b]]) < FLIPPED:
					flipped = true
		if not flipped:
			continue
		# Out from the surface's middle, level: a torso's sides and back.
		var at: Vector3 = verts[members[0]]
		var out := Vector3(at.x - centre.x, 0.0, at.z - centre.z)
		var pick: int = members[0]
		for m: int in members:
			if (normals[m] as Vector3).dot(out) > (normals[pick] as Vector3).dot(out):
				pick = m
		for m: int in members:
			if m == pick or (normals[m] as Vector3).is_equal_approx(normals[pick]):
				continue
			normals[m] = normals[pick]
			if tangents != null and (tangents as PackedFloat32Array).size() >= verts.size() * 4:
				for c in 4:
					tangents[m * 4 + c] = tangents[pick * 4 + c]
			mended += 1
	arrays[Mesh.ARRAY_NORMAL] = normals
	if tangents != null:
		arrays[Mesh.ARRAY_TANGENT] = tangents
	if per > 0:
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	return mended


## Gives every vertex in `members` the same skin: the mean of their weights,
## the strongest `per` bones of it, renormalised. Returns whether any changed.
static func _unify_weights(bones: PackedInt32Array, weights: PackedFloat32Array,
		members: Array, per: int) -> bool:
	var sum := {}
	for m: int in members:
		for k in per:
			var w := weights[m * per + k]
			if w > 0.0:
				sum[bones[m * per + k]] = float(sum.get(bones[m * per + k], 0.0)) + w
	var order := sum.keys()
	order.sort_custom(func(a, b): return sum[a] > sum[b] or (sum[a] == sum[b] and a < b))
	order = order.slice(0, per)
	var total := 0.0
	for b in order:
		total += sum[b]
	if total <= 0.0:
		return false
	var changed := false
	for m: int in members:
		# Already this skin, in any slot order?
		var same := true
		for k in per:
			var w := weights[m * per + k]
			var want: float = sum[bones[m * per + k]] / total \
					if order.has(bones[m * per + k]) else 0.0
			if absf(w - want) > 1e-4:
				same = false
		if same:
			continue
		changed = true
		for k in per:
			bones[m * per + k] = order[k] if k < order.size() else 0
			weights[m * per + k] = sum[order[k]] / total if k < order.size() else 0.0
	return changed


## Moves each vertex of one surface's arrays out along its normal; returns how
## many moved. Public for the test.
static func inflate(arrays: Array, bind_gain: Dictionary, direction := 1.0) -> int:
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
			verts[v] += (normals[v] as Vector3) * d * direction
			moved += 1
	arrays[Mesh.ARRAY_VERTEX] = verts
	return moved


static func rebuilt(source: ArrayMesh, surfaces: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in source.get_surface_count():
		var flags := source.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(s), surfaces[s],
				[], {}, flags)
		mesh.surface_set_material(s, source.surface_get_material(s))
		mesh.surface_set_name(s, source.surface_get_name(s))
	return mesh
