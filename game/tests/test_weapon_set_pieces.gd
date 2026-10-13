extends GdUnitTestSuite
## A man put down on a set piece: through the table, onto the tacks, onto a
## chair -- No Holds Barred only, and the same way every time.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func _wrestler(nhb: bool, seed := 7) -> WrestlerController:
	var w: WrestlerController = WRESTLER_SCENE.instantiate()
	if nhb:
		MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
	w.match_seed = seed
	auto_free(w)
	add_child(w)
	return w


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## `id` stood up at `at`, from the stock beside `w`.
func _set_up(w: WrestlerController, id: StringName, at: Vector3) -> WeaponActor:
	var a := WeaponStock.of(w).pull(WeaponCatalog.by_id(id))
	a.set_up_at(at, 0.0)
	return a


func after_test() -> void:
	var stock := get_node_or_null("WeaponStock")
	if stock:
		stock.free()


func test_put_down_on_a_table_he_goes_through_it() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(1.0, 0.0, 1.0)
	await _ticks(2)
	var table := _set_up(w, &"table", w.global_position)
	var landed := []
	w.set_piece_landed.connect(func(_who, weapon, broke): landed.append([weapon, broke]))
	var wear := w.combat.wear
	w._go_down()
	await _ticks(WrestlerController.LAND_WAIT + 2)
	assert_int(table.mode).is_equal(WeaponActor.Mode.BROKEN)
	assert_str(table.state_root).is_equal("Table_Broken")
	assert_float(w.combat.wear - wear).is_greater(10.0)
	assert_int(landed.size()).is_equal(1)
	assert_bool(landed[0][1]).is_true()
	assert_int(w._move_ticks_remaining).is_greater(w.down_ticks_for(-1))


func test_the_table_breaks_the_same_way_every_time() -> void:
	var spreads := []
	for run in 2:
		var w := _wrestler(true, 31)
		w.global_position = Vector3(1.0, 0.0, 1.0)
		await _ticks(2)
		var table := _set_up(w, &"table", w.global_position)
		w._go_down()
		await _ticks(WrestlerController.LAND_WAIT + 2)
		var v := []
		for piece: Array in table._pieces:
			v.append((piece[1] as Vector3).snappedf(0.001))
		spreads.append(v)
		after_test()
	assert_bool(spreads[0].size() > 0).is_true()
	assert_array(spreads[1]).is_equal(spreads[0])


func test_a_table_out_of_reach_stays_up() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(1.0, 0.0, 1.0)
	await _ticks(2)
	var table := _set_up(w, &"table", w.global_position + Vector3(0.0, 0.0, -3.0))
	w._go_down()
	await _ticks(WrestlerController.LAND_WAIT + 2)
	assert_int(table.mode).is_equal(WeaponActor.Mode.SET_UP)


func test_not_in_a_singles_match() -> void:
	var w := _wrestler(false)
	w.global_position = Vector3(1.0, 0.0, 1.0)
	await _ticks(2)
	var table := _set_up(w, &"table", w.global_position)
	var wear := w.combat.wear
	w._go_down()
	await _ticks(WrestlerController.LAND_WAIT + 2)
	assert_int(table.mode).is_equal(WeaponActor.Mode.SET_UP)
	assert_float(w.combat.wear).is_equal(wear)


func test_on_the_tacks_they_stay_and_some_stick_in_his_back() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(1.0, 0.0, 1.0)
	await _ticks(2)
	var tacks := _set_up(w, &"thumbtacks", w.global_position)
	var wear := w.combat.wear
	w._go_down()
	await _ticks(WrestlerController.LAND_WAIT + 2)
	assert_int(tacks.mode).is_equal(WeaponActor.Mode.SET_UP)
	assert_float(w.combat.wear - wear).is_greater(8.0)
	assert_object(w._tacks_in_back).is_not_null()


func test_a_chair_on_the_floor_hurts_less_than_a_table() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(1.0, 0.0, 1.0)
	await _ticks(2)
	var chair := WeaponStock.of(w).pull(WeaponCatalog.by_id(&"steel_chair"))
	chair.global_position = w.global_position
	chair.drop()
	await _ticks(90)
	assert_int(chair.mode).is_equal(WeaponActor.Mode.FLOOR)
	var wear := w.combat.wear
	w._go_down()
	await _ticks(WrestlerController.LAND_WAIT + 2)
	var taken := w.combat.wear - wear
	assert_float(taken).is_greater(3.0)
	assert_float(taken).is_less(10.0)
	assert_int(chair.hits).is_equal(1)
