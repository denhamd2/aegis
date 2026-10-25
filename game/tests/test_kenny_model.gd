extends GdUnitTestSuite
## Guards the facts that make KennyModel's very small implementation correct.
##
## The model needs almost no adapter code, and every reason for that is a
## property of the asset -- or of the two-step pipeline that produced it
## (`fbx_to_static_glb.py` then `rig_static_wrestler.py`) -- that a re-run or a
## re-export could silently break. These tests fail loudly if one does.

const MODEL := "res://scenes/kenny_model.tscn"
const BASE_RIG := "res://assets/characters/wrestler_base.glb"


func _model() -> Node3D:
	return auto_free(load(MODEL).instantiate()) as Node3D


## The whole approach rests on this: the rigged asset carries the base rig's own
## bones. If a re-export renames or drops any of them, the animation tracks stop
## resolving and the wrestler goes inert -- silently, because a track pointing at
## a missing bone is not an error.
func test_skeleton_is_the_base_rigs_bones() -> void:
	var model := _model()
	add_child(model)
	var skeleton := model.get_game_skeleton() as Skeleton3D
	assert_object(skeleton).is_not_null()

	var base: Node = auto_free(load(BASE_RIG).instantiate())
	var base_skeleton: Skeleton3D = null
	for candidate in base.find_children("", "Skeleton3D", true, false):
		base_skeleton = candidate as Skeleton3D
		break
	assert_object(base_skeleton).is_not_null()

	assert_int(skeleton.get_bone_count()).is_equal(base_skeleton.get_bone_count())
	for index in base_skeleton.get_bone_count():
		var name := base_skeleton.get_bone_name(index)
		assert_int(skeleton.find_bone(name)) \
			.override_failure_message("bone '%s' is missing from the Kenny rig" % name) \
			.is_greater_equal(0)


## Rigged on exactly one skeleton, which is why apply_physique_height() is not
## implemented. Roman is rigged on two, and scaling only one of those produced a
## bald crown, skin through the trousers and a displaced beard from a single
## line -- so "how many skeletons" is worth pinning rather than assuming.
func test_is_rigged_on_a_single_skeleton() -> void:
	var model := _model()
	add_child(model)
	assert_int(model.find_children("", "Skeleton3D", true, false).size()).is_equal(1)


## Every vertex must be weighted. An unweighted vertex is not merely deformed
## badly: it stays pinned at the model's origin while the rest of the body walks
## away, which reads as the character trailing shards behind him.
func test_mesh_is_skinned() -> void:
	var model := _model()
	add_child(model)
	var skeleton := model.get_game_skeleton() as Skeleton3D
	var meshes := skeleton.find_children("", "MeshInstance3D", true, false)
	assert_array(meshes).is_not_empty()
	for node in meshes:
		var mesh_instance := node as MeshInstance3D
		assert_object(mesh_instance.skin) \
			.override_failure_message("%s has no skin: it is not rigged" % mesh_instance.name) \
			.is_not_null()


## The base rig's clips must arrive, under their own names, pointing at this
## model's skeleton. The path rebase is the one thing _install_animations() does,
## and getting it wrong leaves tracks that resolve to nothing without erroring.
func test_animations_are_installed_and_repathed() -> void:
	var model := _model()
	add_child(model)
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	var names := player.get_animation_list()
	assert_array(names).is_not_empty()
	assert_bool(player.has_animation("Idle")).is_true()

	var skeleton := model.get_game_skeleton() as Skeleton3D
	var expected := String(model.get_path_to(skeleton))
	var animation := player.get_animation("Idle")
	var checked := 0
	for track in animation.get_track_count():
		var path := String(animation.track_get_path(track))
		if not path.contains(":"):
			continue
		assert_str(path.get_slice(":", 0)).is_equal(expected)
		checked += 1
	assert_int(checked).is_greater(0)


