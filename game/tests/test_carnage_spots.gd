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


# --- the pane of glass -------------------------------------------------------

func test_the_pane_of_glass_sets_up_like_a_table_and_shatters_into_shards() -> void:
	var def := WeaponCatalog.by_id(&"glass_pane")
	assert_object(def).is_not_null()
	assert_bool(def.set_piece).is_true()
	var a := WeaponActor.make(def)
	auto_free(a)
	for state: String in ["GlassPane_Carried", "GlassPane_Up", "GlassPane_Broken"]:
		assert_bool(a.has_state(state)).override_failure_message(state).is_true()
	var shards := (a._roots["GlassPane_Broken"] as Node3D).find_children("*__piece_*", "Node3D", true, false)
	assert_int(shards.size()).is_greater(30)


func test_through_the_glass_he_is_cut_open_front_and_back() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(1.0, 0.0, 1.0)
	await _ticks(2)
	var pane := _set_up(w, &"glass_pane", w.global_position)
	var blood := w.get_node_or_null("Blood") as Blood
	w._go_down()
	await _ticks(WrestlerController.LAND_WAIT + 2)
	assert_int(pane.mode).is_equal(WeaponActor.Mode.BROKEN)
	assert_str(pane.state_root).is_equal("GlassPane_Broken")
	if blood:
		assert_float(blood.back).is_greater(0.5)
		assert_float(blood.head).is_greater(0.5)
	# heavier than going through a table
	assert_float(WeaponCatalog.landing_move(pane.def).damage_torso).is_greater(
			WeaponCatalog.landing_move(WeaponCatalog.by_id(&"table")).damage_torso)


# --- the ladder bridge -------------------------------------------------------

func test_a_ladder_set_down_outside_goes_across_from_apron_to_barricade() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(4.6, WrestlerController.FLOOR_LEVEL, 0.5)
	w.outside_ring = true
	await _ticks(2)
	var span := w.bridge_span()
	assert_int(span.size()).is_equal(2)
	assert_float((span[0] as Vector3).x).is_less(RingBuilder.APRON_OUT)
	assert_float((span[1] as Vector3).x).is_greater(ArenaBuilder.BARRICADE_RADIUS)
	# not in the ring, and not at a corner
	w.outside_ring = false
	assert_array(w.bridge_span()).is_empty()
	w.outside_ring = true
	w.global_position = Vector3(4.6, WrestlerController.FLOOR_LEVEL, 3.4)
	assert_array(w.bridge_span()).is_empty()
	MatchRules.set_mode(w, MatchRules.Mode.ONE_ON_ONE)
	w.global_position = Vector3(4.6, WrestlerController.FLOOR_LEVEL, 0.5)
	assert_array(w.bridge_span()).is_empty()


func test_put_down_on_the_bridge_it_folds_under_him_and_stays_folded() -> void:
	var w := _wrestler(true)
	w.global_position = Vector3(4.6, WrestlerController.FLOOR_LEVEL, 0.5)
	w.outside_ring = true
	await _ticks(2)
	var ladder := WeaponStock.of(w).pull(WeaponCatalog.by_id(&"ladder"))
	var span := w.bridge_span()
	ladder.set_bridge(span[0], span[1])
	assert_bool(ladder.bridge).is_true()
	var top := (ladder.global_transform * ladder.local_bounds()).end.y
	assert_float(top).is_between(-0.15, 0.25)          # level with the apron and the wall
	var landed := []
	w.set_piece_landed.connect(func(_who, weapon, broke): landed.append([weapon, broke]))
	w._land_on(ladder, w.global_position + Vector3.UP * 0.1)
	assert_bool(ladder.folded).is_true()
	assert_object(ladder.get_node_or_null("Bent")).is_not_null()
	assert_bool(landed[0][1]).is_true()
	# folded, it is not a set piece any more: nobody lands on it twice
	assert_bool(WeaponStock.of(w).set_up_pieces().has(ladder)).is_false()


