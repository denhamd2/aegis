extends GdUnitTestSuite
## Hell in a Cell's door, wall and roof (CellRoof; gauntlet/refs/
## hell_in_a_cell.md): padlocked at the bell, cut open with the wire cutters,
## out, up the front wall and onto the roof; the edge, the fall off it, and
## the centre panels giving way into the ring.


func _match() -> Node:
	var scene: Node = auto_free(load("res://scenes/match.tscn").instantiate())
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1,
			false, MatchRules.Mode.HELL_IN_A_CELL)
	for part in ["Arena", "LightRig"]:
		scene.get_node(part).free()
	scene.entrances = false
	add_child(scene)
	return scene


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _men(scene: Node) -> Array:
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	for w in [roman, cody]:
		w.is_ai = false
	(scene.get_node("MatchReferee") as MatchReferee).set_physics_process(false)
	return [roman, cody]


func _run_route(w: WrestlerController, roof: CellRoof, ticks: int) -> void:
	for i in ticks:
		await _ticks(1)
		if not roof.busy(w):
			return


func test_the_door_is_padlocked_and_the_cutters_are_under_the_ring() -> void:
	var scene := _match()
	await _ticks(2)
	var roof := scene.get_node("CellRoof") as CellRoof
	assert_bool(roof.door_locked).is_true()
	assert_bool(roof.cage.has_padlock()).is_true()
	var stock := WeaponStock.of(scene.get_node("WrestlerA"))
	var found := false
	for a in stock.apron_actors:
		found = found or a.def.id == &"wire_cutters"
	assert_bool(found).is_true()


func test_no_way_out_without_the_cutters_then_cut_and_out() -> void:
	var scene := _match()
	await _ticks(2)
	var m: Array = _men(scene)
	var roman: WrestlerController = m[0]
	var roof := scene.get_node("CellRoof") as CellRoof
	roman.outside_ring = true
	roman.global_position = Vector3(0.0, WrestlerController.FLOOR_LEVEL, -(roof.half() - 0.7))
	await _ticks(2)
	assert_bool(roof.begin(roman)).is_false()
	# The cutters in his hand.
	var cutters := WeaponStock.of(roman).pull(WeaponCatalog.by_id(&"wire_cutters"))
	roman.held_weapon = cutters
	cutters.take(roman)
	assert_bool(roof.begin(roman)).is_true()
	await _run_route(roman, roof, 400)
	assert_bool(roof.door_locked).is_false()
	assert_bool(roof.cage.has_padlock()).is_false()
	assert_float(roman.global_position.z).is_less(-roof.half())
	assert_bool(roman.has_weapon()).is_true()


func test_up_the_wall_onto_the_roof_and_back_down() -> void:
	var scene := _match()
	await _ticks(2)
	var m: Array = _men(scene)
	var roman: WrestlerController = m[0]
	var roof := scene.get_node("CellRoof") as CellRoof
	roman.outside_ring = true
	var foot := Vector3(1.35, 0.0, -(roof.half() + 0.4))
	foot.y = ArenaBuilder.match_surface_y(foot)
	roman.global_position = foot
	await _ticks(2)
	assert_bool(roof.at_climbable_wall(roman.global_position)).is_true()
	assert_bool(roof.begin(roman)).is_true()
	await _run_route(roman, roof, 500)
	assert_bool(roman.on_roof).is_true()
	assert_float(roman.global_position.y).is_greater(roof.top_y() - 0.1)
	await _ticks(30)
	# Still up there: the roof holds him.
	assert_float(roman.global_position.y).is_greater(roof.top_y() - 0.1)
	assert_bool(roof.at_roof_front_edge(roman.global_position)).is_true()
	assert_bool(roof.begin(roman)).is_true()
	await _run_route(roman, roof, 400)
	assert_bool(roman.on_roof).is_false()
	assert_float(roman.global_position.y).is_less(0.0)


func _onto_roof(w: WrestlerController, roof: CellRoof, at: Vector3) -> void:
	w.outside_ring = true
	w.on_roof = true
	w.global_position = Vector3(at.x, roof.surface_y(), at.z)
	w.fsm.transition_to(WrestlerFSM.State.IDLE)


