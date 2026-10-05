extends GdUnitTestSuite
## A man lying down is kept inside the ropes: his head or feet never end
## beyond the rope line, whichever way he lies.

const WrestlerControllerScript := preload("res://core/match/wrestler_controller.gd")


func _lying_at(pos: Vector3, yaw: float) -> WrestlerController:
	var w: WrestlerController = auto_free(WrestlerControllerScript.new())
	add_child(w)
	w.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	w.fsm.transition_to(WrestlerFSM.State.DOWN)
	w.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return w


func test_head_toward_the_rope_slides_in() -> void:
	var w := _lying_at(Vector3(0.0, 0.0, -2.6), 0.0)  # head is up -Z
	w.keep_lying_body_inside_the_ropes()
	for point in WrestlerController.LYING_BODY_POINTS:
		var q := w.global_transform * point
		assert_float(absf(q.z)).is_less_equal(WrestlerController.LYING_BODY_LIMIT + 0.001)


func test_feet_toward_the_rope_slides_in_on_every_side() -> void:
	for yaw in [0.0, PI * 0.5, PI, PI * 1.5, 0.7]:
		var w := _lying_at(Vector3(2.5, 0.0, 2.5), yaw)
		w.keep_lying_body_inside_the_ropes()
		for point in WrestlerController.LYING_BODY_POINTS:
			var q := w.global_transform * point
			assert_float(absf(q.x)).is_less_equal(WrestlerController.LYING_BODY_LIMIT + 0.001)
			assert_float(absf(q.z)).is_less_equal(WrestlerController.LYING_BODY_LIMIT + 0.001)


func test_a_man_in_the_middle_is_not_moved() -> void:
	var w := _lying_at(Vector3(0.5, 0.0, 0.5), 0.3)
	var before := w.global_position
	w.keep_lying_body_inside_the_ropes()
	assert_vector(w.global_position).is_equal(before)


func test_a_standing_man_is_left_to_the_ropes() -> void:
	var w: WrestlerController = auto_free(WrestlerControllerScript.new())
	add_child(w)
	w.global_position = Vector3(2.9, 0.0, 0.0)
	w.keep_lying_body_inside_the_ropes()
	assert_vector(w.global_position).is_equal(Vector3(2.9, 0.0, 0.0))
