extends GdUnitTestSuite
## Getting, holding and losing a weapon (No Holds Barred only), and the weapon
## wheel's arithmetic.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func _wrestler(nhb: bool) -> WrestlerController:
	var w: WrestlerController = WRESTLER_SCENE.instantiate()
	if nhb:
		MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
	auto_free(w)
	add_child(w)
	return w


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


# --- the wheel ----------------------------------------------------------------

func test_the_stick_angle_picks_a_family() -> void:
	assert_int(WeaponWheel.pick_at(Vector2(0, -0.5), -1)[0]).is_equal(0)          # up: chairs
	assert_int(WeaponWheel.pick_at(Vector2(0.5, -0.29), -1)[0]).is_equal(1)       # 60 deg
	assert_int(WeaponWheel.pick_at(Vector2(0, 0.5), -1)[0]).is_equal(3)           # down
	assert_int(WeaponWheel.pick_at(Vector2(0.1, 0.0), -1)[0]).is_equal(-1)        # centred


func test_pushed_out_the_family_holds_and_the_angle_picks_a_weapon() -> void:
	var fam := WeaponDef.Family.SWUNG
	var n := WeaponCatalog.in_family(fam).size()
	var centre := 60.0
	for i in n:
		var deg := WeaponWheel.item_angle(centre, i, n)
		var stick := Vector2(sin(deg_to_rad(deg)), -cos(deg_to_rad(deg))) * 0.95
		var got := WeaponWheel.pick_at(stick, fam)
		assert_int(got[0]).is_equal(fam)
		assert_int(got[1]).is_equal(i)


func test_every_weapon_can_be_reached_on_the_wheel() -> void:
	var reached := {}
	for f in WeaponDef.Family.size():
		var items := WeaponCatalog.in_family(f)
		for i in items.size():
			var deg := WeaponWheel.item_angle(f * 60.0, i, items.size())
			var got := WeaponWheel.pick_at(Vector2(sin(deg_to_rad(deg)), -cos(deg_to_rad(deg))), f)
			reached[items[got[1]].id] = true
	assert_int(reached.size()).is_equal(33)


# --- the rules -----------------------------------------------------------------

func test_only_outside_by_an_apron_and_only_in_no_holds_barred() -> void:
	var nhb := _wrestler(true)
	nhb.outside_ring = true
	nhb.global_position = Vector3(WrestlerController.DECK_KEEP_OUT + 0.1, WrestlerController.FLOOR_LEVEL, 0.5)
	assert_bool(nhb.can_rummage()).is_true()
	nhb.global_position = Vector3(5.4, WrestlerController.FLOOR_LEVEL, 0.5)          # out by the barricade
	assert_bool(nhb.can_rummage()).is_false()
	nhb.outside_ring = false
	nhb.global_position = Vector3(2.4, 0.0, 0.5)                                       # in the ring
	assert_bool(nhb.can_rummage()).is_false()
	var singles := _wrestler(false)
	singles.outside_ring = true
	singles.global_position = Vector3(WrestlerController.DECK_KEEP_OUT + 0.1, WrestlerController.FLOOR_LEVEL, 0.5)
	assert_bool(singles.can_rummage()).is_false()


func test_he_pulls_out_what_he_picks() -> void:
	var w := _wrestler(true)
	w.outside_ring = true
	w.global_position = Vector3(WrestlerController.DECK_KEEP_OUT + 0.1, WrestlerController.FLOOR_LEVEL, 0.5)
	await _ticks(2)
	assert_bool(w._weapon_input({"weapon": true})).is_true()
	assert_bool(w.is_rummaging()).is_true()
	w._tick_weapon_action({"weapon": true, "weapon_pick": &"steel_chair"})
	assert_str(w._weapon_action).is_equal("retrieve")
	for i in WrestlerController.WEAPON_ACTION_TICKS["retrieve"]:
		w._tick_weapon_action({})
	assert_bool(w.has_weapon()).is_true()
	assert_str(String(w.held_weapon.def.id)).is_equal("steel_chair")
	assert_bool(WeaponStock.of(w).in_stock(&"steel_chair")).is_false()


func test_a_ringside_weapon_can_be_slid_under_the_bottom_rope() -> void:
	var w := _wrestler(true)
	w.outside_ring = true
	w.global_position = Vector3(WrestlerController.DECK_KEEP_OUT + 0.1,
			WrestlerController.FLOOR_LEVEL, 0.5)
	await _ticks(2)
	var weapon := WeaponStock.of(w).pull(WeaponCatalog.by_id(&"steel_chair"))
	w.take_weapon(weapon)
	assert_bool(w.can_slide_weapon_into_ring()).is_true()
	assert_bool(w._weapon_input({"throw": true})).is_true()
	assert_str(w._weapon_action).is_equal("slide")
	for i in int(WrestlerController.WEAPON_ACTION_TICKS["slide"]):
		w._tick_weapon_action({})
	assert_int(weapon.mode).is_equal(WeaponActor.Mode.SLIDING)
	await _ticks(40)
	assert_int(weapon.mode).is_equal(WeaponActor.Mode.FLOOR)
	assert_float(weapon.global_position.x).is_less(WrestlerController.RING_KEEP_IN)
	# He can re-enter normally and pick up the same loose weapon from the mat.
	assert_bool(w.begin_rope_cross()).is_true()
	await _ticks(DiveSpot.ROLL_IN_TICKS + 5)
	assert_bool(w.outside_ring).is_false()
	assert_bool(w._weapon_input({"weapon": true})).is_true()
	for i in int(WrestlerController.WEAPON_ACTION_TICKS[w._weapon_action]):
		w._tick_weapon_action({})
	assert_bool(w.has_weapon()).is_true()
	assert_str(String(w.held_weapon.def.id)).is_equal("steel_chair")


