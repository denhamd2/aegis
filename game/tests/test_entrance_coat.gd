extends GdUnitTestSuite
## Cody's entrance coat (core/match/entrance_coat.gd). The owner, on his Mac:
## the coat flashed on and off through the entrance -- it sat off the body
## under it by a different amount every frame, and the bulked arms showed
## through it.

const MATCH := "res://scenes/match.tscn"


func _cody() -> WrestlerController:
	var scene: Node = load(MATCH).instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	add_child(scene)
	auto_free(scene)
	for w: WrestlerController in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
		if w.entrance_style == "cody":
			return w
	return null


## Hung on his skeleton, so it shares his drawn transform with nothing to
## lag, and posed from his final pose on every skeleton update.
func test_the_coat_rides_his_skeleton_and_his_final_pose() -> void:
	var cody := _cody()
	await await_millis(50)
	var coat := EntranceCoat.dress(cody)
	assert_bool(cody.skeleton.is_ancestor_of(coat._root)).is_true()
	assert_bool(coat._root.top_level).is_false()
	assert_bool(cody.skeleton.skeleton_updated.is_connected(coat._follow)).is_true()
	await await_millis(100)
	assert_vector(coat._own.global_position).is_equal_approx(
			cody.skeleton.global_position, Vector3.ONE * 1e-4)
	coat.queue_free()


## Bulked with his body: every coat vertex weighted to his upper arm sits
## out from where the glb put it, the lining with the cloth.
func test_the_coat_is_bulked_with_his_arms() -> void:
	var cody := _cody()
	await await_millis(50)
	var coat := EntranceCoat.dress(cody)
	var source := (load(EntranceCoat.COAT) as PackedScene).instantiate()
	auto_free(source)
	var sleeve := coat._root.find_child("CoatSleeve", true, false) as MeshInstance3D
	var raw := source.find_child("CoatSleeve", true, false) as MeshInstance3D
	for s in [0, 1]:
		var a: PackedVector3Array = sleeve.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		var b: PackedVector3Array = raw.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		var out := 0.0
		for i in a.size():
			out = maxf(out, (a[i] - b[i]).length())
		assert_float(out).override_failure_message("surface %d moved %.4f m" % [s, out]) \
				.is_greater(0.008)
	coat.queue_free()
