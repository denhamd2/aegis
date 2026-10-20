extends GdUnitTestSuite
## Up the ramp in a match he is lit (the owner, 20 Oct: "it stays dark").

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func test_the_spot_finds_him_on_the_ramp_and_lets_go_at_ringside() -> void:
	var w: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(w)
	var spot: RampFollowSpot = auto_free(RampFollowSpot.new())
	add_child(spot)
	spot.watch([w])
	w.global_position = Vector3(0.0, 0.0, -15.0)
	for i in 40:
		spot._physics_process(1.0 / 60.0)
	assert_bool(spot._spots[0].visible).is_true()
	assert_float(spot._spots[0].light_energy).is_equal_approx(RampFollowSpot.SPOT_ENERGY, 0.01)
	# aimed at him
	var aim := -spot._spots[0].global_transform.basis.z
	var to := (w.global_position + Vector3.UP * 1.1 - spot._spots[0].global_position).normalized()
	assert_float(aim.dot(to)).is_greater(0.999)
	w.global_position = Vector3(0.0, 0.0, -4.0)
	for i in 40:
		spot._physics_process(1.0 / 60.0)
	assert_bool(spot._spots[0].visible).is_false()
	assert_bool(RampFollowSpot.on_ramp(Vector3(0.0, 0.0, -2.0))).is_false()
	assert_bool(RampFollowSpot.on_ramp(Vector3(0.0, 0.0, -32.0))).is_true()
