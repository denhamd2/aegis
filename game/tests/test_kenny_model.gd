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