func test_spent_and_knocked_down_by_the_edge_he_goes_over_it() -> void:
	var scene := _match()
	await _ticks(2)
	var m: Array = _men(scene)
	var roman: WrestlerController = m[0]
	var cody: WrestlerController = m[1]
	var roof := scene.get_node("CellRoof") as CellRoof
	var fell: Array = []
	roof.fell_off.connect(func(w: WrestlerController, through: bool) -> void: fell.append([w, through]))
	_onto_roof(roman, roof, Vector3(-(roof.half() - 0.5), 0, 0.5))
	_onto_roof(cody, roof, Vector3(-(roof.half() - 1.6), 0, 0.5))
	await _ticks(2)
	# Spent.
	cody.combat.limb_damage["torso"] = CombatSystem.KICKOUT_DAMAGE_REFERENCE * 0.8
	roman.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	roman.combat.limb_damage["torso"] = CombatSystem.KICKOUT_DAMAGE_REFERENCE * 0.8
	roman._go_down(CombatSystem.Tier.POWER)
	assert_int(fell.size()).is_equal(1)
	assert_bool(fell[0][1]).is_false()
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.LADDER_FALL)
	for i in 200:
		await _ticks(1)
		if roman.fsm.current_state == WrestlerFSM.State.DOWN:
			break
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	assert_float(roman.global_position.y).is_less(-0.9)
	assert_float(absf(roman.global_position.x)).is_greater(roof.half())


func test_the_centre_panel_gives_way_into_the_ring() -> void:
	var scene := _match()
	await _ticks(2)
	var m: Array = _men(scene)
	var roman: WrestlerController = m[0]
	var roof := scene.get_node("CellRoof") as CellRoof
	var bay_c := roof.cage.bay_centre(1, 1)
	assert_bool(roof.cage.is_centre_bay(Vector2i(1, 1))).is_true()
	_onto_roof(roman, roof, bay_c + Vector3(0.2, 0, 0.2))
	await _ticks(2)
	var bay := roof.cage.bay_of(roman.global_position)
	# Three power slams dent it; it holds.
	for i in 3:
		assert_bool(roof.landed(roman, CombatSystem.Tier.POWER)).is_false()
	assert_float(roof.sag(bay)).is_greater(0.0)
	assert_bool(roof.is_broken(bay)).is_false()
	roman.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	roman._go_down(CombatSystem.Tier.POWER)
	assert_bool(roof.is_broken(bay)).is_true()
	for i in 200:
		await _ticks(1)
		if roman.fsm.current_state == WrestlerFSM.State.DOWN:
			break
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	assert_bool(roman.outside_ring).is_false()
	assert_float(roman.global_position.y).is_equal_approx(WrestlerController.MAT_LEVEL, 0.05)