# --- through the LED wall ----------------------------------------------------

func _stage_scene() -> Node:
	var scene: Node = auto_free(load("res://scenes/match.tscn").instantiate())
	scene.entrances = false
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 3, true,
			MatchRules.Mode.NO_HOLDS_BARRED)
	add_child(scene)
	return scene


func test_whipped_into_a_side_led_wall_he_goes_through_it_and_it_dies() -> void:
	var scene := _stage_scene()
	await _ticks(2)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [a, b]:
		w.is_ai = false
		if w.ai:
			w.ai.set_physics_process(false)
	var venue := VenueDamage.of(b)
	# on the deck in front of the left wall, running at it
	var x := -(ArenaBuilder.SIDE_SCREEN_INNER_X + 0.6)
	b.global_position = Vector3(x, ArenaBuilder.STAGE_DECK_Y, ArenaBuilder.MATCH_STAGE_BACK_LIMIT + 0.05)
	b.velocity = Vector3(0.0, 0.0, -WrestlerController.IRISH_WHIP_LAUNCH_SPEED)
	b._irish_whip_rebounded = false
	var health := b.combat.health()
	var smashed := []
	b.smashed_into_screen.connect(func(who): smashed.append(who))
	assert_bool(b._whipped_into_screen()).is_true()
	assert_int(smashed.size()).is_equal(1)
	assert_float(b.combat.health()).is_less(health)
	assert_int(b.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	var screen := venue.side_screen_near(b.global_position + Vector3.UP * 1.15)
	assert_object(screen).is_not_null()
	assert_bool(screen.dead).is_true()
	assert_object(venue.get_node_or_null("%s_Dead" % screen.name)).is_not_null()
	# a rocket's fire, not his: no fire from going through it
	assert_int(venue.fires.size()).is_equal(0)


func test_no_led_wall_off_the_stage_or_in_a_singles_match() -> void:
	var scene := _stage_scene()
	await _ticks(2)
	var b: WrestlerController = scene.get_node("WrestlerB")
	b.global_position = Vector3(4.6, WrestlerController.FLOOR_LEVEL, 0.5)
	b.velocity = Vector3(0.0, 0.0, -9.0)
	assert_bool(b._whipped_into_screen()).is_false()
	MatchRules.set_mode(scene, MatchRules.Mode.ONE_ON_ONE)
	b.global_position = Vector3(-3.15, ArenaBuilder.STAGE_DECK_Y, ArenaBuilder.MATCH_STAGE_BACK_LIMIT + 0.05)
	assert_bool(b._whipped_into_screen()).is_false()


# --- fire breathing ----------------------------------------------------------

func test_the_fire_torch_is_a_spray_that_burns_and_carries_its_flame() -> void:
	var def := WeaponCatalog.by_id(&"fire_torch")
	assert_object(def).is_not_null()
	assert_int(def.swing).is_equal(WeaponDef.Swing.SPRAY)
	assert_bool(WeaponCatalog.is_ranged(def)).is_true()
	var a := WeaponActor.make(def)
	auto_free(a)
	assert_object(a.get_node_or_null("TorchFlame")).is_not_null()


func test_breathing_fire_at_him_sets_him_alight() -> void:
	var a := _wrestler(true)
	var b := _wrestler(true, 8)
	a.opponent = b
	b.opponent = a
	a.global_position = Vector3(0.0, 0.0, 0.0)
	b.global_position = Vector3(0.0, 0.0, -1.4)
	a.look_at(b.global_position, Vector3.UP)
	await _ticks(2)
	a.take_weapon(WeaponStock.of(a).pull(WeaponCatalog.by_id(&"fire_torch")))
	var swing := WeaponCatalog.swing_move(a.held_weapon.def)
	assert_bool(a._strike_reaches(swing)).is_true()
	var fire := b.get_node("ManFire") as ManFire
	assert_bool(fire.burning).is_false()
	a._apply_move_to_opponent(swing)
	assert_bool(fire.burning).is_true()
