class_name RomanBeardGroom
extends RefCounted
## Curved fibre cards sampled on the already fitted beard. Each card copies
## the source skin bindings, so both of Roman's skeletons retain their roles.
## The photographed-looking underpaint supplies the short cheek transition.
const ATLAS := "res://assets/characters/roman_reigns_beard_groom.png"
const CARDS := 1800
const SEGMENTS := 3
const SEED := 161036


static func build(source: MeshInstance3D, surface: int) -> MeshInstance3D:
	var arrays := source.mesh.surface_get_arrays(surface)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var source_bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var source_weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences := source_bones.size() / positions.size()
	if influences not in [4, 8]:
		return null
	var triangles: Array[Vector3i] = []
	var cumulative := PackedFloat32Array()
	var area := 0.0
	var lip_y := 1.644 + RomanFaceShape.offset(Vector3(0, 1.644, .130)).y
	for offset in range(0, indices.size(), 3):
		var tri := Vector3i(indices[offset], indices[offset + 1], indices[offset + 2])
		var centre := (positions[tri.x] + positions[tri.y] + positions[tri.z]) / 3.0
		# Brows stay in the albedo. Keep fibres out of the lips and ears.
		if centre.y > 1.681 or centre.y < 1.57 or centre.z < .008:
			continue
		if absf(centre.x) < .025 and absf(centre.y - lip_y) < .007:
			continue
		var weight := (positions[tri.y] - positions[tri.x]).cross(positions[tri.z] - positions[tri.x]).length() * .5
		if weight <= .00000001:
			continue
		area += weight
		triangles.append(tri)
		cumulative.append(area)
	if area <= 0:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if influences == 8:
		st.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
	for card in CARDS:
		var tri := triangles[mini(cumulative.bsearch(rng.randf() * area), triangles.size() - 1)]
		var a := sqrt(rng.randf())
		var bary := Vector3(1.0 - a, a * (1.0 - rng.randf()), 0)
		bary.z = 1.0 - bary.x - bary.y
		var root := positions[tri.x] * bary.x + positions[tri.y] * bary.y + positions[tri.z] * bary.z
		# A continuous beard-volume normal, rather than each old card's plane.
		var normal := (root - Vector3(0, 1.685, .015)).normalized()
		var flow := Vector3(root.x * 2.0, -1, -.12)
		if root.y > 1.65 and absf(root.x) < .04:
			flow = Vector3(signf(root.x) * .85, -.40, .02)
		flow = (flow - normal * flow.dot(normal) + normal * .12).normalized()
		var across := flow.cross(normal).normalized()
		var width := rng.randf_range(.0015, .0030)
		var length := rng.randf_range(.004, .010)
		if root.y < 1.615:
			length = rng.randf_range(.004, .012)
		elif root.y > 1.65 and absf(root.x) < .04:
			length = rng.randf_range(.003, .006)
		var cell := rng.randi_range(0, 7)
		var closest := tri.x if bary.x >= maxf(bary.y, bary.z) else (tri.y if bary.y >= bary.z else tri.z)
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		for influence in influences:
			bones.append(source_bones[closest * influences + influence])
			weights.append(source_weights[closest * influences + influence])
		for segment in SEGMENTS:
			for corner: Vector2 in [Vector2(0, 0), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)]:
				var t := (segment + corner.y) / float(SEGMENTS)
				var taper := 1.0 - .65 * t * t
				var point := root + flow * length * t + normal * (.0005 + .0020 * sin(t * PI))
				# Curl ends back into the volume instead of a vertical fringe.
				point -= normal * .0015 * t * t
				point += across * ((corner.x - .5) * width * taper)
				st.set_normal(normal)
				st.set_uv(Vector2((cell + corner.x) / 8.0, t))
				st.set_bones(bones)
				st.set_weights(weights)
				st.add_vertex(point)
	st.generate_tangents()
	var groom := MeshInstance3D.new()
	groom.name = "BeardGroom"
	groom.mesh = st.commit()
	groom.skin = source.skin
	groom.transform = source.transform
	source.get_parent().add_child(groom)
	groom.skeleton = groom.get_path_to(source.get_node(source.skeleton))
	groom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.resource_name = "RomanBeardFibres"
	material.albedo_texture = load(ATLAS)
	material.roughness = .78
	material.metallic_specular = .10
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	HairLook.apply(material, Vector2(1, 0), .35)
	groom.material_override = material
	return groom