func test_off_the_roof_edge_onto_the_man_down_below() -> void:
	var scene := _match()
	await _ticks(2)
	var m: Array = _men(scene)
	var roman: WrestlerController = m[0]
	var cody: WrestlerController = m[1]
	var roof := scene.get_node("CellRoof") as CellRoof
	_onto_roof(roman, roof, Vector3(-(roof.half() - 0.5), 0, 0.3))
	cody.outside_ring = true
	cody.global_position = Vector3(-(roof.half() + 0.5), ArenaBuilder.FLOOR_Y, 0.3)
	await _ticks(2)
	cody.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	cody._go_down(CombatSystem.Tier.POWER)
	cody.set_physics_process(false)
	var health := cody.combat.health()
	assert_bool(roman.can_high_dive()).is_true()
	roman.begin_high_dive(cody)
	for i in 120:
		await _ticks(1)
		if roman.fsm.current_state == WrestlerFSM.State.DOWN:
			break
	assert_int(roman.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	assert_float(cody.combat.health()).is_less(health)
	assert_float(roman.global_position.distance_to(cody.global_position)).is_less(1.0)


func test_hung_for_the_entrances_then_lowered_and_padlocked() -> void:
	var scene := _match()
	await _ticks(2)
	var m: Array = _men(scene)
	var roman: WrestlerController = m[0]
	var roof := scene.get_node("CellRoof") as CellRoof
	var cage := roof.cage
	# As MatchSetup hangs it when the entrances run.
	roof.door_locked = false
	cage.set_padlock(false)
	cage.set_lift(CageBuilder.HOIST_LIFT)
	cage.landed.connect(roof.lock_door)
	assert_bool(cage.is_lowered()).is_false()
	assert_float(cage.global_position.y + cage.spec.base_y).is_greater(ArenaBuilder.TRUSS_Y)
	# Hanging, its walls hold no one: he walks from the floor into the ring.
	var p := Vector3(0.0, WrestlerController.FLOOR_LEVEL, roof.half() - 0.3)
	assert_vector(roof.keep_cell_side(roman, p)).is_equal(p)
	assert_bool(roof.begin(roman)).is_false()
	cage.lower(1.0)
	await _ticks(30)
	assert_float(cage.lift).is_between(0.1, CageBuilder.HOIST_LIFT - 0.1)
	await _ticks(40)
	assert_bool(cage.is_lowered()).is_true()
	assert_float(cage.global_position.y).is_equal_approx(0.0, 0.001)
	assert_bool(roof.door_locked).is_true()
	assert_bool(cage.has_padlock()).is_true()


func test_the_lowering_music_plays_once_and_fades_at_the_bell() -> void:
	var scene := _match()
	await _ticks(2)
	var audio: MatchAudio = scene.audio
	assert_object(audio).is_not_null()
	audio._on_cue("cell_lower")
	assert_bool(audio.cell_music_on()).is_true()
	assert_bool((audio._cell_music.stream as AudioStreamOggVorbis).loop).is_false()
	audio.opening_bell()
	assert_bool(audio.cell_music_on()).is_false()


func test_a_big_grapple_by_the_wall_drives_him_into_the_steel() -> void:
	var scene := _match()
	await _ticks(2)
	var m: Array = _men(scene)
	var roman: WrestlerController = m[0]
	var cody: WrestlerController = m[1]
	var roof := scene.get_node("CellRoof") as CellRoof
	for w in [roman, cody]:
		w.outside_ring = true
	# Out on the floor inside the cell, by its +X wall.
	cody.global_position = Vector3(roof.half() - 0.6, WrestlerController.FLOOR_LEVEL, 1.0)
	roman.global_position = Vector3(roof.half() - 1.4, WrestlerController.FLOOR_LEVEL, 1.0)
	var power: MoveDef = roman.power_move if roman.power_move else roman.power_move_pool[0]
	var hits: Array = []
	cody.hit_the_cage.connect(func(_w: WrestlerController, s: float) -> void: hits.append(s))
	var health := cody.combat.health()
	roman._grapple_into_the_steel(power)
	assert_int(roman.cage_rams).is_equal(1)
	assert_int(hits.size()).is_equal(1)
	assert_float(cody.combat.health()).is_less(health)
	# In the middle of the floor, nowhere near a wall: nothing.
	cody.global_position = Vector3(3.6, WrestlerController.FLOOR_LEVEL, 0.0)
	roman._grapple_into_the_steel(power)
	assert_int(roman.cage_rams).is_equal(1)


func test_through_the_open_door_he_is_on_the_other_side() -> void:
	var scene := _match()
	await _ticks(2)
	var m: Array = _men(scene)
	var roman: WrestlerController = m[0]
	var roof := scene.get_node("CellRoof") as CellRoof
	var a := roof.door_axis()
	var inside := a * (roof.half() - 0.5)
	assert_bool(roof.is_outside_cell(roman)).is_false()
	# Shut: held inside.
	var out := a * (roof.half() + 0.5)
	assert_float(roof.keep_cell_side(roman, out).dot(a)).is_less(roof.half())
	# Open: he steps through, and the far side is his now.
	roof.cage.set_door_open(1.0)
	assert_vector(roof.keep_cell_side(roman, out)).is_equal(out)
	assert_bool(roof.is_outside_cell(roman)).is_true()
	assert_vector(roof.keep_cell_side(roman, inside)).is_equal(inside)
	assert_bool(roof.is_outside_cell(roman)).is_false()
