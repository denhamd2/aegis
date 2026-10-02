extends GdUnitTestSuite
## The roster's heights: every man stands at his real billed height, and the
## model heights the scale is computed from are still what the models measure.

## Top of the head mesh at scale 1.0 when the heights were calibrated
## (Roster.entries()): a change to a model shows up here and means the
## calibration has to be redone. Roman's model_height_m is calibrated by eye
## height rather than read off this top -- see the note in Roster.
const HEAD_MESH := {"roman": "head_skinned", "cody": "Body", "kenny": "Kenny_Body"}
const HEAD_TOP := {"roman": 1.895, "cody": 1.837, "kenny": 1.749}


func test_roster_heights() -> void:
	for entry: Roster.Entry in Roster.entries():
		var model: Node3D = (load(entry.model_scene) as PackedScene).instantiate()
		add_child(model)
		await get_tree().process_frame
		var mesh := model.find_child(HEAD_MESH[entry.id], true, false) as MeshInstance3D
		assert_object(mesh).is_not_null()
		var top := (mesh.global_transform * mesh.get_aabb()).end.y
		assert_float(top).override_failure_message(
				"%s's model now measures %.3f m, not the %.3f his scale was calibrated on"
				% [entry.id, top, HEAD_TOP[entry.id]]) \
				.is_equal_approx(HEAD_TOP[entry.id], 0.01)
		assert_float(entry.model_height_m * entry.stature_scale()) \
				.is_equal_approx(entry.stature_m, 0.001)
		model.free()


## The owner: Roman looked too small beside Cody. He is billed an inch taller,
## and after configure_match he is -- whichever slot each man is in.
func test_roman_stands_taller_than_cody_in_either_slot() -> void:
	var roman := Roster.by_id("roman")
	var cody := Roster.by_id("cody")
	assert_float(roman.stature_m - cody.stature_m).is_equal_approx(0.0254, 0.001)
	for pair: Array in [[roman, cody], [cody, roman]]:
		var scene: Node = auto_free(load("res://scenes/match.tscn").instantiate())
		TitleScreen.configure_match(scene, pair[0], pair[1], 1)
		for slot: Array in [["WrestlerA", pair[0]], ["WrestlerB", pair[1]]]:
			var w: WrestlerController = scene.get_node(slot[0])
			assert_float(w.physique_height).is_equal_approx(
					(slot[1] as Roster.Entry).stature_scale(), 0.0001)
