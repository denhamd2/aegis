extends GdUnitTestSuite
## Skin: pores, sweat and scattering (SkinLook, Sweat;
## gauntlet/refs/aaa_gap.md items 2, 5 and 6).


func test_sweat_starts_damp_builds_and_caps() -> void:
	assert_float(Sweat.target(0.0, 0.0)).is_equal_approx(Sweat.BASE, 0.0001)
	var last := -1.0
	for s in range(0, 200, 10):
		var w := Sweat.target(float(s), 0.0)
		assert_float(w).is_greater_equal(last)
		last = w
	# Time alone gets him wet, not soaked; punishment takes him the rest.
	assert_float(Sweat.target(1000.0, 0.0)).is_less(0.8)
	assert_float(Sweat.target(1000.0, 1000.0)).is_equal(1.0)
	assert_float(Sweat.target(60.0, 80.0)).is_greater(Sweat.target(60.0, 0.0))


func test_wetness_is_a_clearcoat_film() -> void:
	var m := StandardMaterial3D.new()
	SkinLook.set_wetness(m, 0.0)
	assert_bool(m.clearcoat_enabled).is_false()
	SkinLook.set_wetness(m, 1.0)
	assert_bool(m.clearcoat_enabled).is_true()
	assert_float(m.clearcoat).is_equal_approx(SkinLook.SWEAT_COAT, 0.0001)
	assert_float(m.clearcoat_roughness).is_equal_approx(SkinLook.SWEAT_COAT_ROUGHNESS_WET, 0.0001)


## The pore layer rides on UV2 and must not tint the skin: white in multiply.
func test_pores_leave_the_colour_alone() -> void:
	var m := StandardMaterial3D.new()
	SkinLook.add_pores(m, 20.0)
	assert_bool(m.detail_enabled).is_true()
	assert_int(m.detail_uv_layer).is_equal(BaseMaterial3D.DETAIL_UV_2)
	assert_int(m.detail_blend_mode).is_equal(BaseMaterial3D.BLEND_MODE_MUL)
	var px := (m.detail_albedo as ImageTexture).get_image().get_pixel(0, 0)
	assert_float(px.r + px.g + px.b).is_equal_approx(3.0, 0.01)
	assert_float(px.a).is_equal_approx(SkinLook.DETAIL_MIX, 0.01)
	assert_float(m.uv2_scale.x).is_equal(20.0)


## UV2 is added to the named surfaces only, and nothing else about the mesh
## -- vertex count, the other surfaces, the override materials -- changes.
func test_detail_uv_is_added_without_touching_the_mesh() -> void:
	var mi: MeshInstance3D = auto_free(MeshInstance3D.new())
	var mesh := ArrayMesh.new()
	for k in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for v in [Vector3(0, 0, k), Vector3(1, 0, k), Vector3(0, 1, k)]:
			st.set_uv(Vector2(v.x, v.y))
			st.add_vertex(v)
		st.commit(mesh)
	mi.mesh = mesh
	var override := StandardMaterial3D.new()
	mi.set_surface_override_material(1, override)
	SkinLook.with_detail_uv(mi, [0])
	var out := mi.mesh as ArrayMesh
	assert_int(out.get_surface_count()).is_equal(2)
	var a0 := out.surface_get_arrays(0)
	var a1 := out.surface_get_arrays(1)
	assert_that(a0[Mesh.ARRAY_TEX_UV2]).is_equal(a0[Mesh.ARRAY_TEX_UV])
	assert_that(a1[Mesh.ARRAY_TEX_UV2]).is_null()
	assert_int((a0[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()).is_equal(3)
	assert_object(mi.get_surface_override_material(1)).is_same(override)


## The two men who carry skin materials get the full treatment.
func test_roman_and_cody_register_skin_with_pores_and_sweat() -> void:
	for id in ["roman", "cody"]:
		var model: Node3D = (load(Roster.by_id(id).model_scene) as PackedScene).instantiate()
		add_child(model)
		await get_tree().process_frame
		var skin: Array = model.get_meta("skin_materials", [])
		assert_int(skin.size()).override_failure_message("%s has no skin" % id).is_greater(0)
		for m: BaseMaterial3D in skin:
			assert_bool(m.subsurf_scatter_enabled).is_true()
			assert_bool(m.detail_enabled).is_true()
		model.free()
