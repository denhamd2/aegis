extends GdUnitTestSuite
## A man who walks into a fire catches fire, stays alight until Aubrey puts him
## out with the extinguisher, and keeps the burn marks (ManFire, FireCrew; the
## owner, 19 Oct).

const MATCH_SCENE := "res://scenes/match.tscn"


func _match() -> Node:
	var scene: Node = auto_free(load(MATCH_SCENE).instantiate())
	add_child(scene)
	return scene


func _man(w: WrestlerController) -> ManFire:
	return w.find_child("ManFire", false, false) as ManFire


func test_a_man_who_walks_into_a_fire_catches_fire() -> void:
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.global_position = Vector3(-3.0, 0.0, 0.0)
	b.global_position = Vector3(6.0, 0.0, 6.0)      # clear of the fire
	var venue := VenueDamage.of(a)
	# a fire beside him, at his chest
	venue.start_fire(Vector3(0.6, 1.0, 0.0), 0.8, false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_man(a).burning).is_false()          # out of reach: nothing yet
	a.global_position = Vector3(0.0, 0.0, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_man(a).burning).is_true()
	assert_bool(_man(b).burning).is_false()


func test_a_fire_far_off_or_at_his_feet_does_not_catch_him() -> void:
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	a.global_position = Vector3(0.0, 0.0, 0.0)
	var venue := VenueDamage.of(a)
	venue.start_fire(Vector3(4.0, 1.0, 0.0), 0.8, false)
	venue.start_fire(Vector3(0.2, -0.9, 0.0), 0.8, false)   # under the mat, at his feet
	for i in 3:
		await get_tree().process_frame
	assert_bool(_man(a).burning).is_false()


func test_once_alight_he_stays_alight_and_the_marks_only_grow() -> void:
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var m := _man(a)
	m.ignite()
	var before := m.burn
	for i in 60:
		await get_tree().process_frame
	assert_bool(m.burning).is_true()
	assert_float(m.burn).is_greater(before)
	var later := m.burn
	m.wrestler.global_position = Vector3(-6.0, 0.0, 0.0)
	await get_tree().process_frame
	assert_bool(m.burning).is_true()          # walking off does not put him out
	assert_float(m.burn).is_greater_equal(later)


func test_putting_him_out_keeps_the_burn_marks_for_the_rest_of_the_match() -> void:
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var m := _man(a)
	m.ignite()
	for i in 30:
		await get_tree().process_frame
	var marked := m.burn
	assert_float(marked).is_greater(0.0)
	m.extinguish()
	assert_bool(m.burning).is_false()
	assert_float(m.burn).is_equal(marked)
	for i in 30:
		await get_tree().process_frame
	assert_float(m.burn).is_equal(marked)     # out, and still marked


func test_he_is_wet_for_a_moment_after_the_put_out_and_cannot_catch_again() -> void:
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var m := _man(a)
	m.ignite()
	m.extinguish()
	VenueDamage.of(a).start_fire(a.global_position + Vector3(0.3, 1.0, 0.0), 0.8, false)
	await get_tree().process_frame
	assert_bool(m.burning).is_false()


func test_aubrey_fetches_the_extinguisher_and_puts_the_fire_out() -> void:
	# no entrances: the match is live, and she follows it
	var scene: Node = auto_free(load(MATCH_SCENE).instantiate())
	scene.entrances = false
	add_child(scene)
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var crew := scene.get_node("FireCrew") as FireCrew
	var ref := scene.get_node("RefereeActor") as RefereeActor
	var m := _man(a)
	var put_out := [false]
	crew.put_out.connect(func(_w: WrestlerController) -> void: put_out[0] = true)
	m.ignite()
	var ticks := 0
	var left := false
	while not put_out[0] and ticks < 60 * 60:
		await get_tree().physics_frame
		ticks += 1
		left = left or ref.mode == RefereeActor.Mode.ERRAND
	assert_bool(left).override_failure_message("the referee never left the match for the extinguisher").is_true()
	assert_bool(put_out[0]).is_true()
	assert_bool(m.burning).is_false()
	assert_float(m.burn).is_greater(0.0)
	# and goes back to her spot once the foam has stopped
	var back := 0
	while crew.busy() and back < 60 * 20:
		await get_tree().physics_frame
		back += 1
	assert_bool(crew.busy()).is_false()


func test_the_fire_he_was_put_out_in_does_not_catch_him_again() -> void:
	# the foam goes into it: once he is out, that fire does not take him back
	var scene := _match()
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	a.global_position = Vector3(0.0, 0.0, 0.0)
	var m := _man(a)
	VenueDamage.of(a).start_fire(Vector3(0.4, 1.0, 0.0), 0.8, false)
	m.ignite()
	m.extinguish()
	for i in 240:                       # well past the wet moment
		await get_tree().process_frame
	assert_bool(m.burning).is_false()
