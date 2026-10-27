extends GdUnitTestSuite
## Guards KennyModel: Kenny Omega built on Cody's model.
##
## The owner, 27 Oct: "use Cody's body for Kenny and adjust it to Kenny, eg,
## skin shade, no Cody tattoos". So KennyModel is CodyModel -- the same mesh,
## rig, animations and adapter -- with Kenny's skin, face, eyes, gear and hair
## swapped in at load. These tests pin both halves: that he still IS Cody's
## working rig, and that none of Cody shows through.

const MODEL := "res://scenes/kenny_model.tscn"
const BASE_RIG := "res://assets/characters/wrestler_base.glb"
const CHAR := "res://assets/characters/"


func _model() -> KennyModel:
	var model := auto_free(load(MODEL).instantiate()) as KennyModel
	add_child(model)
	return model


func _surfaces(model: Node, materials: Array) -> Array[BaseMaterial3D]:
	var out: Array[BaseMaterial3D] = []
	for mi: MeshInstance3D in model.find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface)
			if source and materials.has(source.resource_name):
				out.append(mi.get_surface_override_material(surface) as BaseMaterial3D)
	return out


## Built on Cody's model, not a mesh of his own: the scene instances Cody's
## .glb and the script is a CodyModel.
func test_is_built_on_codys_model() -> void:
	var model := _model()
	assert_bool(model is CodyModel).is_true()
	var scene := load(MODEL) as PackedScene
	var paths: Array[String] = []
	for i in scene.get_state().get_node_count():
		var inst := scene.get_state().get_node_instance(i)
		if inst:
			paths.append(inst.resource_path)
	assert_array(paths).contains([CHAR + "cody_rhodes.glb"])


## The animation tracks resolve against the base rig's bone names: if any is
## missing the wrestler goes inert, silently.
func test_skeleton_is_the_base_rigs_bones() -> void:
	var skeleton := _model().get_game_skeleton()
	assert_object(skeleton).is_not_null()
	var base: Node = auto_free(load(BASE_RIG).instantiate())
	var base_skeleton := base.find_children("", "Skeleton3D", true, false)[0] as Skeleton3D
	for index in base_skeleton.get_bone_count():
		var bone := base_skeleton.get_bone_name(index)
		assert_int(skeleton.find_bone(bone)) \
			.override_failure_message("bone '%s' is missing from Kenny's rig" % bone) \
			.is_greater_equal(0)


## One skeleton: his curls are skinned to it rather than bringing their own.
func test_is_rigged_on_a_single_skeleton() -> void:
	assert_int(_model().find_children("", "Skeleton3D", true, false).size()).is_equal(1)


## Every mesh under the skeleton -- body and curls -- is skinned; an
## unweighted one stays at the origin while he walks away.
func test_meshes_are_skinned() -> void:
	var skeleton := _model().get_game_skeleton()
	var meshes := skeleton.find_children("", "MeshInstance3D", true, false)
	assert_int(meshes.size()).is_greater(1)
	for node in meshes:
		assert_object((node as MeshInstance3D).skin) \
			.override_failure_message("%s has no skin" % node.name).is_not_null()


func test_animations_are_installed() -> void:
	var player := _model().get_node("AnimationPlayer") as AnimationPlayer
	assert_bool(player.has_animation("Idle")).is_true()


## He wrestles in the model's own gear, repainted: the procedural trunks stay off.
func test_does_not_use_universal_attire() -> void:
	assert_bool(_model().uses_universal_attire()).is_false()


## Every skin surface wears Kenny's atlas, not Cody's (tools/assets/
## build_kenny_textures.py), at Kenny's fairer tint.
func test_skin_is_kennys() -> void:
	var model := _model()
	var surfaces := _surfaces(model, KennyModel.SKIN_TEXTURES.keys())
	assert_int(surfaces.size()).is_greater_equal(KennyModel.SKIN_TEXTURES.size())
	for mat in surfaces:
		assert_object(mat).is_not_null()
		assert_str(mat.albedo_texture.resource_path).starts_with(CHAR + "kenny_")
		assert_float(mat.albedo_color.r).is_equal_approx(KennyModel.KENNY_SKIN_TINT.r, 0.001)


## Cody's tattoos are gone: no dark ink left where "Dream" was on his chest or
## where the skull-and-flag was on his neck. Ink is far darker than the skin
## round it; cloned skin is not. The neck patch is the tattoo's lower part:
## his beard now reaches round the jaw's corner into its upper part, and a
## beard hair is as dark as ink.
func test_codys_tattoos_are_gone() -> void:
	for spot: Array in [["kenny_body_chest.png", Rect2(0.54, 0.29, 0.10, 0.18)],
			["kenny_head.png", Rect2(0.17, 0.80, 0.13, 0.12)]]:
		var image := (load(CHAR + spot[0]) as Texture2D).get_image()
		if image.is_compressed():
			image.decompress()
		var rect: Rect2 = spot[1]
		var lums: Array[float] = []
		# The head atlas's alpha is sparse round the neck: sample densely and
		# keep what the island covers.
		for i in 1200:
			var x := int((rect.position.x + rect.size.x * fmod(i * 0.618, 1.0)) * image.get_width())
			var y := int((rect.position.y + rect.size.y * (i / 1200.0)) * image.get_height())
			var c := image.get_pixel(x, y)
			if c.a > 0.5:
				lums.append(c.get_luminance())
		lums.sort()
		assert_int(lums.size()).is_greater(200)
		var median := lums[lums.size() / 2]
		assert_float(lums[int(lums.size() * 0.03)]) \
			.override_failure_message("ink left in %s: %.2f against skin %.2f" % [spot[0],
				lums[int(lums.size() * 0.03)], median]) \
			.is_greater(median * 0.6)


