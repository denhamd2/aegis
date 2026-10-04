extends GdUnitTestSuite
## Roman's ula fala (tools/blender/roman_props.py, core/match/entrance_props.gd).
##
## It is skinned to his own skeleton so it cannot float: it rides the clavicles,
## the chest and the neck with the skin. These pin the parts of that which
## can be checked without a renderer -- the file's shape, and that the copy of
## the skeleton it keeps is hung on his and driven from his pose.

const ULA_FALA := "res://assets/props/ula_fala.glb"
const MATCH := "res://scenes/match.tscn"
## The budget: dense, but a prop (polycount-budgets.md).
const MAX_TRIANGLES := 15000


func _count_triangles(root: Node) -> int:
	var total := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			total += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return total


func test_the_necklace_is_skinned_to_his_bones_and_within_budget() -> void:
	var root: Node3D = auto_free((load(ULA_FALA) as PackedScene).instantiate())
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	assert_int(skeletons.size()).is_equal(1)
	var sk := skeletons[0] as Skeleton3D
	# The bones it is weighted to are the ones the photograph says it rides.
	for bone in ["J_Chest", "J_Neck", "J_Clavicle_L", "J_Clavicle_R"]:
		assert_int(sk.find_bone(bone)).override_failure_message("no %s" % bone).is_greater_equal(0)
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var names := meshes.map(func(m: Node) -> String: return String(m.name))
	for part in ["FalaRed", "FalaCord"]:
		assert_bool(names.has(part)).override_failure_message("no %s" % part).is_true()
	for m: MeshInstance3D in meshes:
		assert_object(m.skin).override_failure_message("%s is not skinned" % m.name).is_not_null()
	var tris := _count_triangles(root)
	assert_int(tris).override_failure_message("%d triangles" % tris).is_less(MAX_TRIANGLES)
	# Dense, not a thin ring: a few thousand triangles is the necklace.
	assert_int(tris).is_greater(4000)


func test_the_keys_are_in_a_collar_on_his_neck_not_a_loose_ring() -> void:
	var root: Node3D = auto_free((load(ULA_FALA) as PackedScene).instantiate())
	var aabb := AABB()
	var first := true
	for node in root.find_children("FalaRed", "MeshInstance3D", true, false):
		var box := (node as MeshInstance3D).mesh.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	# About 0.5 m across the shoulders' top and 0.3 m front to back: a collar
	# the size of the man, not the 0.32 m mannequin loop it replaced.
	assert_float(aabb.size.x).is_between(0.40, 0.65)
	assert_float(aabb.size.z).is_between(0.22, 0.45)


func _roman_match() -> Dictionary:
	var scene: Node = load(MATCH).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = false
	add_child(scene)
	auto_free(scene)
	return {"scene": scene, "roman": scene.get_node("WrestlerA")}


func test_it_hangs_on_his_skeleton_and_is_posed_from_his_every_frame() -> void:
	var roman: WrestlerController = _roman_match()["roman"]
	await get_tree().process_frame
	await get_tree().process_frame
	var props := EntranceProps.dress(roman, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var fala: Node3D = props._fala
	var own: Skeleton3D = props._fala_skeleton
	assert_object(own).is_not_null()
	# Under his skeleton, so it shares his transform with nothing to lag.
	assert_object(fala.get_parent()).is_same(roman.skeleton)
	assert_bool(own.global_transform.is_equal_approx(roman.skeleton.global_transform)).is_true()
	# Move him: it goes with him in the same frame.
	roman.global_position += Vector3(1.5, 0.0, -0.7)
	roman.global_rotate(Vector3.UP, 0.8)
	assert_bool(own.global_transform.is_equal_approx(roman.skeleton.global_transform)).is_true()
	# Every bone it shares with him carries his pose as it is DRAWN: his
	# `skeleton_updated` fires after the animation, the IK and the modifiers
	# (the neck RomanHeadShape widens), and Godot puts the pose back to the
	# animation's afterwards. So it is read inside the signal, after the
	# necklace's own handler (connected first).
	var seen := {"frames": 0, "bad": []}
	roman.skeleton.skeleton_updated.connect(func() -> void:
		seen["frames"] += 1
		for i in own.get_bone_count():
			var j := roman.skeleton.find_bone(own.get_bone_name(i))
			if j < 0 or not own.get_bone_pose_rotation(i).is_equal_approx(
					roman.skeleton.get_bone_pose_rotation(j)) \
					or not own.get_bone_pose_scale(i).is_equal_approx(
					roman.skeleton.get_bone_pose_scale(j)):
				seen["bad"].append(own.get_bone_name(i)))
	for i in 3:
		await get_tree().process_frame
	assert_int(seen["frames"]).is_greater(0)
	assert_array(seen["bad"]).override_failure_message(
			"bones off his pose: %s" % [seen["bad"]]).is_empty()
	# Its meshes are placed by the skin alone.
	for m: MeshInstance3D in fala.find_children("*", "MeshInstance3D", true, false):
		assert_bool(m.transform.is_equal_approx(Transform3D.IDENTITY)) \
				.override_failure_message("%s has its own placement" % m.name).is_true()
	# Its rest is his rest: same bones, same local rest transforms, so a copied
	# pose lands where his own skin puts it.
	for i in own.get_bone_count():
		var j := roman.skeleton.find_bone(own.get_bone_name(i))
		assert_vector(own.get_bone_rest(i).origin).is_equal_approx(
				roman.skeleton.get_bone_rest(j).origin, Vector3.ONE * 0.001)
	# Handed off (EntranceDirector's fala_off) it is hidden, and back on.
	props.set_fala_visible(false)
	assert_bool(fala.visible).is_false()
	props.set_fala_visible(true)
	assert_bool(fala.visible).is_true()
	# And it goes when the props do (the bell).
	props.free()
	await get_tree().process_frame
	assert_bool(is_instance_valid(fala) and fala.is_inside_tree()).is_false()
