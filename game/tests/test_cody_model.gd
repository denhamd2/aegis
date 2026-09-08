extends GdUnitTestSuite
## Guards the facts that make CodyModel's very small implementation correct.
##
## The model needs almost no adapter code, and every reason for that is a
## property of the asset that a re-export could silently break. These tests fail
## loudly if one does.

const MODEL := "res://scenes/cody_model.tscn"
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
			.override_failure_message("bone '%s' is missing from the Cody rig" % name) \
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


## Cody wrestles in his own gear. Without this the controller paints procedural
## trunks and boots over a model that already has them.
func test_does_not_use_universal_attire() -> void:
	var model := _model()
	add_child(model)
	assert_bool(model.uses_universal_attire()).is_false()


## Keys pass through unchanged -- see the long note on _install_animations().
## This skeleton shares the base rig's hierarchy, so identical local poses give
## identical global poses; converting them through rest space instead applies the
## A-pose offset twice and folds the arms across the waist.
func test_animation_keys_are_not_converted() -> void:
	var model := _model()
	add_child(model)
	var base: Node = auto_free(load(BASE_RIG).instantiate())
	var base_player := base.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var source := base_player.get_animation("Idle")
	var installed := (model.get_node("AnimationPlayer") as AnimationPlayer) \
			.get_animation("Idle")

	var compared := 0
	for track in source.get_track_count():
		if source.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(source.track_get_path(track).get_concatenated_subnames())
		for other in installed.get_track_count():
			if String(installed.track_get_path(other).get_concatenated_subnames()) != bone:
				continue
			if installed.track_get_type(other) != Animation.TYPE_ROTATION_3D:
				continue
			assert_int(installed.track_get_key_count(other)) \
				.is_equal(source.track_get_key_count(track))
			if source.track_get_key_count(track) > 0:
				var a: Quaternion = source.track_get_key_value(track, 0)
				var b: Quaternion = installed.track_get_key_value(other, 0)
				assert_float(a.angle_to(b)) \
					.override_failure_message(
						"key for '%s' was altered; it must pass through" % bone) \
					.is_less(0.001)
				compared += 1
			break
	assert_int(compared).is_greater(10)


## The supplied asset is in centimetres; the rigging step converts it. A model
## imported at the wrong scale is a 180-metre wrestler, which nothing else in
## the project has any chance of framing.
func test_stands_at_human_height() -> void:
	var model := _model()
	add_child(model)
	var aabb := AABB()
	var first := true
	for node in model.find_children("", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var world := mesh_instance.global_transform * mesh_instance.get_aabb()
		if first:
			aabb = world
			first = false
		else:
			aabb = aabb.merge(world)
	assert_float(aabb.size.y).is_between(1.6, 2.1)
