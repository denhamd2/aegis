extends GdUnitTestSuite
## Hell in a Cell (gauntlet/refs/hell_in_a_cell.md): a roofed cell on the
## arena floor round the ring and the ringside mats; anything goes inside it,
## pinfall or submission only -- no escape win, no stage, and a man whipped
## into its wall on the floor goes into the steel.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")

var _cage: CageBuilder


func after_test() -> void:
	if _cage and is_instance_valid(_cage):
		_cage.free()
	_cage = null


func _wrestler(at: Vector3, index := 0) -> WrestlerController:
	var w: WrestlerController = WRESTLER_SCENE.instantiate()
	w.player_index = index
	MatchRules.set_mode(w, MatchRules.Mode.HELL_IN_A_CELL)
	auto_free(w)
	add_child(w)
	w.is_ai = true
	w.global_position = at
	return w


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_the_rules_are_anything_goes_in_a_cage_with_no_escape() -> void:
	assert_str(MatchRules.label(MatchRules.Mode.HELL_IN_A_CELL)).is_equal("HELL IN A CELL")
	var w := _wrestler(Vector3.ZERO)
	assert_bool(MatchRules.caged(w)).is_true()
	assert_bool(MatchRules.escape_wins(w)).is_false()
	assert_bool(MatchRules.no_holds_barred(w)).is_true()
	assert_bool(MatchRules.pins_count(w)).is_true()
	assert_bool(MatchRules.prize_hangs(w)).is_false()


func test_the_cell_stands_on_the_floor_round_ringside_with_a_roof() -> void:
	var spec := CageBuilder.Spec.for_mode(MatchRules.Mode.HELL_IN_A_CELL)
	assert_bool(spec.roof).is_true()
	assert_float(spec.base_y).is_equal_approx(ArenaBuilder.FLOOR_Y, 0.001)
	# Round the ringside mats, inside the barricade.
	assert_float(spec.half).is_greater(4.5)
	assert_float(spec.half).is_less(ArenaBuilder.BARRICADE_RADIUS)
	# About twenty feet of steel.
	assert_float(spec.top_y - spec.base_y).is_between(5.5, 6.5)
	# The door on the entrance side.
	assert_vector(spec.door_axis).is_equal(Vector3(0, 0, -1))
	# The Steel Cage is unchanged.
	var cage := CageBuilder.Spec.for_mode(MatchRules.Mode.STEEL_CAGE)
	assert_bool(cage.roof).is_false()
	assert_float(cage.half).is_equal_approx(3.26, 0.001)


func test_the_match_builds_the_cell_but_no_way_out() -> void:
	var scene: Node = auto_free(load("res://scenes/match.tscn").instantiate())
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1,
			false, MatchRules.Mode.HELL_IN_A_CELL)
	for part in ["Arena", "LightRig"]:
		scene.get_node(part).free()
	scene.entrances = false
	add_child(scene)
	await _ticks(2)
	var cage := scene.get_node_or_null("Cage") as CageBuilder
	assert_object(cage).is_not_null()
	assert_bool(cage.spec.roof).is_true()
	assert_object(scene.get_node_or_null("CageEscape")).is_null()
	# Nothing laid out on the stage: it is out past the walls.
	var stock := scene.get_node_or_null("WeaponStock") as WeaponStock
	if stock:
		assert_bool(stock.stage_actors.is_empty()).is_true()


func test_whipped_into_the_cell_wall_on_the_floor_he_hits_the_steel() -> void:
	_cage = CageBuilder.build(self, CageBuilder.Spec.hell_in_a_cell())
	var a := _wrestler(Vector3(3.6, ArenaBuilder.FLOOR_Y, 0.0), 0)
	var b := _wrestler(Vector3(4.2, ArenaBuilder.FLOOR_Y, 0.0), 1)
	await _ticks(2)
	b.outside_ring = true
	a.outside_ring = true
	var rams: Array = []
	b.hit_the_cage.connect(func(who: WrestlerController, _s: float) -> void: rams.append(who))
	b._irish_whip_target = a
	b._irish_whip_rebounded = false
	b._irish_whip_cage = true
	b.velocity = Vector3(WrestlerController.IRISH_WHIP_LAUNCH_SPEED, 0.0, 0.0)
	b._irish_whip_launch_velocity = b.velocity
	b.fsm.transition_to(WrestlerFSM.State.IRISH_WHIP)
	for i in 60:
		await _ticks(1)
		b.outside_ring = true
		if not rams.is_empty():
			break
	assert_array(rams).contains_exactly([b])
	assert_float(b.global_position.x).is_greater(_cage.spec.half - 0.9)


func test_in_the_ring_a_cell_whip_is_still_the_ropes() -> void:
	_cage = CageBuilder.build(self, CageBuilder.Spec.hell_in_a_cell())
	var b := _wrestler(Vector3(2.4, 0.0, 0.0), 1)
	await _ticks(2)
	b._irish_whip_cage = true
	b.velocity = Vector3(WrestlerController.IRISH_WHIP_LAUNCH_SPEED, 0.0, 0.0)
	assert_bool(b._whipped_into_cage()).is_false()