## His gear is repainted: every gear surface wears Kenny's atlas.
func test_gear_is_kennys() -> void:
	var surfaces := _surfaces(_model(), KennyModel.GEAR_TEXTURES.keys())
	assert_int(surfaces.size()).is_greater_equal(KennyModel.GEAR_TEXTURES.size())
	for mat in surfaces:
		assert_object(mat).is_not_null()
		assert_str(mat.albedo_texture.resource_path).starts_with(CHAR + "kenny_gear_")


## His own eye maps. The owner, 27 Oct: "his eyes don't match with the
## reference. Ours looks glowing and slightly wrong color." The sheet's iris is
## grey-blue and sits darker than the white of his eye; the first pass's was a
## pale periwinkle that rendered 1.7x his sclera under match light. Too dark,
## though, and the socket's shade took it to black (kenny_face_judge.md).
## Measured on the map: the iris near grey (no channel more than 15% over
## another), no brighter than the white beside it, and not under 0.6 of it.
func test_eyes_are_kennys() -> void:
	var model := _model()
	var eyes := _surfaces(model, [CodyModel.EYE_MATERIAL])
	assert_int(eyes.size()).is_greater(0)
	for mat in eyes:
		if mat:
			assert_str(mat.albedo_texture.resource_path).is_equal(CHAR + "kenny_eye_color.png")
	var image := (load(CHAR + "kenny_eye_color.png") as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var size := image.get_width()
	var iris := Color(0, 0, 0)
	var white := Color(0, 0, 0)
	for i in 64:
		var angle := TAU * i / 64.0
		# 4 mm out (inside the iris, outside the pupil) and 7 mm out (the white,
		# inside the lids' shading), on a 30.5 mm map centred on the line of sight.
		iris += image.get_pixel(int(size * (0.5 + 4.0 / 30.5 * cos(angle))),
				int(size * (0.5 + 4.0 / 30.5 * sin(angle)))) / 64.0
		white += image.get_pixel(int(size * (0.5 + 7.0 / 30.5 * cos(angle))),
				int(size * (0.5 + 7.0 / 30.5 * sin(angle)))) / 64.0
	assert_float(maxf(iris.r, maxf(iris.g, iris.b)) / minf(iris.r, minf(iris.g, iris.b))).is_less(1.15)
	assert_float(iris.get_luminance()).is_less_equal(white.get_luminance())
	assert_float(iris.get_luminance()).is_greater(white.get_luminance() * 0.6)


## Degrees round his head from the front, either side (the head's vertical
## axis sits at z -0.09; he faces +Z).
func _round_from_front(v: Vector3) -> float:
	return rad_to_deg(absf(atan2(v.x, v.z + 0.09)))


## The owner, 27 Oct: "The beard on the side of his face doesn't look right."
## It stopped mid-cheek in a straight edge, short of the ear. The sheet's runs
## along the whole jaw into the sideburns: on the head atlas, his jaw just in
## front of the ear is beard-dark against the bare upper cheek, on both sides.
## Measured over the texels: 0.82-0.84 of the cheek with the beard, 1.09-1.10
## with none.
func test_the_beard_runs_along_the_jaw_to_the_ear() -> void:
	var model := _model()
	var image := (load(CHAR + "kenny_head.png") as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var jaw := {-1.0: [] as Array[float], 1.0: [] as Array[float]}
	var cheek: Array[float] = []
	for mi: MeshInstance3D in model.find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(s)
			if source == null or source.resource_name != "xmaterial_c3d4d9e78b44a79":
				continue
			var arrays := mi.mesh.surface_get_arrays(s)
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				var v := verts[i]
				var angle := _round_from_front(v)
				var uv := uvs[i]
				var lum := image.get_pixel(clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1),
						clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)).get_luminance()
				if angle > 75.0 and angle < 88.0 and v.y > 1.62 and v.y < 1.65:
					jaw[signf(v.x)].append(lum)
				elif angle > 30.0 and angle < 50.0 and v.y > 1.705 and v.y < 1.725:
					cheek.append(lum)
	assert_int(cheek.size()).is_greater(10)
	var bare := 0.0
	for l in cheek:
		bare += l / cheek.size()
	for side: float in jaw:
		var lums: Array = jaw[side]
		assert_int(lums.size()).is_greater(5)
		var mean := 0.0
		for l: float in lums:
			mean += l / lums.size()
		assert_float(mean) \
			.override_failure_message("no beard on the %s jaw by the ear: %.2f against cheek %.2f"
				% ["left" if side > 0 else "right", mean, bare]) \
			.is_less(bare * 0.95)