## Kenny is scanned wearing his own gear, so the procedural attire must stay off.
## Without this the controller treats the model as a bare mannequin and
## WrestlerAttire.build() paints trunks and boots over clothing that is already
## part of the single scanned body mesh -- with nothing to hide them behind.
func test_does_not_use_universal_attire() -> void:
	var model := _model()
	add_child(model)
	assert_bool(model.uses_universal_attire()).is_false()


## The supplied scan stands on its head, and fbx_to_static_glb.py flips it. That
## flip is a step in a script rather than a visible property of the scene, so it
## is exactly the kind of thing a later re-run can lose: assert the rigged asset
## really is the right way up, with the head bone above the hips.
func test_model_is_the_right_way_up() -> void:
	var model := _model()
	add_child(model)
	var skeleton := model.get_game_skeleton() as Skeleton3D
	# "pelvis", not "Hips" -- these are the CC0 base rig's own names, and only
	# "Head" happens to be capitalised among them.
	var head := skeleton.find_bone("Head")
	var pelvis := skeleton.find_bone("pelvis")
	assert_int(head).is_greater_equal(0)
	assert_int(pelvis).is_greater_equal(0)
	var head_y := skeleton.get_bone_global_pose(head).origin.y
	var pelvis_y := skeleton.get_bone_global_pose(pelvis).origin.y
	assert_float(head_y) \
		.override_failure_message("head is below the pelvis: the scan is upside down") \
		.is_greater(pelvis_y)


## The owner, 20 Oct: Kenny's model "doesn't look good or realistic" -- the top
## of his head was the hair cap alone, a slicked painted helmet, with curls
## only from the ears back (kenny_aaa_plan.md gap 1). The crown curls cover it:
## curl cards reach the cap's top on both sides of the part.
func test_curls_cover_the_crown() -> void:
	var model := _model()
	var cap := model.find_child("Kenny_HairCap", true, false) as MeshInstance3D
	var curls := model.find_child("Kenny_Curls", true, false) as MeshInstance3D
	assert_object(cap).is_not_null()
	assert_object(curls).is_not_null()
	var top := -INF
	for v: Vector3 in cap.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		top = maxf(top, v.y)
	var left := 0
	var right := 0
	for v: Vector3 in curls.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if v.y > top - 0.03:
			if v.x > 0.0:
				left += 1
			else:
				right += 1
	assert_int(left).is_greater(200)
	assert_int(right).is_greater(200)


## The cap is the shadowed roots under the curls: matte, with no stretched
## hair highlight. With HairLook's anisotropy the overhead key drew a pale
## band across his hairline that read as slicked-back hair (kenny pass 4).
func test_the_hair_cap_is_matte_roots() -> void:
	var model := _model()
	add_child(model)
	var cap := model.find_child("Kenny_HairCap", true, false) as MeshInstance3D
	var mat := cap.get_surface_override_material(0) as BaseMaterial3D
	assert_object(mat).is_not_null()
	assert_bool(mat.anisotropy_enabled).is_false()
	assert_float(mat.metallic_specular).is_less_equal(0.1)
	assert_float(mat.roughness).is_greater_equal(0.85)


## The owner, 25 Oct: "His hair looks too big." Against his AEW headshot the
## hair sits close to the head and ends near the jaw at the sides and the
## collar at the back. Measured on the curl cards (2nd to 98th percentile, so
## a stray strand does not decide it): no wider than 0.34 m at ear height
## (it was 0.42), and nothing hangs below his shoulders (it reached 1.35 m).
func test_the_hair_sits_close_to_his_head() -> void:
	var curls := _model().find_child("Kenny_Curls", true, false) as MeshInstance3D
	var xs: Array[float] = []
	var lowest := INF
	for v: Vector3 in curls.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		lowest = minf(lowest, v.y)
		if v.y > 1.55 and v.y < 1.65:
			xs.append(v.x)
	xs.sort()
	var width := xs[int(xs.size() * 0.98)] - xs[int(xs.size() * 0.02)]
	assert_float(width).is_less(0.34)
	assert_float(lowest).is_greater(1.40)