func test_no_holds_barred_seeds_four_pickup_ready_weapons_on_the_stage() -> void:
	var arena: Node3D = auto_free(Node3D.new())
	MatchRules.set_mode(arena, MatchRules.Mode.NO_HOLDS_BARRED)
	add_child(arena)
	var w: WrestlerController = WRESTLER_SCENE.instantiate()
	arena.add_child(w)
	var stock := WeaponStock.of(w)
	stock.seed_stage_weapons()
	stock.seed_stage_weapons()
	assert_int(stock.stage_actors.size()).is_equal(4)
	for actor in stock.stage_actors:
		assert_int(actor.mode).is_equal(WeaponActor.Mode.FLOOR)
		assert_int(actor.match_lifetime_limit) \
				.is_equal(WeaponStock.STAGE_WEAPON_LIFETIME_TICKS)
		assert_float(actor.global_position.y).is_equal_approx(
				ArenaBuilder.STAGE_DECK_Y + 0.02, 0.01)
		assert_bool(ArenaBuilder.is_match_stage(actor.global_position)).is_true()
	assert_object(stock.nearest_stage_weapon(Vector3(0.0, 0.0, -33.0))).is_not_null()


func test_letting_go_of_the_button_gets_him_up_empty_handed() -> void:
	var w := _wrestler(true)
	w.outside_ring = true
	w.global_position = Vector3(WrestlerController.DECK_KEEP_OUT + 0.1, WrestlerController.FLOOR_LEVEL, 0.5)
	await _ticks(2)
	w._weapon_input({"weapon": true})
	for i in WrestlerController.RUMMAGE_RELEASE_TICKS:
		w._tick_weapon_action({"weapon": false})
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.IDLE)
	assert_bool(w.has_weapon()).is_false()


func test_he_loses_it_when_he_goes_down() -> void:
	var w := _wrestler(true)
	await _ticks(2)
	var a := WeaponStock.of(w).pull(WeaponCatalog.by_id(&"baseball_bat"))
	w.take_weapon(a)
	assert_bool(w.has_weapon()).is_true()
	w.fsm.transition_to(WrestlerFSM.State.STUNNED)
	w._tick_weapon()
	assert_bool(w.has_weapon()).is_false()
	assert_int(a.mode).is_equal(WeaponActor.Mode.THROWN)


func test_a_used_weapon_on_the_floor_can_be_reused_by_the_other_wrestler() -> void:
	var arena: Node3D = auto_free(Node3D.new())
	MatchRules.set_mode(arena, MatchRules.Mode.NO_HOLDS_BARRED)
	add_child(arena)
	var first: WrestlerController = WRESTLER_SCENE.instantiate()
	var second: WrestlerController = WRESTLER_SCENE.instantiate()
	arena.add_child(first)
	arena.add_child(second)
	var stock := WeaponStock.of(first)
	await _ticks(2)
	var bat := stock.pull(WeaponCatalog.by_id(&"baseball_bat"))
	first.take_weapon(bat)
	first.drop_weapon()
	await _ticks(60)
	assert_int(bat.mode).is_equal(WeaponActor.Mode.FLOOR)
	second.global_position = bat.global_position + Vector3(0.0, 0.0, 0.4)
	assert_bool(stock.loose_near(second.global_position) == bat).is_true()
	assert_bool(second._weapon_input({"weapon": true})).is_true()
	assert_str(second._weapon_action).is_equal(WeaponCatalog.pickup_action(bat.def))
	for i in int(WrestlerController.WEAPON_ACTION_TICKS[second._weapon_action]):
		second._tick_weapon_action({})
	assert_bool(second.has_weapon()).is_true()
	assert_bool(second.held_weapon == bat).is_true()


func test_weapons_expire_after_a_match_lifetime_on_the_floor_or_in_hand() -> void:
	var arena: Node3D = auto_free(Node3D.new())
	add_child(arena)
	var w: WrestlerController = WRESTLER_SCENE.instantiate()
	MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
	arena.add_child(w)
	var stock := WeaponStock.of(w)
	await _ticks(2)
	var loose := stock.pull(WeaponCatalog.by_id(&"steel_chair"))
	loose.mode = WeaponActor.Mode.FLOOR
	loose.match_lifetime_ticks = WeaponActor.MATCH_LIFETIME_TICKS - 1
	await _ticks(2)
	assert_bool(is_instance_valid(loose)).is_false()
	assert_object(stock.loose_near(w.global_position)).is_null()

	var held := stock.pull(WeaponCatalog.by_id(&"baseball_bat"))
	w.take_weapon(held)
	held.match_lifetime_ticks = WeaponActor.MATCH_LIFETIME_TICKS - 1
	await _ticks(2)
	assert_bool(w.has_weapon()).is_false()
	assert_bool(is_instance_valid(held)).is_false()


func test_a_thrown_weapon_flies_at_him_and_lands() -> void:
	var w := _wrestler(true)
	var foe := _wrestler(true)
	w.global_position = Vector3(0, 0, 1.5)
	foe.global_position = Vector3(0, 0, -1.5)
	w.opponent = foe
	foe.opponent = w
	await _ticks(2)
	var a := WeaponStock.of(w).pull(WeaponCatalog.by_id(&"trash_can"))
	w.take_weapon(a)
	w.begin_weapon_action("throw")
	for i in WrestlerController.WEAPON_ACTION_AT["throw"]:
		w._tick_weapon_action({})
	assert_bool(w.has_weapon()).is_false()
	assert_int(a.mode).is_equal(WeaponActor.Mode.THROWN)
	assert_float(a.velocity.z).is_less(0.0)       # toward him