## His hairline recedes at the temples into a soft M (KennyModel's curls and
## head texture share build_kenny_textures.HAIRLINE): no hair cap over the
## temple corners below 1.79 m, where Cody's flat crop ran to 1.787.
func test_the_hairline_recedes_at_the_temples() -> void:
	var lowest := INF
	var count := 0
	for v: Vector3 in _hair(_model(), "CurlCap").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var angle := _round_from_front(v)
		if angle > 25.0 and angle < 42.0:
			lowest = minf(lowest, v.y)
			count += 1
	assert_int(count).is_greater(10)
	assert_float(lowest).is_greater(1.79)


## His face is reshaped from Cody's (KennyFaceShape, judge run 5): the upper
## lids come down over the eyes -- hooded, the sheet's squint -- and nothing
## below his jaw moves, so the neck seam and the body hold.
func test_his_face_is_shaped_and_the_neck_is_not() -> void:
	var kenny := _head_vertices(_model())
	var cody_model := auto_free(load("res://scenes/cody_model.tscn").instantiate()) as Node
	add_child(cody_model)
	var cody := _head_vertices(cody_model)
	assert_int(kenny.size()).is_equal(cody.size())
	var lid := 0.0
	var lids := 0
	for i in kenny.size():
		var c: Vector3 = cody[i]
		var x := absf(c.x - KennyFaceShape.MIDLINE_X)
		if x > 0.025 and x < 0.039 and c.y > 1.721 and c.y < 1.726 and c.z > -0.02:
			lid += (kenny[i].y - c.y)
			lids += 1
	assert_int(lids).is_greater(4)
	# Every move is clear of the neck (the body bulk moves the neck on its own,
	# differently for Kenny and Cody, so the table is what is checked).
	for row: Array in KennyFaceShape.TABLE:
		assert_float((row[0] as Vector3).y - (row[1] as Vector3).y).is_greater(1.62)
	# 2.8 mm at the lid's centre, less across the band.
	assert_float(lid / lids).is_less(-0.001)


func _head_vertices(model: Node) -> PackedVector3Array:
	for mi: MeshInstance3D in model.find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(s)
			if source and source.resource_name == KennyFaceShape.SKIN_MATERIAL:
				return mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
	return PackedVector3Array()


func _hair(model: Node, hair_name: String) -> MeshInstance3D:
	return model.get_game_skeleton().find_child(hair_name, true, false) as MeshInstance3D


## Cody's short groom is gone; Kenny's curls are on, skinned to his skeleton.
func test_wears_kennys_curls_not_codys_groom() -> void:
	var model := _model()
	for hair_name in ["CurlCap", "CurlSlick", "CurlRinglets"]:
		assert_object(_hair(model, hair_name)) \
			.override_failure_message("no %s" % hair_name).is_not_null()
	for node in model.find_children("", "MeshInstance3D", true, false):
		assert_bool(String(node.name).contains("HairCard")) \
			.override_failure_message("Cody's groom is on him: %s" % node.name).is_false()


## The slick reaches over the top of the cap on both sides of the part: no
## bare painted helmet on the crown (kenny_aaa_plan.md gap 1).
func test_slick_covers_the_crown() -> void:
	var model := _model()
	var top := -INF
	for v: Vector3 in _hair(model, "CurlCap").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		top = maxf(top, v.y)
	var left := 0
	var right := 0
	for v: Vector3 in _hair(model, "CurlSlick").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if v.y > top - 0.03:
			if v.x > 0.0:
				left += 1
			else:
				right += 1
	assert_int(left).is_greater(100)
	assert_int(right).is_greater(100)


## The cap is the shadowed roots under the hair: matte, no stretched highlight.
## With HairLook's anisotropy the overhead key drew a pale band across his
## hairline (kenny pass 4).
func test_the_hair_cap_is_matte_roots() -> void:
	var mat := _hair(_model(), "CurlCap").material_override as BaseMaterial3D
	assert_object(mat).is_not_null()
	assert_bool(mat.anisotropy_enabled).is_false()
	assert_float(mat.metallic_specular).is_less_equal(0.1)
	assert_float(mat.roughness).is_greater_equal(0.85)


## The owner, 25 Oct: "His hair looks too big." Measured on the curls (2nd to
## 98th percentile, so a stray strand does not decide it): no wider than
## 0.27 m at ear height and nothing below his shoulders.
func test_the_hair_sits_close_to_his_head() -> void:
	var model := _model()
	var xs: Array[float] = []
	var lowest := INF
	for hair_name in ["CurlSlick", "CurlRinglets"]:
		for v: Vector3 in _hair(model, hair_name).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			lowest = minf(lowest, v.y)
			if v.y > 1.62 and v.y < 1.72:
				xs.append(v.x)
	xs.sort()
	var width := xs[int(xs.size() * 0.98)] - xs[int(xs.size() * 0.02)]
	assert_float(width).is_less(0.27)
	assert_float(lowest).is_greater(1.40)
