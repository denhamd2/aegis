extends GdUnitTestSuite
## The carnage spots (the owner, 19 Oct: "the flaming table, ladder bridge,
## pane of glass, through LED wall, and fire breathing"): each one does what
## it says, No Holds Barred only, and the same way every time.

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


func _set_up(w: WrestlerController, id: StringName, at: Vector3) -> WeaponActor:
	var a := WeaponStock.of(w).pull(WeaponCatalog.by_id(id))
	a.set_up_at(at, 0.0)
	return a


func after_test() -> void:
	var stock := get_node_or_null("WeaponStock")
	if stock:
		stock.free()


# --- the flaming table ---------------------------------------------------------

func test_a_taunt_beside_a_table_sets_it_alight() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(2.0, 0.0, 2.0)
	await _ticks(2)
	var table := _set_up(w, &"table", w.global_position + Vector3(1.0, 0.0, 0.0))
	assert_object(w.table_to_light()).is_same(table)
	w.begin_light(table)
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.WEAPON_ACTION)
	await _ticks(WrestlerController.WEAPON_ACTION_AT["light"] + 2)
	assert_bool(table.ablaze).is_true()
	assert_object(table.get_node_or_null("TableFire")).is_not_null()
	# one fire a table: there is nothing more to light
	assert_object(w.table_to_light()).is_null()


func test_no_lighting_a_table_in_a_singles_match_or_with_his_hands_full() -> void:
	var w := _wrestler(false)
	w.global_position = Vector3(2.0, 0.0, 2.0)
	await _ticks(2)
	var stock := WeaponStock.of(w)
	var table := stock.pull(WeaponCatalog.by_id(&"table"))
	table.set_up_at(w.global_position + Vector3(1.0, 0.0, 0.0), 0.0)
	assert_object(w.table_to_light()).is_null()
	MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
	assert_object(w.table_to_light()).is_same(table)
	w.take_weapon(stock.pull(WeaponCatalog.by_id(&"kendo_stick")))
	assert_object(w.table_to_light()).is_null()


func test_through_a_burning_table_he_catches_fire_and_the_wreck_burns() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(1.0, 0.0, 1.0)
	await _ticks(2)
	var table := _set_up(w, &"table", w.global_position)
	table.set_ablaze()
	var fire := w.get_node("ManFire") as ManFire
	assert_bool(fire.burning).is_false()
	w._go_down()
	await _ticks(WrestlerController.LAND_WAIT + 2)
	assert_int(table.mode).is_equal(WeaponActor.Mode.BROKEN)
	assert_bool(fire.burning).is_true()
	# the burning top's flames went onto the pieces
	assert_object(table.get_node_or_null("TableFire")).is_null()
	var burning_pieces := 0
	for piece: Array in table._pieces:
		if (piece[0] as Node3D).find_children("*", "GPUParticles3D", true, false).size() > 0:
			burning_pieces += 1
	assert_int(burning_pieces).is_equal(table._pieces.size())


func test_through_a_cold_table_he_does_not() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(1.0, 0.0, 1.0)
	await _ticks(2)
	_set_up(w, &"table", w.global_position)
	w._go_down()
	await _ticks(WrestlerController.LAND_WAIT + 2)
	assert_bool((w.get_node("ManFire") as ManFire).burning).is_false()
